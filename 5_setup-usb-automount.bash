#!/bin/bash
#
# Gymcam — Steg 5: USB-automonterings-setup
# Kör som användare (inte root): bash 5_setup-usb-automount.bash

set -e

SERVICE_NAME="gymcam"
APP_DIR="$HOME/gymcam"
ENV_FILE="$APP_DIR/.env"
USB_LABEL="GYMCAM"
USB_MOUNT="/mnt/$USB_LABEL"
UDEV_RULE="/etc/udev/rules.d/99-usb-automount.rules"

# -----------------------------------------------------------------------------------------------------------------------------------------------------

# === 1. Installera udisks2 ===
echo "[INFO] Installerar udisks2..."
sudo apt update -qq
sudo apt install -y udisks2
echo "[OK] 1. === udisks2 installerat ==="

# -----------------------------------------------------------------------------------------------------------------------------------------------------

# === 2. Skapa udev-regel för automontring ===
echo "[INFO] Skapar udev-regel..."

sudo mkdir -p "$USB_MOUNT"
sudo chown 1000:1000 "$USB_MOUNT"

sudo bash -c "cat > $UDEV_RULE" <<EOF
# Gymcam: montera USB-enhet med etikett $USB_LABEL till fast punkt
ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_LABEL}=="$USB_LABEL", ENV{ID_FS_USAGE}=="filesystem", \\
  RUN+="/usr/bin/systemd-mount --no-block --collect --mount-point=$USB_MOUNT -o uid=1000,gid=1000,umask=0000 %N"
EOF

echo "[OK] 2. === udev-regel skapad: $UDEV_RULE ==="

# -----------------------------------------------------------------------------------------------------------------------------------------------------

# === 3. Ladda om udev ===
sudo udevadm control --reload-rules
sudo udevadm trigger
echo "[OK] 3. === udev-regler omladdade ==="

# -----------------------------------------------------------------------------------------------------------------------------------------------------

# === 4. Fråga om USB-stickan ska formateras med etiketten GYMCAM ===
echo ""
echo "---------------------------------------------------------------"
echo "  USB-FORMATERING (valfritt men rekommenderat)"
echo "---------------------------------------------------------------"
echo "  Om du formaterar USB-stickan med etiketten '$USB_LABEL'"
echo "  kommer monteringspunkten alltid vara:"
echo "  $USB_MOUNT"
echo ""
echo "  VARNING: All data på USB-stickan raderas!"
echo ""

# Lista tillgängliga USB-enheter
echo "  Tillgängliga enheter:"
lsblk -o NAME,SIZE,TYPE,TRAN,LABEL | grep -E "disk|part" | grep -v "loop" || true
echo ""

read -r -p "Vill du formatera en USB-sticka nu? [j/N] " format_choice

if [[ "$format_choice" =~ ^[Jj]$ ]]; then
  echo ""
  read -r -p "  Ange enhetsnamn (t.ex. sdb, utan /dev/): " USB_DEV
  USB_DEV="/dev/${USB_DEV//\/dev\//}"   # hantera om användaren skriver /dev/sdb

  if [ ! -b "$USB_DEV" ] && [ ! -b "${USB_DEV}1" ]; then
    echo "[FEL] Enheten $USB_DEV hittades inte. Avbryter formatering."
  else
    # Kontrollera att det inte är systemdisken
    ROOT_DEV=$(findmnt -n -o SOURCE / | sed 's/[0-9]*$//')
    if [[ "$USB_DEV" == "$ROOT_DEV" ]]; then
      echo "[FEL] $USB_DEV är systemdisken — avbryter för säkerhets skull."
    else
      echo ""
      echo "  [VARNING] Formaterar $USB_DEV — ALL DATA RADERAS!"
      read -r -p "  Är du helt säker? Skriv 'ja' för att fortsätta: " confirm
      if [[ "$confirm" == "ja" ]]; then
        sudo apt install -y dosfstools > /dev/null
        # Avmontera om den är monterad
        sudo umount "${USB_DEV}"* 2>/dev/null || true
        # Skapa ny partitionstabell och partition
        sudo parted -s "$USB_DEV" mklabel msdos
        sudo parted -s "$USB_DEV" mkpart primary fat32 1MiB 100%
        # Formatera med etikett
        sudo mkfs.vfat -F 32 -n "$USB_LABEL" "${USB_DEV}1"
        echo "[OK] === $USB_DEV formaterad med etiketten '$USB_LABEL' ==="
      else
        echo "[INFO] Formatering avbruten."
      fi
    fi
  fi
else
  echo "[INFO] Hoppar över formatering."
  echo "       Montera din USB-sticka och notera dess monteringspunkt."
  echo "       Uppdatera sedan USB_MOUNT i $ENV_FILE manuellt."
fi

# -----------------------------------------------------------------------------------------------------------------------------------------------------

# === 5. Uppdatera USB_MOUNT i .env ===
if [ -f "$ENV_FILE" ]; then
  if grep -q "^USB_MOUNT=" "$ENV_FILE"; then
    sed -i "s|^USB_MOUNT=.*|USB_MOUNT=$USB_MOUNT|" "$ENV_FILE"
  else
    echo "USB_MOUNT=$USB_MOUNT" >> "$ENV_FILE"
  fi
  echo "[OK] 5. === USB_MOUNT=$USB_MOUNT inställt i $ENV_FILE ==="
else
  echo "[VARNING] $ENV_FILE hittades inte — skapa den manuellt med:"
  echo "          USB_MOUNT=$USB_MOUNT"
fi

# -----------------------------------------------------------------------------------------------------------------------------------------------------

# === 6. Uppdatera gymcam systemd-tjänst med nya USB_MOUNT ===
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
if [ -f "$SERVICE_FILE" ]; then
  sudo sed -i "s|Environment=USB_MOUNT=.*|Environment=USB_MOUNT=$USB_MOUNT|" "$SERVICE_FILE"
  sudo systemctl daemon-reload
  sudo systemctl restart "$SERVICE_NAME" 2>/dev/null || true
  echo "[OK] 6. === systemd-tjänst uppdaterad med USB_MOUNT=$USB_MOUNT ==="
else
  echo "[INFO] Ingen systemd-tjänst hittad — kör skript 3 först om du inte gjort det."
fi

# -----------------------------------------------------------------------------------------------------------------------------------------------------

echo ""
echo "[KLAR] USB-automonterings-setup klar."
echo ""
echo "  Monteringspunkt: $USB_MOUNT"
echo "  (USB-stickan monteras dit automatiskt när den ansluts)"
echo ""
echo "  Testa: Anslut USB-stickan och kör:"
echo "  ls $USB_MOUNT"
echo ""