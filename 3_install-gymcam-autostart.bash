#!/bin/bash
#
# Gymcam — Steg 3: Systemd-tjänst för automatisk start
# Kör som användare (inte root): bash 3_install-gymcam-autostart.bash

set -e

APP_DIR="$HOME/gymcam"
APP_SCRIPT="server.js"
SERVICE_NAME="gymcam"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

echo "[INFO] Sätter upp systemd-tjänst för gymcam..."

# -----------------------------------------------------------------------------------------------------------------------------------------------------

# === 1. Hitta node-binären (nvm installerar den utanför PATH för systemd) ===
if [ -f "$HOME/.nvm/nvm.sh" ]; then
  export NVM_DIR="$HOME/.nvm"
  source "$NVM_DIR/nvm.sh"
fi

NODE_BIN=$(which node 2>/dev/null || true)

if [ -z "$NODE_BIN" ]; then
  echo "[FEL] Node.js hittades inte. Kör skript 2 först."
  exit 1
fi

echo "[OK] 1. === Node.js hittad: $NODE_BIN ($(node --version)) ==="

# -----------------------------------------------------------------------------------------------------------------------------------------------------

# === 2. Kontrollera att app-mappen finns ===
if [ ! -d "$APP_DIR" ]; then
  echo "[FEL] App-mappen $APP_DIR saknas. Kör skript 2 först."
  exit 1
fi
echo "[OK] 2. === App-mappen hittad: $APP_DIR ==="

# -----------------------------------------------------------------------------------------------------------------------------------------------------

# === 3. Kontrollera .env ===
if [ ! -f "$APP_DIR/.env" ]; then
  echo "[VARNING] $APP_DIR/.env saknas — tjänsten kanske inte startar korrekt."
  echo "          Skapa .env med PASS, USB_MOUNT och OPEN_BROWSER=false"
fi

# Läs .env-värden för att baka in dem i tjänsten
ENV_PASS=$(grep -E '^PASS=' "$APP_DIR/.env" 2>/dev/null | cut -d= -f2- | tr -d '"' || echo "")
ENV_USB=$(grep -E '^USB_MOUNT=' "$APP_DIR/.env" 2>/dev/null | cut -d= -f2- | tr -d '"' || echo "/mnt/usb")

if [ -z "$ENV_PASS" ]; then
  echo "[VARNING] PASS är inte satt i .env — kamerainspelning fungerar inte."
fi

echo "[OK] 3. === .env läst ==="

# -----------------------------------------------------------------------------------------------------------------------------------------------------

# === 4. Skapa systemd-tjänst ===
# NODE_BIN är den absoluta sökvägen — systemd läser inte nvm
sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=Gymcam videosystem
After=network.target

[Service]
ExecStart=$NODE_BIN $APP_DIR/$APP_SCRIPT
WorkingDirectory=$APP_DIR
Restart=always
RestartSec=5
User=$USER
Environment=NODE_ENV=production
Environment=OPEN_BROWSER=false
Environment=PASS=$ENV_PASS
Environment=USB_MOUNT=$ENV_USB
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME

[Install]
WantedBy=multi-user.target
EOF

echo "[OK] 4. === Systemd-tjänst skapad: $SERVICE_FILE ==="

# -----------------------------------------------------------------------------------------------------------------------------------------------------

# === 5. Aktivera och starta tjänsten ===
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME.service"
sudo systemctl start "$SERVICE_NAME.service"

echo "[OK] 5. === $SERVICE_NAME aktiverad och startad ==="

# Verifiera att tjänsten körde
sleep 3
if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
  echo "[OK]    Tjänsten körs."
else
  echo "[VARNING] Tjänsten verkar inte köra."
  echo "          Kontrollera loggar: journalctl -u $SERVICE_NAME -f"
fi

# -----------------------------------------------------------------------------------------------------------------------------------------------------

echo ""
echo "[KLAR] gymcam systemd-tjänst konfigurerad."
echo ""
echo "  Användbara kommandon:"
echo "  sudo systemctl status $SERVICE_NAME     — kontrollera status"
echo "  sudo systemctl restart $SERVICE_NAME    — starta om"
echo "  journalctl -u $SERVICE_NAME -f          — liveloggar"
echo ""
echo "  Kör nästa skript: bash 4_setup-gymcam-shutdown.bash"
echo ""

read -r -p "Starta om nu? [J/n] " choice
if [[ "$choice" =~ ^[Jj]$ || -z "$choice" ]]; then
  echo "Startar om systemet..."
  sudo reboot
else
  echo "Kom ihåg att starta om manuellt: sudo reboot"
fi
