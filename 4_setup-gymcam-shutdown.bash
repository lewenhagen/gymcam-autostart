#!/usr/bin/env bash
#
# Gymcam — Steg 4: Tillåt avstängning utan lösenord
# Kör som användare (inte root): bash 4_setup-gymcam-shutdown.bash

set -e

GCUSER="$USER"
SUDOERS_FILE="/etc/sudoers.d/gymcam-poweroff"

# Tillåt användaren att köra poweroff utan lösenord
echo "$GCUSER ALL=(ALL) NOPASSWD: /bin/systemctl poweroff" | sudo tee "$SUDOERS_FILE" > /dev/null
sudo chmod 440 "$SUDOERS_FILE"

# Verifiera att filen är syntaktiskt korrekt
sudo visudo -cf "$SUDOERS_FILE" && echo "[OK] sudoers-fil verifierad." || {
  echo "[FEL] Ogiltig sudoers-syntax — tar bort filen."
  sudo rm -f "$SUDOERS_FILE"
  exit 1
}

echo ""
echo "[KLAR] $GCUSER kan nu stänga av systemet utan lösenord."
echo "       Kommando: sudo systemctl poweroff"
echo ""
echo "  Installation klar! Starta om för att testa hela kedjan:"
echo "  sudo reboot"
