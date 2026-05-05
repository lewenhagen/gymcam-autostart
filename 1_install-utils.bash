#!/bin/bash
#
# Gymcam — Steg 1: Browser/Kiosk-installation
# Kör som användare (inte root): bash 1_install-utils.bash

GCUSER="$USER"

set -e

# === 1. Installera nödvändiga paket ===
sudo apt update
sudo apt install -y --no-install-recommends \
  xorg \
  curl \
  xserver-xorg-legacy \
  openbox \
  chromium \
  unclutter \
  console-data \
  git \
  ffmpeg \
  jq \
  nmap

echo "[OK] 1. === Paket installerade (xorg, chromium, openbox, ffmpeg m.fl.) ==="

# -----------------------------------------------------------------------------------------------------------------------------------------------------

# === 2. Tillåt X att starta utan root ===
sudo sed -i 's/^allowed_users.*/allowed_users=anybody/' /etc/X11/Xwrapper.config \
  || echo "allowed_users=anybody" | sudo tee -a /etc/X11/Xwrapper.config > /dev/null

echo "[OK] 2. === X tillåts starta utan root ==="

# -----------------------------------------------------------------------------------------------------------------------------------------------------

# === 3. Lägg till användare i rätt grupper ===
sudo usermod -aG video,audio,input "$GCUSER"
echo "[OK] 3. === $GCUSER tillagd i grupperna video, audio, input ==="

# -----------------------------------------------------------------------------------------------------------------------------------------------------

# === 4. Aktivera autologin för $GCUSER på TTY1 ===
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
cat << EOF | sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $GCUSER --noclear %I $TERM
EOF
echo "[OK] 4. === Autologin på TTY1 aktiverat för $GCUSER ==="

# -----------------------------------------------------------------------------------------------------------------------------------------------------

# === 5. Skapa video-mapp för inspelningar ===
mkdir -p "$HOME/gymcam/video"
echo "[OK] 5. === video/-mapp skapad under $HOME/gymcam/video ==="

# -----------------------------------------------------------------------------------------------------------------------------------------------------

# === 6. Sätt upp .xinitrc ===
cat > ~/.xinitrc <<'EOF'
#!/bin/bash
xset -dpms
xset s off
xset s noblank

# Dölj musmarkören
unclutter -idle 0 -root &

export DISPLAY=:0
export XAUTHORITY=$HOME/.Xauthority

# Vänta på att en skärm ansluts
while ! xrandr | grep " connected"; do
  sleep 1
done

# Låt Xorg välja bästa upplösning automatiskt
for output in $(xrandr | grep " connected" | cut -d" " -f1); do
  xrandr --output "$output" --auto
done

# Starta Openbox
openbox-session &

# Vänta tills gymcam-servern svarar
until curl -s http://localhost:3000 > /dev/null; do
  echo "Väntar på gymcam-servern..."
  sleep 1
done

# Starta Chromium i kioskläge — startas om automatiskt om det kraschar
while true; do
  chromium \
    --noerrdialogs \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --disable-features=TranslateUI,Translate \
    --disable-translate \
    --lang=sv \
    --accept-lang=sv \
    --no-first-run \
    --no-default-browser-check \
    --disable-popup-blocking \
    --incognito \
    --start-fullscreen \
    --user-data-dir=$HOME/.chromium-kiosk \
    --kiosk "http://localhost:3000"

  echo "[VARNING] Chromium kraschade eller avslutades, startar om om 5s..." >&2
  sleep 5
done
EOF

chmod +x ~/.xinitrc
echo "[OK] 6. === .xinitrc konfigurerat för $GCUSER ==="

# -----------------------------------------------------------------------------------------------------------------------------------------------------

# === 7. Autostart av X när $GCUSER loggar in på TTY1 ===
cat > ~/.bash_profile <<'EOF'
if [[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]]; then
  startx
fi
EOF

echo "[OK] 7. === X autostartar vid inloggning på TTY1 ==="

# -----------------------------------------------------------------------------------------------------------------------------------------------------

# === 8. Konfigurera Chromium kioskprofil (undertrycker popups) ===
mkdir -p "$HOME/.chromium-kiosk/Default"
chmod 700 "$HOME/.chromium-kiosk"
touch "$HOME/.chromium-kiosk/First Run"

cat > "$HOME/.chromium-kiosk/Default/Preferences" <<'EOF'
{
  "exit_type": "Normal",
  "exited_cleanly": true,
  "translate": { "enabled": false },
  "translate_blocked_languages": ["sv"],
  "intl": { "accept_languages": "sv,sv-SE" }
}
EOF

echo "[OK] 8. === Chromium kioskprofil konfigurerad ==="

# -----------------------------------------------------------------------------------------------------------------------------------------------------

echo ""
echo "[KLAR] Gymcam browser/kiosk-installation klar."
echo "       Kör nästa skript: bash 2_install-gymcam.bash"
