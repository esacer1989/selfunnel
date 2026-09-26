#!/bin/bash
# Selfunnel Client Installer (Linux / macOS)
# Официальный установочный скрипт
# Использование: curl -sSL https://selfunnel.ru/install.sh | sh
# или с токеном: curl -sSL https://selfunnel.ru/install.sh?token=YOUR_TOKEN | sh

set -e

INSTALL_DIR="/opt/selfunnel"
CONFIG_FILE="$INSTALL_DIR/frpc.toml"
FRP_VERSION="0.61.1"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Selfunnel Client Installer ===${NC}"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Пожалуйста, запустите от имени root:${NC}"
    echo "  sudo curl -sSL https://selfunnel.ru/install.sh | sh"
    exit 1
fi

# Detect OS and architecture
OS=$(uname -s)
case "$OS" in
    Linux)  OS_LABEL="linux" ;;
    Darwin) OS_LABEL="darwin" ;;
    *)
        echo -e "${RED}Неподдерживаемая ОС: $OS${NC}"
        exit 1
        ;;
esac

ARCH=$(uname -m)
case "$ARCH" in
    x86_64)           ARCH="amd64" ;;
    aarch64|arm64)    ARCH="arm64" ;;
    armv7l|armv6l)    ARCH="arm" ;;
    *)
        echo -e "${RED}Неподдерживаемая архитектура: $ARCH${NC}"
        exit 1
        ;;
esac

echo "ОС: $OS ($OS_LABEL), архитектура: $ARCH"

# Create directory
mkdir -p "$INSTALL_DIR"

# Download frpc
echo "Скачивание frpc v${FRP_VERSION}..."
TMP_DIR=$(mktemp -d)
ARCHIVE="$TMP_DIR/frp.tar.gz"

if ! curl -fL "https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_${OS_LABEL}_${ARCH}.tar.gz" \
    -o "$ARCHIVE" 2>/dev/null; then
    echo -e "${RED}Ошибка скачивания frpc. Проверьте интернет-соединение.${NC}"
    rm -rf "$TMP_DIR"
    exit 1
fi

tar xzf "$ARCHIVE" -C "$TMP_DIR"
cp "$TMP_DIR/frp_${FRP_VERSION}_${OS_LABEL}_${ARCH}/frpc" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/frpc"
rm -rf "$TMP_DIR"

echo -e "${GREEN}frpc установлен${NC}"

# Get install token from URL or prompt
TOKEN="${1:-}"
if [ -z "$TOKEN" ]; then
    echo ""
    echo -e "${YELLOW}Введите Install Token из личного кабинета selfunnel.ru:${NC}"
    echo -n "  Token: "
    read -r TOKEN
fi

if [ -z "$TOKEN" ]; then
    echo -e "${RED}Токен не указан. Зарегистрируйтесь на https://selfunnel.ru и получите токен в личном кабинете.${NC}"
    exit 1
fi

# Download tunnel configuration
echo "Загрузка конфигурации туннелей..."
if ! curl -fsSL "https://selfunnel.ru/client/frpc.toml?token=$TOKEN" -o "$CONFIG_FILE" 2>/dev/null; then
    echo -e "${RED}Ошибка загрузки конфигурации. Проверьте токен.${NC}"
    exit 1
fi

echo -e "${GREEN}Конфигурация сохранена${NC}"

if [ "$OS" = "Linux" ]; then
    # Install as systemd service
    echo "Установка systemd-сервиса..."
    cat > /etc/systemd/system/selfunnel.service << 'EOF'
[Unit]
Description=Selfunnel tunnel client
After=network.target

[Service]
Type=simple
ExecStart=/opt/selfunnel/frpc -c /opt/selfunnel/frpc.toml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now selfunnel.service

    echo ""
    echo -e "${GREEN}=== Установка завершена! ===${NC}"
    echo ""
    echo "Статус: systemctl status selfunnel"
    echo "Логи:   journalctl -u selfunnel -f"
    echo "Конфиг: $CONFIG_FILE"
    echo ""

    # Show tunnel addresses
    echo "Активные туннели:"
    grep -E "^subdomain|^  subdomain" "$CONFIG_FILE" | sed 's/.*subdomain.*=.*"/  https:\/\//;s/"//' | while read -r url; do
        echo "  $url.selfunnel.ru"
    done

else
    # macOS: launchd agent
    echo "Установка launchd-агента..."
    mkdir -p /Library/LaunchDaemons
    cat > /Library/LaunchDaemons/com.selfunnel.client.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.selfunnel.client</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/selfunnel/frpc</string>
        <string>-c</string>
        <string>/opt/selfunnel/frpc.toml</string>
    </array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
</dict>
</plist>
EOF

    launchctl load /Library/LaunchDaemons/com.selfunnel.client.plist
    echo ""
    echo -e "${GREEN}=== Установка завершена! ===${NC}"
    echo ""
    echo "Проверка: launchctl list | grep selfunnel"
fi