#!/bin/bash
# Selfunnel Docker Installer
# Установка через Docker: поддерживает Linux-хост с Docker

set -e

IMAGE="ghcr.io/fatedier/frp:latest"
CONTAINER_NAME="selfunnel"
CONFIG_DIR="/opt/selfunnel"

echo "=== Selfunnel Docker Installer ==="
echo ""

# Check docker
if ! command -v docker &>/dev/null; then
    echo "Docker не найден. Установите Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

# Get token
TOKEN="${1:-}"
if [ -z "$TOKEN" ]; then
    echo "Введите Install Token из личного кабинета selfunnel.ru:"
    read -r TOKEN
fi

if [ -z "$TOKEN" ]; then
    echo "Токен не указан."
    exit 1
fi

# Download config
mkdir -p "$CONFIG_DIR"
CONFIG_FILE="$CONFIG_DIR/frpc.toml"

echo "Загрузка конфигурации..."
if ! curl -fsSL "https://selfunnel.ru/client/frpc.toml?token=$TOKEN" -o "$CONFIG_FILE"; then
    echo "Ошибка загрузки конфигурации."
    exit 1
fi

# Stop existing container
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

# Run frpc in Docker
docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    -v "$CONFIG_FILE:/etc/frp/frpc.toml" \
    -p 7000:7000 \
    --network host \
    fatedier/frp:latest \
    frpc -c /etc/frp/frpc.toml

echo ""
echo "=== Готово! ==="
docker logs "$CONTAINER_NAME" | tail -5