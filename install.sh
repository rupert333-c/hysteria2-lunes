#!/usr/bin/env bash
# Hysteria2 稳定优先一键部署（Lunes Host 专用）
# 密码通过环境变量 AUTH_PASSWORD 传入

set -euo pipefail

# ===== 校验密码 =====
if [ -z "${AUTH_PASSWORD:-}" ]; then
  echo "❌ 未设置 AUTH_PASSWORD"
  echo "用法：AUTH_PASSWORD=你的密码 bash install.sh 3078"
  exit 1
fi

HYSTERIA_VERSION="v2.6.5"
SERVER_PORT="${1:-443}"
SNI="www.bing.com"

BASE_DIR="$HOME/hysteria"
BIN_PATH="$BASE_DIR/hysteria"
CONF_FILE="$BASE_DIR/server.yaml"
CERT_FILE="$BASE_DIR/cert.pem"
KEY_FILE="$BASE_DIR/key.pem"

mkdir -p "$BASE_DIR"
cd "$BASE_DIR"

echo "===================================="
echo " Hysteria2 部署（Lunes 专用）"
echo " 端口: ${SERVER_PORT}"
echo " 安装目录: ${BASE_DIR}"
echo "===================================="

# ===== 架构 =====
case "$(uname -m)" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "❌ 不支持的架构"; exit 1 ;;
esac

# ===== 下载 =====
if [ ! -f "$BIN_PATH" ]; then
  curl -L --retry 3 -o hysteria.tar.gz \
    "https://github.com/apernet/hysteria/releases/download/app/${HYSTERIA_VERSION}/hysteria-linux-${ARCH}.tar.gz"
  tar -xzf hysteria.tar.gz
  mv hysteria-linux-${ARCH} hysteria
  chmod +x hysteria
  rm -f hysteria.tar.gz
fi

# ===== 证书 =====
if [ ! -f "$CERT_FILE" ]; then
  openssl req -x509 -nodes -newkey ec \
    -pkeyopt ec_paramgen_curve:prime256v1 \
    -days 3650 \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" \
    -subj "/CN=${SNI}"
fi

# ===== 配置 =====
cat > "$CONF_FILE" <<EOF
listen: ":${SERVER_PORT}"
tls:
  cert: "${CERT_FILE}"
  key: "${KEY_FILE}"
  alpn:
    - h3
    - h3-29
auth:
  type: password
  password: "${AUTH_PASSWORD}"
bandwidth:
  up: "50mbps"
  down: "50mbps"
EOF

# ===== 启动（前台提示 + 后台运行）=====
pkill -f "hysteria.*server" 2>/dev/null || true
nohup "$BIN_PATH" server -c "$CONF_FILE" >/dev/null 2>&1 &

# ===== 获取 IP 并打印节点 =====
IP=$(curl -s https://api.ipify.org || hostname -I | awk '{print $1}')

echo ""
echo "✅ 部署完成（Lunes）"
echo ""
echo "📌 v2rayN 节点（请立即复制）："
echo ""
echo "hysteria2://${AUTH_PASSWORD}@${IP}:${SERVER_PORT}?sni=${SNI}&alpn=h3,h3-29&insecure=1#Hy2-Lunes"
echo ""
