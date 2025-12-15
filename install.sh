#!/usr/bin/env bash
# Hysteria2 稳定优先一键部署（lunes host）
# ⚠️ 密码通过环境变量 AUTH_PASSWORD 传入，脚本中不保存密码

set -euo pipefail

# ===== 必须的密码校验 =====
if [ -z "${AUTH_PASSWORD:-}" ]; then
  echo "❌ 未设置密码"
  echo "👉 用法示例："
  echo "AUTH_PASSWORD=你的密码 bash install.sh 3078"
  exit 1
fi

HYSTERIA_VERSION="v2.6.5"
SERVER_PORT="${1:-443}"
SNI="www.bing.com"
ALPN_LIST=("h3" "h3-29")

BASE_DIR="/root/hysteria"
BIN_PATH="${BASE_DIR}/hysteria"
CONF_FILE="${BASE_DIR}/server.yaml"
CERT_FILE="${BASE_DIR}/cert.pem"
KEY_FILE="${BASE_DIR}/key.pem"

mkdir -p "$BASE_DIR"
cd "$BASE_DIR"

echo "===================================="
echo " Hysteria2 稳定版部署（安全模式）"
echo " 端口: ${SERVER_PORT}"
echo "===================================="

# ===== 架构识别 =====
case "$(uname -m)" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "❌ 不支持的架构"; exit 1 ;;
esac

# ===== 下载 hysteria =====
if [ ! -f "$BIN_PATH" ]; then
  echo "⬇️ 下载 hysteria ${HYSTERIA_VERSION} (${ARCH})"
  curl -L --retry 3 -o hysteria.tar.gz \
    "https://github.com/apernet/hysteria/releases/download/app/${HYSTERIA_VERSION}/hysteria-linux-${ARCH}.tar.gz"

  tar -xzf hysteria.tar.gz
  mv hysteria-linux-${ARCH} hysteria
  chmod +x hysteria
  rm -f hysteria.tar.gz
fi

# ===== 生成证书 =====
if [ ! -f "$CERT_FILE" ]; then
  echo "🔐 生成自签证书"
  openssl req -x509 -nodes -newkey ec \
    -pkeyopt ec_paramgen_curve:prime256v1 \
    -days 3650 \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" \
    -subj "/CN=${SNI}"
fi

# ===== 写配置 =====
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
quic:
  max_idle_timeout: "30s"
  max_concurrent_streams: 16
  initial_stream_receive_window: 524288
  max_stream_receive_window: 1048576
  initial_conn_receive_window: 1048576
  max_conn_receive_window: 2097152
EOF

# ===== 启动 =====
pkill -f "hysteria.*server" || true
nohup "$BIN_PATH" server -c "$CONF_FILE" >/dev/null 2>&1 &

IP=$(curl -s https://api.ipify.org || echo "YOUR_IP")

echo ""
echo "✅ 部署完成（安全模式）"
echo "v2rayN 节点："
echo "hysteria2://${AUTH_PASSWORD}@${IP}:${SERVER_PORT}?sni=${SNI}&alpn=h3,h3-29&insecure=1#Hy2-Stable"
