#!/bin/bash
#
# Gymcam — Steg 2: Installera gymcam-applikationen
# Kör som användare (inte root): bash 2_install-gymcam.bash

set -e

function printStatus {
  echo "=== [OK] $1 ==="
}

APP_DIR="$HOME/gymcam"

# -----------------------------------------------------------------------------------------------------------------------------------------------------

# === 1. Installera nvm + Node.js LTS ===
curl -s -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash

export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"

nvm install --lts
printStatus "Node.js $(node --version) installerat via nvm"

# -----------------------------------------------------------------------------------------------------------------------------------------------------

# === 2. Klona gymcam ===
if [ -d "$APP_DIR" ]; then
  echo "[INFO] $APP_DIR finns redan — uppdaterar med git pull..."
  cd "$APP_DIR" && git pull
else
  git clone https://github.com/lewenhagen/gymcam.git "$APP_DIR"
fi
printStatus "gymcam klonat till $APP_DIR"

# -----------------------------------------------------------------------------------------------------------------------------------------------------

# === 3. Installera npm-beroenden ===
cd "$APP_DIR"
npm install
printStatus "npm-paket installerade"

# -----------------------------------------------------------------------------------------------------------------------------------------------------

# === 4. Skapa video/-mapp om den saknas ===
mkdir -p "$APP_DIR/video"
printStatus "video/-mapp säkerställd"

# -----------------------------------------------------------------------------------------------------------------------------------------------------

# === 5. Skapa .env om den saknas ===
if [ ! -f "$APP_DIR/.env" ]; then
  cat > "$APP_DIR/.env" <<'EOF'
# Lösenord för kamerornas RTSP-strömmar
PASS=ditt_kameralösenord

# Monteringspunkt för USB-minne (justera efter din setup)
# Exempel: USB_MOUNT=/media/gymcam/USBMINNE
USB_MOUNT=/mnt/usb

# Öppna inte webbläsare automatiskt (hanteras av xinitrc)
OPEN_BROWSER=false
EOF
  echo "[VARNING] .env-fil skapad med platshållare."
  echo "          Redigera $APP_DIR/.env och fyll i PASS och USB_MOUNT innan du startar."
else
  printStatus ".env finns redan — ingen ändring gjord"
fi

# -----------------------------------------------------------------------------------------------------------------------------------------------------

# === 6. Skapa cameras.json om den saknas ===
if [ ! -f "$APP_DIR/config/cameras.json" ]; then
  mkdir -p "$APP_DIR/config"
  cat > "$APP_DIR/config/cameras.json" <<'EOF'
[
  { "name": "Kamera 1", "ip": "192.168.1.10" },
  { "name": "Kamera 2", "ip": "192.168.1.11" },
  { "name": "Kamera 3", "ip": "192.168.1.12" },
  { "name": "Kamera 4", "ip": "192.168.1.13" }
]
EOF
  echo "[VARNING] config/cameras.json skapad med exempel-IP-adresser."
  echo "          Redigera $APP_DIR/config/cameras.json med rätt IP-adresser."
else
  printStatus "config/cameras.json finns redan"
fi

# -----------------------------------------------------------------------------------------------------------------------------------------------------

echo ""
echo "[KLAR] gymcam installerat i $APP_DIR"
echo ""
echo "  Kom ihåg att redigera:"
echo "  1. $APP_DIR/.env               — sätt PASS och USB_MOUNT"
echo "  2. $APP_DIR/config/cameras.json — sätt rätt kamera-IP-adresser"
echo ""
echo "  Kör nästa skript: bash 3_install-gymcam-autostart.bash"
