#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# Hysteria2 稳定 & 安全部署脚本（基于原始可用版本）

set -e

# ====== 安全：必须通过环境变量传入密码 ======
if [ -z "${AUTH_PASSWORD:-}" ]; then
    echo "❌ 未设置 AUTH_PASSWORD"
    echo "👉 用法：AUTH_PASSWORD=你的密码 bash hy2.sh 端口"
    exit 1
fi

# ---------- 默认配置 ----------
HYSTERIA_VERSION="v2.6.5"
DEFAULT_PORT=22222
CERT_FILE="cert.pem"
KEY_FILE="key.pem"
SNI="www.bing.com"
ALPN="h3"
# ------------------------------

BASE_DIR="$HOME/hysteria"
mkdir -p "$BASE_DIR"
cd "$BASE_DIR"

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Hysteria2 稳定 & 安全部署（Lunes 适配）"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

# ---------- 获取端口 ----------
if [[ $# -ge 1 && -n "${1:-}" ]]; then
    SERVER_PORT="$1"
else
    SERVER_PORT="$DEFAULT_PORT"
fi

echo "端口: $SERVER_PORT"

# ---------- 检测架构 ----------
arch_name() {
    local machine
    machine=$(uname -m | tr '[:upper:]' '[:lower:]')
    if [[ "$machine" == *"arm64"* ]] || [[ "$machine" == *"aarch64"* ]]; then
        echo "arm64"
    elif [[ "$machine" == *"x86_64"* ]] || [[ "$machine" == *"amd64"* ]]; then
        echo "amd64"
    else
        echo ""
    fi
}

ARCH=$(arch_name)
if [ -z "$ARCH" ]; then
    echo "❌ 无法识别 CPU 架构: $(uname -m)"
    exit 1
fi

BIN_PATH="${BASE_DIR}/hysteria"

# ---------- 下载二进制（单文件，稳定） ----------
if [ ! -f "$BIN_PATH" ]; then
    URL="https://github.com/apernet/hysteria/releases/download/app/${HYSTERIA_VERSION}/hysteria-linux-${ARCH}"
    echo "下载: $URL"
    curl -L --retry 3 --connect-timeout 30 -o "$BIN_PATH" "$URL"
    chmod +x "$BIN_PATH"
fi

# ---------- 生成证书 ----------
if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    openssl req -x509 -nodes -newkey ec \
        -pkeyopt ec_paramgen_curve:prime256v1 \
        -days 3650 \
        -keyout "$KEY_FILE" \
        -out "$CERT_FILE" \
        -subj "/CN=${SNI}"
fi

# ---------- 写配置 ----------
cat > server.yaml <<EOF
listen: ":${SERVER_PORT}"
tls:
  cert: "${BASE_DIR}/${CERT_FILE}"
  key: "${BASE_DIR}/${KEY_FILE}"
  alpn:
    - "${ALPN}"
auth:
  type: password
  password: "${AUTH_PASSWORD}"
EOF

# ---------- 获取 IP ----------
SERVER_IP=$(curl -s https://api.ipify.org || echo "YOUR_SERVER_IP")

# ---------- 打印节点（一定可见） ----------
echo ""
echo "================= 节 点 ================="
echo "hysteria2://${AUTH_PASSWORD}@${SERVER_IP}:${SERVER_PORT}?sni=${SNI}&alpn=${ALPN}&insecure=1#Hy2-Lunes"
echo "========================================="
echo ""

# ---------- 启动 ----------
echo "启动 Hysteria2..."
exec "$BIN_PATH" server -c server.yaml
