#!/usr/bin/env bash
# deploy.sh — 1-click Linux deployment for TechPanda Inventory
# Tested on Debian / Ubuntu. Run as a user with sudo privileges.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "  TechPanda Inventory - Linux Deployer"
echo "=========================================="

# -- 1. Docker ------------------------------------------------------------------
if ! command -v docker &>/dev/null; then
  echo "[+] Docker not found. Installing via official convenience script..."
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
  echo "[OK] Docker installed. You may need to log out and back in for group changes."
else
  echo "[OK] Docker already installed: $(docker --version)"
fi

# Ensure Docker daemon auto-starts on system boot
sudo systemctl enable docker.service >/dev/null 2>&1 || true
sudo systemctl enable containerd.service >/dev/null 2>&1 || true

# ── 2. Docker Compose (plugin) ─────────────────────────────────────────────────
if ! docker compose version &>/dev/null 2>&1; then
  echo "[+] Docker Compose plugin not found. Installing…"
  DOCKER_CONFIG="${DOCKER_CONFIG:-$HOME/.docker}"
  mkdir -p "$DOCKER_CONFIG/cli-plugins"
  COMPOSE_VERSION=$(curl -fsSL https://api.github.com/repos/docker/compose/releases/latest \
    | grep '"tag_name"' | sed 's/.*"tag_name": "\(.*\)".*/\1/')
  curl -fsSL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
    -o "$DOCKER_CONFIG/cli-plugins/docker-compose"
  chmod +x "$DOCKER_CONFIG/cli-plugins/docker-compose"
  echo "[✓] Docker Compose installed: $(docker compose version)"
else
  echo "[✓] Docker Compose already available: $(docker compose version)"
fi

# ── 3. Cloudflare Tunnel Token & Secrets ────────────────────────────────────────
if [[ -f "$SCRIPT_DIR/.env" ]] && grep -Eq "^JWT_SECRET=.+" "$SCRIPT_DIR/.env" && grep -Eq "^ADMIN_PASSWORD=.+" "$SCRIPT_DIR/.env"; then
  echo "[✓] Existing application secrets found in .env — preserving them."
else
  echo ""
  echo "Cloudflare Tunnel is optional. Leave the token empty for LAN-only deployment."
  read -rsp "Cloudflare Tunnel Token (optional): " CF_TOKEN
  echo ""
  read -rsp "Initial application admin password: " ADMIN_PASSWORD
  echo ""
  if [[ -z "$ADMIN_PASSWORD" ]]; then
    echo "[!] ADMIN_PASSWORD cannot be empty."
    exit 1
  fi
  RANDOM_SECRET=$(openssl rand -hex 32 2>/dev/null || date +%s%N | sha256sum | head -c 64)
  cat > "$SCRIPT_DIR/.env" <<EOF
CLOUDFLARE_TUNNEL_TOKEN=${CF_TOKEN}
JWT_SECRET=${RANDOM_SECRET}
ADMIN_NAME=admin
ADMIN_PASSWORD=${ADMIN_PASSWORD}
EOF
  echo "[✓] .env written with tunnel token and generated JWT secret."
fi

COMPOSE_ARGS=""
if grep -Eq "^CLOUDFLARE_TUNNEL_TOKEN=.+" "$SCRIPT_DIR/.env"; then
  COMPOSE_ARGS="--profile cloudflare"
  echo "[✓] Cloudflare Tunnel enabled."
else
  echo "[✓] LAN-only mode enabled; Cloudflare Tunnel will not start."
fi

# ── 4. Build + Start ───────────────────────────────────────────────────────────
DOCKER_CMD="docker"
if ! docker info &>/dev/null 2>&1; then
  echo "[!] Current user cannot access Docker daemon directly; using 'sudo docker'."
  DOCKER_CMD="sudo docker"
fi

echo "[+] Running: $DOCKER_CMD compose up -d --build"
cd "$SCRIPT_DIR"
# Avoid taking a port already used by another application on a shared server.
# APP_PORT may be set explicitly in .env; otherwise choose 8000 or the first
# available port in the 8001-8099 range.
if ! grep -Eq '^APP_PORT=[0-9]+$' .env; then
  APP_PORT=8000
  if command -v ss >/dev/null 2>&1 && ss -ltn "sport = :${APP_PORT}" | grep -q LISTEN; then
    for candidate in $(seq 8001 8099); do
      if ! ss -ltn "sport = :${candidate}" | grep -q LISTEN; then
        APP_PORT="$candidate"
        break
      fi
    done
    echo "[!] Port 8000 is already in use; selected APP_PORT=${APP_PORT}."
    printf '\nAPP_PORT=%s\n' "$APP_PORT" >> .env
  fi
fi
# Validate the exact Compose file being deployed before building anything. This
# catches stale/partial releases and reports the real missing setting early.
$DOCKER_CMD compose config --quiet
$DOCKER_CMD compose $COMPOSE_ARGS up -d --build

LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
DEPLOY_PORT=$(grep -E '^APP_PORT=[0-9]+$' .env 2>/dev/null | tail -n 1 | cut -d= -f2)
DEPLOY_PORT=${DEPLOY_PORT:-8000}

echo ""
echo "========================================================================"
echo "  Deployment complete!"
echo ""
echo "  Host port used: ${DEPLOY_PORT}"
echo "  1. Local Network Access (LAN / ESP32):"
echo "     * Web App: http://${LOCAL_IP}:${DEPLOY_PORT}/"
echo "     * API:     http://${LOCAL_IP}:${DEPLOY_PORT}/api/v1"
echo ""
echo "  2. Cloudflare Zero Trust Tunnel Configuration:"
echo "     In CF Dash -> Tunnels -> Public Hostname:"
echo "       * Service Type: HTTP"
echo "       * URL:          api:8000"
echo "========================================================================"
echo ""
echo "Useful commands:"
echo "  $DOCKER_CMD compose logs -f api      # Backend logs"
echo "  $DOCKER_CMD compose logs -f tunnel   # Tunnel logs"
echo "  $DOCKER_CMD compose down             # Stop everything"
