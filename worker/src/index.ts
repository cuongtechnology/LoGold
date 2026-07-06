/**
 * Lo Gold Price Proxy — Cloudflare Worker.
 *
 * Endpoint chính: `GET /prices` → JSON list các loại vàng đã normalize sang
 * VND/lượng. Client Flutter (mobile + web) gọi endpoint này thay vì fetch
 * trực tiếp SJC/DOJI để:
 *  1. Tránh CORS (worker set `Access-Control-Allow-Origin: *`).
 *  2. Ẩn logic scrape khỏi client — sửa scrape không cần force update app.
 *  3. Cache 5 phút trong KV — 10k user × 4 req/ngày = 40k req, nhưng upstream
 *     chỉ nhận ~288 req/ngày (cron 5 phút). Free tier CF thoải mái.
 *  4. User-Agent + retry giúp bypass Cloudflare challenge trên SJC.
 *
 * Deploy:
 *   cd worker && npm install
 *   npx wrangler kv namespace create LO_PRICE_CACHE     # copy id vào wrangler.toml
 *   npx wrangler deploy
 *
 * Endpoint sau deploy: `https://lo-gold-proxy.<subdomain>.workers.dev/prices`
 */

export interface Env {
  LO_PRICE_CACHE: KVNamespace;
}

interface GoldPrice {
  goldTypeId: string;
  buyPrice: number;   // VND/lượng
  sellPrice: number;  // VND/lượng
  source: string;
  updatedAt: string;  // ISO 8601
}

interface PriceBundle {
  prices: GoldPrice[];
  fetchedAt: string;
  upstream: string;
}

const CACHE_KEY = 'prices:v1';
const CACHE_TTL_SECONDS = 300; // 5 phút
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36';
const UPSTREAM_TIMEOUT_MS = 12_000;

// ─── HTTP handler ─────────────────────────────────────────────────────────

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // Preflight CORS.
    if (request.method === 'OPTIONS') {
      return corsResponse(new Response(null, { status: 204 }));
    }
    if (request.method !== 'GET') {
      return corsResponse(new Response('Method not allowed', { status: 405 }));
    }

    if (url.pathname === '/prices') {
      const bundle = await getCachedOrFresh(env);
      return corsResponse(json(bundle));
    }

    if (url.pathname === '/health') {
      return corsResponse(json({ ok: true, cacheKey: CACHE_KEY }));
    }

    return corsResponse(new Response('Not found', { status: 404 }));
  },

  // Cron trigger (cấu hình trong wrangler.toml: `crons = ["*/5 * * * *"]`).
  // Refresh cache đều đặn để user luôn nhận cache hit — không có "cold" request
  // nào phải chờ upstream 3-5 giây.
  async scheduled(_event: ScheduledEvent, env: Env): Promise<void> {
    try {
      const bundle = await fetchFresh();
      await env.LO_PRICE_CACHE.put(CACHE_KEY, JSON.stringify(bundle), {
        expirationTtl: CACHE_TTL_SECONDS * 2, // buffer để không hết hạn trong lúc cron chạy
      });
    } catch (err) {
      console.error('scheduled refresh failed:', err);
    }
  },
};

// ─── Cache logic ──────────────────────────────────────────────────────────

async function getCachedOrFresh(env: Env): Promise<PriceBundle> {
  const cached = await env.LO_PRICE_CACHE.get(CACHE_KEY);
  if (cached) {
    return JSON.parse(cached);
  }
  const fresh = await fetchFresh();
  await env.LO_PRICE_CACHE.put(CACHE_KEY, JSON.stringify(fresh), {
    expirationTtl: CACHE_TTL_SECONDS * 2,
  });
  return fresh;
}

async function fetchFresh(): Promise<PriceBundle> {
  // Thử SJC XML trước; fallback DOJI HTML.
  try {
    const prices = await fetchSjcXml();
    if (prices.length > 0) {
      return {
        prices,
        fetchedAt: new Date().toISOString(),
        upstream: 'sjc_xml',
      };
    }
  } catch (err) {
    console.warn('SJC XML failed:', err);
  }

  const prices = await fetchDojiHtml();
  return {
    prices,
    fetchedAt: new Date().toISOString(),
    upstream: 'doji_html',
  };
}

// ─── Upstream: SJC XML ────────────────────────────────────────────────────

async function fetchSjcXml(): Promise<GoldPrice[]> {
  const res = await fetchWithTimeout('https://sjc.com.vn/xml/tygiavang.xml', {
    headers: {
      'User-Agent': UA,
      'Accept': 'application/xml, text/xml, */*',
      'Accept-Language': 'vi-VN,vi;q=0.9,en;q=0.8',
    },
  });
  if (!res.ok) throw new Error(`SJC XML HTTP ${res.status}`);

  const body = await res.text();
  if (body.trimStart().startsWith('<!DOCTYPE') || body.includes('Just a moment')) {
    throw new Error('SJC XML challenge blocked');
  }

  const now = new Date().toISOString();
  const prices = new Map<string, GoldPrice>();

  // SJC XML format thay đổi theo thời gian; parse cả 2 shape:
  //   <row buy="..." sell="..." type_name="..."/>
  //   <Row><BuyPrice>..</BuyPrice><SellPrice>..</SellPrice><TenLoai>..</TenLoai></Row>
  const rowAttrRegex = /<row\s+([^>]+?)\/?>/gi;
  for (const m of body.matchAll(rowAttrRegex)) {
    const attrs = parseAttrs(m[1]);
    const label = attrs.type_name || attrs.TypeName || '';
    const buy = parseNumber(attrs.buy || attrs.BuyPrice);
    const sell = parseNumber(attrs.sell || attrs.SellPrice);
    addPrice(prices, label, buy, sell, 'sjc_xml', now);
  }

  const rowElemRegex = /<Row>([\s\S]*?)<\/Row>/gi;
  for (const m of body.matchAll(rowElemRegex)) {
    const inner = m[1];
    const label = extractTag(inner, 'TenLoai') || extractTag(inner, 'type_name') || '';
    const buy = parseNumber(extractTag(inner, 'BuyPrice') || extractTag(inner, 'buy'));
    const sell = parseNumber(extractTag(inner, 'SellPrice') || extractTag(inner, 'sell'));
    addPrice(prices, label, buy, sell, 'sjc_xml', now);
  }

  return [...prices.values()];
}

// ─── Upstream: DOJI HTML ──────────────────────────────────────────────────

async function fetchDojiHtml(): Promise<GoldPrice[]> {
  const res = await fetchWithTimeout('https://giavang.doji.vn', {
    headers: {
      'User-Agent': UA,
      'Accept': 'text/html,application/xhtml+xml',
      'Accept-Language': 'vi-VN,vi;q=0.9',
    },
  });
  if (!res.ok) throw new Error(`DOJI HTML HTTP ${res.status}`);

  const html = await res.text();
  const now = new Date().toISOString();
  const prices = new Map<string, GoldPrice>();

  // Bảng Hà Nội format ngắn gọn: <td class="label">NAME</td><td>BUY</td><td>SELL</td>
  // Giá đơn vị nghìn/chỉ → ×10000 = VND/lượng.
  const rowRegex =
    /<td class="label">\s*(.*?)\s*<\/td>\s*<td>\s*([\d,.]+)\s*<\/td>\s*<td>\s*([\d,.]+)\s*<\/td>/gis;

  for (const m of html.matchAll(rowRegex)) {
    const label = m[1];
    const buyThousandPerChi = parseNumber(m[2]);
    const sellThousandPerChi = parseNumber(m[3]);
    if (buyThousandPerChi == null || sellThousandPerChi == null) continue;

    const buy = buyThousandPerChi * 10_000;
    const sell = sellThousandPerChi * 10_000;
    addPrice(prices, label, buy, sell, 'doji_html', now);
  }

  if (prices.size === 0) throw new Error('DOJI parse yielded 0 rows');
  return [...prices.values()];
}

// ─── Helpers ──────────────────────────────────────────────────────────────

function addPrice(
  bag: Map<string, GoldPrice>,
  label: string,
  buy: number | null,
  sell: number | null,
  source: string,
  now: string,
): void {
  if (!label || buy == null || sell == null) return;
  const goldTypeId = mapLabelToGoldTypeId(label);
  if (!goldTypeId) return;
  // First-write wins — mỗi loại chỉ giữ giá đầu tiên gặp trong feed.
  if (!bag.has(goldTypeId)) {
    bag.set(goldTypeId, { goldTypeId, buyPrice: buy, sellPrice: sell, source, updatedAt: now });
  }
}

function mapLabelToGoldTypeId(label: string): string | null {
  const lower = label.toLowerCase();
  if (lower.includes('sjc')) return 'sjc';
  if (lower.includes('nhẫn') || lower.includes('nhan')) return 'ring_9999';
  if (lower.includes('nguyên liệu') || lower.includes('nguyen lieu')
      || lower.includes('avpl') || lower.includes('kim tt')) return 'gold_9999';
  if (lower.includes('nữ trang') || lower.includes('nu trang') || lower.includes('trang sức')) {
    return 'jewelry';
  }
  return null;
}

function parseAttrs(raw: string): Record<string, string> {
  const attrs: Record<string, string> = {};
  const attrRegex = /(\w+)\s*=\s*"([^"]*)"/g;
  for (const m of raw.matchAll(attrRegex)) {
    attrs[m[1]] = m[2];
  }
  return attrs;
}

function extractTag(xml: string, name: string): string | null {
  const re = new RegExp(`<${name}[^>]*>([\\s\\S]*?)</${name}>`, 'i');
  const m = xml.match(re);
  return m ? m[1].trim() : null;
}

function parseNumber(raw: string | null | undefined): number | null {
  if (raw == null) return null;
  const cleaned = raw.replace(/[,.\s]/g, '');
  if (!cleaned) return null;
  const n = Number(cleaned);
  return Number.isFinite(n) ? n : null;
}

async function fetchWithTimeout(url: string, init: RequestInit): Promise<Response> {
  const ctrl = new AbortController();
  const timeout = setTimeout(() => ctrl.abort(), UPSTREAM_TIMEOUT_MS);
  try {
    return await fetch(url, { ...init, signal: ctrl.signal });
  } finally {
    clearTimeout(timeout);
  }
}

function json(payload: unknown): Response {
  return new Response(JSON.stringify(payload), {
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
}

function corsResponse(res: Response): Response {
  const headers = new Headers(res.headers);
  headers.set('Access-Control-Allow-Origin', '*');
  headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  headers.set('Access-Control-Allow-Headers', 'Content-Type');
  headers.set('Cache-Control', `public, max-age=${CACHE_TTL_SECONDS}`);
  return new Response(res.body, { status: res.status, headers });
}
