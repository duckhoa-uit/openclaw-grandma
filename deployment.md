# Plan: OpenClaw VPS Setup for Grandmother's Browser Assistant

## Context

Your grandmother needs an AI-powered browser assistant that can:
- Fill Vietnamese government forms, handle email, general browsing
- Read PDF instructions and execute the tasks described in them
- Use a **persistent browser session** with saved credentials (no re-login every time)
- Be controlled via **Zalo** (Vietnam's primary messaging app)
- Run on a **free/low-cost VPS** with a cheap but capable LLM provider
- **All interaction is in Vietnamese** — grandmother only speaks/reads Vietnamese

---

## Architecture

```
Grandmother's Phone (Zalo)
        │
        ▼
   Zalo OA Webhook (HTTPS)
        │
        ▼
   VPS (Hetzner CX33 - 4 vCPU, 8GB RAM, Helsinki DC)
   ├── OpenClaw Gateway (Docker — built from github.com/openclaw/openclaw)
   │   ├── Zalo Channel Plugin (@openclaw/zalo)
   │   ├── LLM Provider (Kimi K2.5 via OpenAI-compatible API)
   │   ├── Browser Tool (OpenClaw-managed, persistent profile)
   │   │   └── Chrome/Chromium with --keep-alive session
   │   │       └── Saved cookies/logins for all grandmother's sites
   │   ├── Official Skills (from ClawHub registry)
   │   │   ├── Browser Skills
   │   │   │   ├── browser-use (persistent browser automation)
   │   │   │   ├── autofillin (form filling + file uploads with Playwright)
   │   │   │   └── browser-automation (navigate, click, type, scroll)
   │   │   ├── Office/Document Skills
   │   │   │   ├── office-to-md (Word/Excel/PowerPoint/PDF → Markdown)
   │   │   │   ├── md-to-office (Markdown → Word/Excel/PowerPoint)
   │   │   │   ├── pdf-converter (PDF ↔ Word/Excel/PPT/HTML/images)
   │   │   │   └── pdf-extraction (extract text, tables, images from PDF)
   │   │   └── Utility Skills
   │   │       ├── file-links-tool (upload/download files)
   │   │       └── template-engine (fill document templates)
   │   └── Custom Skills (Vietnamese-specific)
   │       ├── vn-form-filler (Vietnamese form filling)
   │       ├── pdf-task-reader (read PDF instructions, execute tasks)
   │       ├── email-helper (read/send email in Vietnamese)
   │       ├── study-class (navigate online courses)
   │       └── session-keeper (auto-refresh saved logins)
   └── Caddy (reverse proxy + auto HTTPS for Zalo webhook)
```

---

## Step-by-Step Plan

### Step 1: Provision VPS on Hetzner

- Sign up at [hetzner.com/cloud](https://hetzner.com/cloud)
- Create a **CX33** server (~$5.99/mo):
  - CPU: 4 vCPU (x86 Intel/AMD)
  - RAM: 8 GB
  - Storage: 80 GB NVMe SSD
  - OS: Ubuntu 22.04
  - **Datacenter: Helsinki (hel1-dc2)** (or Singapore if available)
  - Add your SSH key during creation
- Access: `ssh root@YOUR_VPS_IP`

### Step 2: Server Base Setup

```bash
# Or run the automated script: scripts/vps-setup.sh

# Update system
apt-get update && apt-get install -y git curl ca-certificates

# Install Docker
curl -fsSL https://get.docker.com | sh

# Install Caddy (reverse proxy for HTTPS)
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update && sudo apt install caddy

# Set up firewall
sudo ufw default deny incoming && sudo ufw default allow outgoing
sudo ufw allow 22/tcp && sudo ufw allow 443/tcp
sudo ufw --force enable
```

### Step 3: Clone & Build OpenClaw (Official Docker Method)

```bash
# Clone the official OpenClaw repo
git clone https://github.com/openclaw/openclaw.git /opt/openclaw
cd /opt/openclaw

# Create persistent host directories (survives container rebuilds)
mkdir -p /root/.openclaw/workspace
chown -R 1000:1000 /root/.openclaw

# Clone this grandma config repo
git clone https://github.com/duckhoa-uit/openclaw-grandma.git /opt/openclaw-grandma

# Copy .env.example and fill in your keys
cp /opt/openclaw-grandma/.env.example /opt/openclaw/.env
nano .env  # Fill in API keys, tokens, generate secrets with: openssl rand -hex 32

# Run the official Docker setup script (builds image + onboarding wizard)
./docker-setup.sh

# Or build manually:
# docker compose build
# docker compose run --rm openclaw-cli onboard
# docker compose up -d openclaw-gateway
```

**`.env` configuration:**
```env
# OpenClaw Gateway (required)
OPENCLAW_IMAGE=openclaw:latest
OPENCLAW_GATEWAY_TOKEN=<generate with: openssl rand -hex 32>
OPENCLAW_GATEWAY_BIND=lan
OPENCLAW_GATEWAY_PORT=18789
OPENCLAW_CONFIG_DIR=/root/.openclaw
OPENCLAW_WORKSPACE_DIR=/root/.openclaw/workspace
GOG_KEYRING_PASSWORD=<generate with: openssl rand -hex 32>
XDG_CONFIG_HOME=/home/node/.openclaw

# LLM Providers (both configured, switch via DEFAULT_MODEL)
MOONSHOT_API_KEY=your-moonshot-api-key
ZAI_API_KEY=your-zai-api-key
DEFAULT_MODEL=kimi/kimi-k2.5  # or zai/glm-5

# Browser config - persistent profile
BROWSER_PROFILE=grandma
BROWSER_KEEP_ALIVE=true
BROWSER_HEADLESS=true

# Zalo channel
ZALO_OA_ACCESS_TOKEN=your-zalo-oa-token
ZALO_OA_REFRESH_TOKEN=your-zalo-refresh-token
ZALO_APP_ID=your-app-id
ZALO_APP_SECRET=your-app-secret
ZALO_WEBHOOK_SECRET=your-webhook-secret
```

**`models.providers` config (both Kimi K2.5 and GLM-5):**
```json
{
  "kimi": {
    "baseUrl": "https://api.moonshot.ai/v1",
    "apiKey": "${MOONSHOT_API_KEY}",
    "models": {
      "kimi-k2.5": {
        "contextWindow": 256000
      }
    }
  },
  "zai": {
    "baseUrl": "https://open.bigmodel.cn/api/paas/v4",
    "apiKey": "${ZAI_API_KEY}",
    "models": {
      "glm-5": {
        "contextWindow": 200000
      }
    }
  }
}
```

**Switch between providers:**
```bash
# Use Kimi K2.5 (default)
DEFAULT_MODEL=kimi/kimi-k2.5

# Use GLM-5
DEFAULT_MODEL=zai/glm-5
```

**Provider comparison:**

| Feature | Kimi K2.5 | GLM-5 |
|---|---|---|
| Context window | 256K tokens | 200K tokens |
| Multimodal (vision) | Yes | Yes |
| Cost | ~1.6x cheaper | Baseline |
| Parameters | 1T (32B active) | 745B (44B active) |
| Vietnamese support | Decent (test needed) | Decent (test needed) |
| Asian language strength | Good | Good (Tsinghua-backed) |
| Free tier | Via Moonshot | Via Z.AI (bigmodel.cn) |

**Recommendation:** Start with Kimi K2.5 (cheaper, larger context). Switch to GLM-5 if Vietnamese quality is better. Test both during Step 9.

**Vietnamese-only system prompt (`config/system-prompt.md`):**
```markdown
# Hệ thống trợ lý AI cho Bà

Bạn là trợ lý AI cá nhân cho một bà lớn tuổi người Việt Nam.

## Quy tắc bắt buộc:
- **LUÔN LUÔN** trả lời bằng tiếng Việt. Không bao giờ dùng tiếng Anh.
- Dùng ngôn ngữ đơn giản, dễ hiểu, lịch sự (xưng "con", gọi "bà")
- Giải thích từng bước một cách rõ ràng
- Luôn gửi ảnh chụp màn hình trước khi gửi/nộp bất kỳ biểu mẫu nào
- Hỏi xác nhận trước khi thực hiện hành động quan trọng
- Không bao giờ thực hiện giao dịch tài chính mà không có xác nhận rõ ràng
- Nếu gặp lỗi, giải thích bằng tiếng Việt đơn giản và đề xuất giải pháp

## Khả năng:
- Điền biểu mẫu trên trang web
- Đọc và xử lý file PDF, Word, Excel
- Đọc và gửi email
- Mở lớp học trực tuyến
- Chuyển đổi file (PDF ↔ Word ↔ Excel)
- Chụp màn hình trang web

## Khi nhận file (PDF, Word, Excel):
1. Đọc nội dung file
2. Tóm tắt nội dung cho bà bằng tiếng Việt
3. Hỏi bà muốn làm gì với file này
4. Thực hiện theo yêu cầu của bà
```

This system prompt ensures OpenClaw ALWAYS responds in Vietnamese, uses respectful
Vietnamese kinship terms ("con" for self, "bà" for grandmother), and explains
everything in simple language.

### Step 4: Configure Persistent Browser (Key Requirement)

This is the core of your request - a browser that **keeps credentials alive** across tasks:

```bash
# Start the managed browser with a persistent profile
openclaw browser start --profile grandma --keep-alive

# The profile is stored at:
# ~/.openclaw/browser-profiles/grandma/
# This directory persists cookies, localStorage, sessions, etc.
```

**OpenClaw Gateway config (`gateway.yaml`):**
```yaml
browser:
  profile: grandma
  keepAlive: true
  headless: true
  userDataDir: /home/openclaw/.openclaw/browser-profiles/grandma
  args:
    - "--no-first-run"
    - "--disable-sync"
    - "--lang=vi"  # Vietnamese locale
```

**Credential setup uses a hybrid approach (noVNC + auto-relogin scripts):**

**Method 1: noVNC (for initial setup + CAPTCHA/2FA sites)**
1. Start noVNC container on VPS (web-based remote desktop)
2. Open `http://your-vps-ip:8080` from your laptop/phone browser
3. You see the VPS desktop with Chrome running in the persistent profile
4. Manually log into all grandmother's accounts (email, gov sites, etc.)
5. Handle any CAPTCHAs, 2FA prompts, phone verifications manually
6. Browser profile saves all cookies, localStorage, sessions
7. Close noVNC when done — Chrome switches back to headless mode
8. Re-enable noVNC anytime a site needs manual re-authentication

**noVNC Docker service (only started on-demand):**
```bash
# Start noVNC when you need to manually log in
docker compose --profile setup up -d novnc

# Stop noVNC when done (security: don't leave it running)
docker compose --profile setup down
```

**Method 2: Playwright auto-relogin scripts (for session refresh)**
For sites that expire sessions but DON'T require CAPTCHA/2FA:
```bash
# Store credentials securely in .env (never in skill files)
GRANDMA_EMAIL=grandma@email.com
GRANDMA_EMAIL_PASSWORD=encrypted-or-env-var
GOV_SITE_USERNAME=grandmother-id
GOV_SITE_PASSWORD=encrypted-or-env-var
```

**Auto-relogin skill (runs on schedule via cron):**
```yaml
# skills/auto-relogin.yaml
name: auto-relogin
description: "Auto-relogin to sites when sessions expire"
instructions: |
  Check each saved site and re-login if session has expired:
  1. Navigate to site
  2. Check if still logged in (look for user avatar/name/dashboard)
  3. If logged out:
     a. Find the login form
     b. Enter credentials from environment variables
     c. Submit and verify login succeeded
     d. Take screenshot as proof
  4. If CAPTCHA or 2FA is required:
     a. DO NOT attempt to bypass
     b. Send a Zalo message: "Trang [site] cần đăng nhập thủ công. Vui lòng liên hệ con."
        ("Site [site] needs manual login. Please contact your grandchild.")

  Sites to check:
  - Email: ${GRANDMA_EMAIL_URL}
  - Government portal: ${GOV_SITE_URL}
  - E-learning: ${ELEARNING_URL}
```

**Cron schedule (check sessions every 12 hours):**
```yaml
# In OpenClaw config
automation:
  schedules:
    - name: session-refresh
      cron: "0 */12 * * *"  # Every 12 hours
      skill: auto-relogin
```

**How the two methods work together:**
| Scenario | Method Used |
|---|---|
| First-time login to any site | noVNC (manual) |
| Site with CAPTCHA/2FA | noVNC (manual) — bot sends Zalo alert |
| Session expired, no CAPTCHA | Playwright auto-relogin (automatic) |
| New site grandmother needs | noVNC (manual first login) |
| Routine session refresh | Playwright cron job (every 12h) |

### Step 5: Install & Configure Zalo Channel

```bash
# Install Zalo plugin
openclaw plugins install @openclaw/zalo
```

**Zalo OA Setup:**
1. Create a Zalo Official Account at [oa.zalo.me](https://oa.zalo.me)
2. Register an app at [developers.zalo.me](https://developers.zalo.me)
3. Get OA Access Token + App credentials
4. Configure webhook URL pointing to your VPS

**Caddy config (`/etc/caddy/Caddyfile`):**
```
your-domain.com {
    reverse_proxy /webhook/zalo localhost:3000
}
```

**OpenClaw Zalo channel config:**
```yaml
channels:
  zalo:
    enabled: true
    oaAccessToken: ${ZALO_OA_ACCESS_TOKEN}
    oaRefreshToken: ${ZALO_OA_REFRESH_TOKEN}
    appId: ${ZALO_APP_ID}
    appSecret: ${ZALO_APP_SECRET}
    webhookUrl: https://your-domain.com/webhook/zalo
    webhookSecret: ${ZALO_WEBHOOK_SECRET}
```

**Note:** Zalo channel is experimental in OpenClaw - DM only, no group support yet.

### Step 6: Install Official Browser & Office Skills

Install all relevant skills from ClawHub (the official OpenClaw skills registry):

```bash
# ═══════════════════════════════════════════
# BROWSER SKILLS
# ═══════════════════════════════════════════

# browser-use: Core browser automation — persistent sessions, navigate, click, type, screenshot
# This is the MAIN skill for controlling the browser with saved credentials
openclaw skills install @openclaw/browser-use

# autofillin: Automated form filling + file uploads with Playwright
# Handles login persistence, form detection, waits for manual confirmation before submit
openclaw skills install @openclaw/autofillin

# browser-automation: Navigate, click, type, scroll, switch tabs
# Lower-level browser control for custom workflows
openclaw skills install @openclaw/browser-automation

# ═══════════════════════════════════════════
# OFFICE / DOCUMENT SKILLS
# ═══════════════════════════════════════════

# office-to-md: Convert Word (.docx), Excel (.xlsx), PowerPoint (.pptx), PDF → Markdown
# Uses Microsoft's markitdown engine, preserves headings, tables, images, links
openclaw skills install @openclaw/office-to-md
pip install markitdown[all]  # Required dependency (includes OCR + audio)

# md-to-office: Convert Markdown → Word, Excel, PowerPoint
# For creating documents from AI-generated content
openclaw skills install @openclaw/md-to-office

# pdf-converter: PDF ↔ Word/Excel/PPT/HTML/images
# Format-preserving conversions, OCR for scanned PDFs, batch processing
openclaw skills install @openclaw/pdf-converter

# pdf-extraction: Extract text, tables, and images from PDFs
# Useful for reading Vietnamese government PDF instructions
openclaw skills install @openclaw/pdf-extraction

# template-engine: Fill document templates with data
# Good for repeatedly filling the same form/document types
openclaw skills install @openclaw/template-engine

# ═══════════════════════════════════════════
# FILE & UTILITY SKILLS
# ═══════════════════════════════════════════

# file-links-tool: Upload/download files securely
openclaw skills install @openclaw/file-links-tool
```

**Verify all skills are installed:**
```bash
openclaw skills list
# Should show: browser-use, autofillin, browser-automation,
#              office-to-md, md-to-office, pdf-converter,
#              pdf-extraction, template-engine, file-links-tool
```

**How these skills work together for grandmother's tasks:**

| Task | Skills Used |
|---|---|
| "Fill this government form" | `browser-use` + `autofillin` (persistent session, no re-login) |
| "Read this PDF and do what it says" | `pdf-extraction` → `browser-use` + `autofillin` |
| "Convert this Word doc to PDF" | `md-to-office` or `pdf-converter` |
| "Download this PDF form, fill it, upload it" | `pdf-converter` + `template-engine` + `browser-use` |
| "Read my email" | `browser-use` (uses saved Gmail/email session) |
| "Open my online study class" | `browser-use` (persistent login to e-learning site) |

### Step 7: Create Custom Vietnamese Skills

All custom skills enforce Vietnamese-only communication using respectful kinship terms.

#### Skill 1: Vietnamese Form Filler
```yaml
# skills/vn-form-filler.yaml
name: vn-form-filler
description: "Điền biểu mẫu trên trang web cho bà"
instructions: |
  NGÔN NGỮ: Luôn luôn trả lời bằng tiếng Việt. Xưng "con", gọi "bà".

  Bạn đang giúp bà điền biểu mẫu trên trang web. Thực hiện theo các bước:
  1. Mở trang web theo link được cung cấp
  2. Chụp ảnh màn hình (snapshot) để nhận diện các trường cần điền
  3. Điền thông tin vào các trường theo yêu cầu
  4. Chụp ảnh màn hình trước khi gửi và gửi cho bà xem
  5. CHỈ gửi biểu mẫu khi bà xác nhận "OK", "Được", "Gửi đi", hoặc "Đồng ý"

  QUAN TRỌNG:
  - Không bao giờ gửi biểu mẫu liên quan đến tiền bạc mà không có xác nhận
  - Nếu không chắc chắn về thông tin, hỏi bà trước
  - Giải thích mỗi trường bằng tiếng Việt đơn giản
```

#### Skill 2: PDF Task Reader
```yaml
# skills/pdf-task-reader.yaml
name: pdf-task-reader
description: "Đọc file PDF và thực hiện các công việc được yêu cầu"
instructions: |
  NGÔN NGỮ: Luôn luôn trả lời bằng tiếng Việt. Xưng "con", gọi "bà".

  Khi nhận được file PDF:
  1. Tải và đọc nội dung file PDF
  2. Tìm các công việc cần làm (trang web cần mở, biểu mẫu cần điền, lớp học cần đăng ký)
  3. Liệt kê các công việc và hỏi bà xác nhận
  4. Thực hiện từng công việc theo thứ tự, dùng trình duyệt có sẵn đăng nhập
  5. Báo cáo kết quả với ảnh chụp màn hình

  Các loại công việc thường gặp trong PDF:
  - "Truy cập trang web..." → Mở trang web
  - "Điền biểu mẫu..." → Điền biểu mẫu
  - "Đăng ký lớp học..." → Đăng ký học
  - "Nộp hồ sơ..." → Nộp tài liệu
  - "In tài liệu..." → Tải về file PDF để in
```

#### Skill 3: Session Keeper (Auto-refresh logins)
```yaml
# skills/session-keeper.yaml
name: session-keeper
description: "Tự động kiểm tra và duy trì đăng nhập các trang web"
instructions: |
  Kiểm tra từng trang web đã lưu:
  1. Mở trang web
  2. Kiểm tra còn đăng nhập không (tìm tên người dùng, avatar, trang chủ)
  3. Nếu bị đăng xuất, dùng thông tin đăng nhập đã lưu để đăng nhập lại
  4. Nếu cần CAPTCHA hoặc xác thực 2 bước:
     - Gửi tin nhắn Zalo: "Bà ơi, trang [tên trang] cần đăng nhập lại thủ công.
       Con không tự đăng nhập được. Bà nhờ cháu giúp nhé."
  5. Báo cáo kết quả kiểm tra
```

#### Skill 4: Email Helper
```yaml
# skills/email-helper.yaml
name: email-helper
description: "Đọc và gửi email cho bà"
instructions: |
  NGÔN NGỮ: Luôn luôn trả lời bằng tiếng Việt. Xưng "con", gọi "bà".

  Giúp bà với email:
  - Đọc email mới và tóm tắt bằng tiếng Việt đơn giản
  - Viết và gửi thư trả lời theo yêu cầu của bà
  - Chuyển tiếp email quan trọng
  - Tải file đính kèm

  Khi tóm tắt email:
  - "Bà có [số] email mới"
  - "Email từ [người gửi]: [tóm tắt 1-2 câu]"
  - "Bà muốn trả lời email nào không ạ?"
```

#### Skill 5: Study Class Helper
```yaml
# skills/study-class.yaml
name: study-class
description: "Giúp bà mở và tham gia lớp học trực tuyến"
instructions: |
  NGÔN NGỮ: Luôn luôn trả lời bằng tiếng Việt. Xưng "con", gọi "bà".

  Giúp bà tham gia lớp học trực tuyến:
  1. Mở trang web lớp học (dùng tài khoản đã đăng nhập sẵn)
  2. Tìm bài học/lớp học tiếp theo
  3. Chụp ảnh màn hình và hướng dẫn bà
  4. Nếu cần làm bài tập, hướng dẫn từng bước

  Nếu trang web yêu cầu đăng nhập lại:
  - Tự động đăng nhập bằng thông tin đã lưu
  - Nếu không được, báo cho bà biết
```

### Step 8: Docker Compose (Final Deployment)

The `docker-compose.yml` is placed inside the cloned OpenClaw repo (`/opt/openclaw`).
This repo (`openclaw-grandma`) provides config, skills, and scripts that get copied into the deployment.

```yaml
# docker-compose.yml (inside /opt/openclaw)
services:
  openclaw-gateway:
    image: ${OPENCLAW_IMAGE}
    build: .
    container_name: openclaw-gateway
    restart: unless-stopped
    env_file:
      - .env
    environment:
      - HOME=/home/node
      - NODE_ENV=production
      - TERM=${TERM}
      - OPENCLAW_GATEWAY_BIND=${OPENCLAW_GATEWAY_BIND}
      - OPENCLAW_GATEWAY_PORT=${OPENCLAW_GATEWAY_PORT}
      - OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN}
      - GOG_KEYRING_PASSWORD=${GOG_KEYRING_PASSWORD}
      - XDG_CONFIG_HOME=/home/node/.config
      - PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    volumes:
      - ${OPENCLAW_CONFIG_DIR}:/home/node/.openclaw
      - ${OPENCLAW_WORKSPACE_DIR}:/home/node/.openclaw/workspace
    ports:
      # Loopback only — access via SSH tunnel from your laptop
      - "127.0.0.1:${OPENCLAW_GATEWAY_PORT}:18789"
    shm_size: '2gb'  # Required for Chromium/Playwright
    command: ["node", "dist/index.js", "gateway", "--bind", "${OPENCLAW_GATEWAY_BIND}", "--port", "${OPENCLAW_GATEWAY_PORT}", "--allow-unconfigured"]

  # noVNC for initial credential setup (disable after setup)
  novnc:
    image: theasp/novnc:latest
    container_name: novnc
    environment:
      - DISPLAY_WIDTH=1280
      - DISPLAY_HEIGHT=720
    ports:
      - "6080:8080"
    profiles:
      - setup  # Only runs with: docker compose --profile setup up -d novnc
```

**Access the Gateway from your laptop (SSH tunnel):**
```bash
ssh -N -L 18789:127.0.0.1:18789 root@YOUR_VPS_IP
# Then open http://127.0.0.1:18789/ and paste your OPENCLAW_GATEWAY_TOKEN
```

### Step 9: Vietnamese Language Testing

Before going live, verify the full Vietnamese experience:
- Confirm system prompt makes OpenClaw respond ONLY in Vietnamese
- Test Vietnamese kinship terms ("con"/"bà") are used consistently
- Test form field identification on Vietnamese government sites
- Test PDF reading with Vietnamese content
- Test Zalo message understanding in Vietnamese
- Test that error messages and confirmations are all in Vietnamese
- Test edge cases: mixed Vietnamese/English content on websites

**Fallback LLM options if Kimi K2.5 Vietnamese is weak:**
- **Qwen 3** (Alibaba) - strong multilingual, has free tier via `qwen-oauth`
- **GLM-5** (Z.AI) - good Asian language support, free tier available
- **Gemini 3 Flash** (Google) - strong multilingual, generous free tier

### Step 10: Security Hardening

- [ ] Enable UFW firewall (only 22, 443)
- [ ] Use SSH keys only (disable password auth)
- [ ] Keep Gateway loopback-only (access via SSH tunnel)
- [ ] Set a strong OPENCLAW_GATEWAY_TOKEN
- [ ] Only install skills from official OpenClaw repo (230+ malicious skills were found in Jan-Feb 2026)
- [ ] Disable noVNC after initial credential setup
- [ ] Set up daily backups of browser profile directory
- [ ] Monitor logs for unauthorized access

### Step 11: Grandmother Onboarding

1. Set up her Zalo to message the OpenClaw OA bot
2. Teach her simple commands in Vietnamese:

   **Browser tasks:**
   - "Điền biểu mẫu [link]" → Fill form at URL
   - "Đọc email" → Read recent emails
   - "Mở lớp học" → Open study class
   - "Mở trang [link]" → Navigate to any website
   - "Chụp màn hình" → Take screenshot of current page

   **Document tasks:**
   - "Đọc file PDF" → (send PDF attachment) Read and summarize content
   - "Làm theo hướng dẫn trong PDF" → Read PDF instructions and execute tasks
   - "Chuyển file Word sang PDF" → Convert Word to PDF
   - "Chuyển file PDF sang Word" → Convert PDF to editable Word
   - "Đọc file Excel" → Read and summarize spreadsheet content
   - "Điền vào mẫu [tên]" → Fill a document template

3. Always send screenshot confirmations before submitting anything
4. She can also just send files (PDF, Word, Excel) directly via Zalo and ask what to do with them

---

## Cost Estimate

| Item | Monthly Cost |
|---|---|
| Hetzner CX33 (Helsinki) | **~$5.99/mo** |
| Kimi K2.5 or GLM-5 API (light usage) | **~$1-3** (both have free tiers) |
| Domain name (for HTTPS webhook) | ~$1/mo or use free subdomain |
| **Total** | **~$7-10/month** |

---

## Verification / Testing

1. Build and start gateway: `docker compose build && docker compose up -d openclaw-gateway`
2. Check logs: `docker compose logs -f openclaw-gateway` (should show `listening on ws://0.0.0.0:18789`)
3. SSH tunnel from laptop: `ssh -N -L 18789:127.0.0.1:18789 root@89.167.33.213`
4. Open `http://127.0.0.1:18789/` and paste your gateway token
5. Install Playwright: `docker compose run --rm openclaw-cli node /app/node_modules/playwright-core/cli.js install chromium`
6. Start browser with `--keep-alive`, log into one test site, restart gateway, verify session persists
7. Send a Zalo message to the OA bot, verify it reaches OpenClaw and responds
8. Test form-filler skill on a Vietnamese government form
9. Test PDF reader with a sample Vietnamese PDF
10. Verify Vietnamese language quality with Kimi K2.5 (switch to Qwen/Gemini if needed)
