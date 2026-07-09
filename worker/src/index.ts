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
 * Push notification (giá SJC biến động mạnh):
 *  - `POST /register-token` / `POST /unregister-token` — app đăng ký/gỡ FCM
 *    device token, lưu trong `LO_PRICE_CACHE` (key `token:<fcm_token>`).
 *  - Mỗi lần cron chạy, so giá SJC mới với `last_notified_price:sjc` — lệch
 *    quá `NOTIFY_THRESHOLD_PERCENT` thì bắn FCM tới toàn bộ token đã đăng ký.
 *  - Cần 2 secret (không set thì tính năng tự tắt, không lỗi):
 *      npx wrangler secret put FCM_PROJECT_ID           # project_id trong service account JSON
 *      npx wrangler secret put FCM_SERVICE_ACCOUNT_JSON # nguyên văn nội dung file JSON service account
 *    Tạo service account: Firebase Console → Project settings → Service accounts
 *    → Generate new private key.
 *
 * Deploy:
 *   cd worker && npm install
 *   npx wrangler kv namespace create LO_PRICE_CACHE     # copy id vào wrangler.toml
 *   npx wrangler deploy
 *
 * Endpoint sau deploy: `https://lo-gold-proxy.<subdomain>.workers.dev/prices`
 */

import { SignJWT, importPKCS8 } from 'jose';

export interface Env {
  LO_PRICE_CACHE: KVNamespace;
  FCM_PROJECT_ID?: string;
  FCM_SERVICE_ACCOUNT_JSON?: string;
  TEST_NOTIFY_TOKEN?: string;
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

const TOKEN_PREFIX = 'token:';
const LAST_NOTIFIED_KEY = 'last_notified_price:sjc';
const NOTIFY_THRESHOLD_PERCENT = 1.0; // % thay đổi giá SJC để bắn push

// ─── HTTP handler ─────────────────────────────────────────────────────────

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // Preflight CORS.
    if (request.method === 'OPTIONS') {
      return corsResponse(new Response(null, { status: 204 }));
    }

    if (request.method === 'GET' && url.pathname === '/prices') {
      const bundle = await getCachedOrFresh(env);
      return corsResponse(json(bundle));
    }

    if (request.method === 'GET' && url.pathname === '/health') {
      return corsResponse(json({ ok: true, cacheKey: CACHE_KEY }));
    }

    if (request.method === 'POST' && url.pathname === '/register-token') {
      return corsResponse(await handleRegisterToken(request, env));
    }

    if (request.method === 'POST' && url.pathname === '/unregister-token') {
      return corsResponse(await handleUnregisterToken(request, env));
    }

    if (request.method === 'POST' && url.pathname === '/test-notify') {
      return corsResponse(await handleTestNotify(request, env));
    }

    return corsResponse(new Response('Not found', { status: 404 }));
  },

  // Cron trigger (cấu hình trong wrangler.toml: `crons = ["*/5 * * * *"]`).
  // Refresh cache đều đặn để user luôn nhận cache hit — không có "cold" request
  // nào phải chờ upstream 3-5 giây. Đồng thời kiểm tra biến động giá SJC để
  // gửi push nếu vượt ngưỡng.
  async scheduled(_event: ScheduledEvent, env: Env): Promise<void> {
    try {
      const bundle = await fetchFresh();
      await env.LO_PRICE_CACHE.put(CACHE_KEY, JSON.stringify(bundle), {
        expirationTtl: CACHE_TTL_SECONDS * 2, // buffer để không hết hạn trong lúc cron chạy
      });
      await checkPriceSurgeAndNotify(bundle, env);
    } catch (err) {
      console.error('scheduled refresh failed:', err);
    }
  },
};

// ─── Push notification (đăng ký token + gửi FCM) ─────────────────────────

interface TokenRequestBody {
  token?: string;
  platform?: string;
}

async function handleRegisterToken(request: Request, env: Env): Promise<Response> {
  let body: TokenRequestBody;
  try {
    body = await request.json();
  } catch {
    return new Response('Invalid JSON', { status: 400 });
  }
  if (!body.token) return new Response('Missing token', { status: 400 });

  await env.LO_PRICE_CACHE.put(
    TOKEN_PREFIX + body.token,
    JSON.stringify({
      platform: body.platform ?? 'unknown',
      registeredAt: new Date().toISOString(),
    }),
  );
  return json({ ok: true });
}

async function handleUnregisterToken(request: Request, env: Env): Promise<Response> {
  let body: TokenRequestBody;
  try {
    body = await request.json();
  } catch {
    return new Response('Invalid JSON', { status: 400 });
  }
  if (!body.token) return new Response('Missing token', { status: 400 });

  await env.LO_PRICE_CACHE.delete(TOKEN_PREFIX + body.token);
  return json({ ok: true });
}

interface TestNotifyBody {
  title?: string;
  body?: string;
}

/**
 * Gửi thử 1 push tới toàn bộ token đã đăng ký, bỏ qua ngưỡng biến động giá
 * — chỉ để verify pipeline FCM (JWT sign → OAuth token → gửi) hoạt động.
 *
 * Yêu cầu header `X-Test-Token` khớp secret `TEST_NOTIFY_TOKEN`:
 *   npx wrangler secret put TEST_NOTIFY_TOKEN --name lo-gold-proxy
 * Thiếu secret này → endpoint tự tắt (403), tránh ai cũng gọi được để spam
 * push tới toàn bộ user.
 */
async function handleTestNotify(request: Request, env: Env): Promise<Response> {
  if (!env.TEST_NOTIFY_TOKEN) {
    return new Response('Chưa cấu hình TEST_NOTIFY_TOKEN', { status: 403 });
  }
  if (request.headers.get('X-Test-Token') !== env.TEST_NOTIFY_TOKEN) {
    return new Response('Unauthorized', { status: 401 });
  }
  if (!env.FCM_PROJECT_ID || !env.FCM_SERVICE_ACCOUNT_JSON) {
    return new Response('Chưa cấu hình FCM_PROJECT_ID/FCM_SERVICE_ACCOUNT_JSON', { status: 400 });
  }

  let body: TestNotifyBody = {};
  try {
    body = await request.json();
  } catch {
    // Body rỗng cũng OK — dùng title/body mặc định.
  }

  const title = body.title ?? 'Test thông báo giá vàng';
  const message = body.body ?? 'Nếu bạn thấy cái này, push notification đã chạy đúng 🎉';

  try {
    await sendFcmToAll(env, title, message);
    return json({ ok: true });
  } catch (err) {
    return json({ ok: false, error: String(err) }, 500);
  }
}

interface LastNotifiedPrice {
  buyPrice: number;
  notifiedAt: string;
}

async function checkPriceSurgeAndNotify(bundle: PriceBundle, env: Env): Promise<void> {
  // Push chưa cấu hình (thiếu secret) → bỏ qua êm, không phải lỗi.
  if (!env.FCM_PROJECT_ID || !env.FCM_SERVICE_ACCOUNT_JSON) return;

  const sjc = bundle.prices.find((p) => p.goldTypeId === 'sjc');
  if (!sjc) return;

  const rawLast = await env.LO_PRICE_CACHE.get(LAST_NOTIFIED_KEY);
  if (!rawLast) {
    // Lần đầu chạy — chỉ lưu baseline, chưa có gì để so sánh nên không bắn push.
    await env.LO_PRICE_CACHE.put(
      LAST_NOTIFIED_KEY,
      JSON.stringify({ buyPrice: sjc.buyPrice, notifiedAt: new Date().toISOString() }),
    );
    return;
  }

  const last: LastNotifiedPrice = JSON.parse(rawLast);
  if (last.buyPrice <= 0) return;

  const pctChange = ((sjc.buyPrice - last.buyPrice) / last.buyPrice) * 100;
  if (Math.abs(pctChange) < NOTIFY_THRESHOLD_PERCENT) return;

  const direction = pctChange > 0 ? 'tăng' : 'giảm';
  const title = `Giá vàng SJC vừa ${direction} ${Math.abs(pctChange).toFixed(2)}%`;
  const body = `Giá mua vào hiện tại: ${formatVnd(sjc.buyPrice)}đ/lượng`;

  try {
    await sendFcmToAll(env, title, body);
    await env.LO_PRICE_CACHE.put(
      LAST_NOTIFIED_KEY,
      JSON.stringify({ buyPrice: sjc.buyPrice, notifiedAt: new Date().toISOString() }),
    );
  } catch (err) {
    console.error('gửi FCM thất bại:', err);
  }
}

interface ServiceAccount {
  client_email: string;
  private_key: string;
}

/** Đổi service account JSON → OAuth2 access token (JWT-bearer flow). */
async function getFcmAccessToken(serviceAccountJson: string): Promise<string> {
  const account: ServiceAccount = JSON.parse(serviceAccountJson);
  // Khi set secret qua shell/redirect, "\n" trong PEM đôi khi bị escape kép
  // thành literal "\\n" — chuẩn hoá lại thành xuống dòng thật trước khi
  // importPKCS8 parse, không thì lỗi "must be PKCS#8 formatted string".
  const privateKeyPem = account.private_key.replace(/\\n/g, '\n');
  const privateKey = await importPKCS8(privateKeyPem, 'RS256');

  const jwt = await new SignJWT({ scope: 'https://www.googleapis.com/auth/firebase.messaging' })
    .setProtectedHeader({ alg: 'RS256' })
    .setIssuedAt()
    .setIssuer(account.client_email)
    .setSubject(account.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .setExpirationTime('1h')
    .sign(privateKey);

  const res = await fetchWithTimeout('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!res.ok) {
    throw new Error(`Lấy access token thất bại: HTTP ${res.status}`);
  }
  const data = await res.json<{ access_token: string }>();
  return data.access_token;
}

/**
 * Gửi push tới toàn bộ token đã đăng ký. Token bị FCM báo không còn hợp lệ
 * (app gỡ cài đặt/token hết hạn) thì tự xoá khỏi KV để dọn rác.
 *
 * Giới hạn hiện tại: `list()` chỉ lấy tối đa 1000 token/lần (không phân
 * trang) — đủ dùng ở quy mô nhỏ, cần thêm cursor pagination nếu vượt mốc này.
 */
async function sendFcmToAll(env: Env, title: string, body: string): Promise<void> {
  const projectId = env.FCM_PROJECT_ID!;
  const accessToken = await getFcmAccessToken(env.FCM_SERVICE_ACCOUNT_JSON!);
  const list = await env.LO_PRICE_CACHE.list({ prefix: TOKEN_PREFIX });

  for (const key of list.keys) {
    const token = key.name.slice(TOKEN_PREFIX.length);
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ message: { token, notification: { title, body } } }),
      },
    );

    if (!res.ok) {
      const errText = await res.text();
      console.warn(`FCM gửi lỗi cho token ...${token.slice(-8)}: ${errText}`);
      if (res.status === 404 || errText.includes('UNREGISTERED')) {
        await env.LO_PRICE_CACHE.delete(key.name);
      }
    }
  }
}

function formatVnd(value: number): string {
  return Math.round(value).toLocaleString('vi-VN');
}

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

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
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
