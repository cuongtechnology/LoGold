#!/usr/bin/env bash
# Script deploy Cloudflare Worker cho Lỗ.
# Chạy: cd worker && bash DEPLOY.sh
#
# Yêu cầu: node >= 18, tài khoản Cloudflare (free tier OK)

set -euo pipefail

cd "$(dirname "$0")"

echo "→ 1. Install dependencies..."
npm install --no-audit --no-fund

echo "→ 2. Login Cloudflare (mở browser để authorize)..."
npx wrangler login

echo "→ 3. Tạo KV namespace..."
KV_OUTPUT=$(npx wrangler kv namespace create LO_PRICE_CACHE 2>&1)
PREVIEW_OUTPUT=$(npx wrangler kv namespace create LO_PRICE_CACHE --preview 2>&1)
echo "$KV_OUTPUT"
echo "$PREVIEW_OUTPUT"

KV_ID=$(echo "$KV_OUTPUT" | grep -oP 'id = "\K[a-f0-9]+' | head -1)
PREVIEW_ID=$(echo "$PREVIEW_OUTPUT" | grep -oP 'id = "\K[a-f0-9]+' | head -1)

if [[ -z "$KV_ID" || -z "$PREVIEW_ID" ]]; then
  echo "❌ Không parse được KV id. Copy id thủ công vào wrangler.toml"
  exit 1
fi

echo "→ 4. Ghi KV id vào wrangler.toml..."
sed -i.bak "s|TODO_replace_with_kv_id_from_wrangler_output|$KV_ID|g; s|TODO_replace_with_preview_id_from_wrangler_output|$PREVIEW_ID|g" wrangler.toml
rm -f wrangler.toml.bak

echo "→ 5. Deploy worker..."
npx wrangler deploy

echo ""
echo "✅ Done! Test endpoint:"
echo "   curl https://lo-gold-proxy.<subdomain>.workers.dev/health"
echo ""
echo "→ Copy URL trên rồi build Flutter với:"
echo "   flutter build web --dart-define=LO_WORKER_URL=<URL_ĐÓ>"
