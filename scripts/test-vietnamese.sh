#!/bin/bash
# Test Vietnamese language quality with the configured LLM
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OPENCLAW_REPO="${OPENCLAW_REPO:-/opt/openclaw}"
cd "$OPENCLAW_REPO"

echo "=== Testing Vietnamese Language Quality ==="
echo ""

# Test 1: Basic Vietnamese response
echo "Test 1: Basic greeting"
docker compose exec openclaw-gateway openclaw chat --message "Xin chào, con là ai?" --once
echo ""

# Test 2: Vietnamese kinship terms
echo "Test 2: Kinship terms (should use 'con' and 'bà')"
docker compose exec openclaw-gateway openclaw chat --message "Giúp bà đọc email" --once
echo ""

# Test 3: Form filling instructions
echo "Test 3: Form filling in Vietnamese"
docker compose exec openclaw-gateway openclaw chat --message "Bà muốn điền biểu mẫu trên trang dichvucong.gov.vn" --once
echo ""

# Test 4: Error handling in Vietnamese
echo "Test 4: Error handling"
docker compose exec openclaw-gateway openclaw chat --message "Trang web bị lỗi, làm sao bây giờ?" --once
echo ""

echo "=== Vietnamese tests complete ==="
echo "Review the responses above. They should all be:"
echo "- In Vietnamese only (no English)"
echo "- Using 'con' (self) and 'bà' (grandmother)"
echo "- Simple, respectful language"
echo ""
echo "If Vietnamese quality is poor, try switching to GLM-5:"
echo "  Edit .env: DEFAULT_MODEL=zai/glm-5"
echo "  Then: docker compose restart openclaw-gateway"
