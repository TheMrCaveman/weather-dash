#!/usr/bin/env bash
# Weather dashboard kiosk installer for Raspberry Pi OS (Desktop, Bookworm or Trixie)
# Run as your normal desktop user (not root):  bash install.sh
set -euo pipefail

DIR="$HOME/weather-dash"
SRC="$(cd "$(dirname "$0")" && pwd)"

echo "==> Installing packages (Chromium, emoji font)…"
sudo apt-get update -qq
sudo apt-get install -y fonts-noto-color-emoji
if ! command -v chromium >/dev/null && ! command -v chromium-browser >/dev/null; then
  sudo apt-get install -y chromium || sudo apt-get install -y chromium-browser
fi
BROWSER="$(command -v chromium || command -v chromium-browser)"

echo "==> Copying dashboard to $DIR"
mkdir -p "$DIR"
if [ "$SRC" != "$DIR" ]; then cp "$SRC/index.html" "$DIR/index.html"; fi

echo "==> Creating launcher"
cat > "$DIR/start.sh" <<EOF
#!/usr/bin/env bash
# wait for the network so the first fetch succeeds
for i in \$(seq 1 30); do ping -c1 -W1 buienradar.nl >/dev/null 2>&1 && break; sleep 2; done
exec "$BROWSER" --kiosk --noerrdialogs --disable-infobars --no-first-run \\
  --disable-session-crashed-bubble --disable-features=Translate \\
  --check-for-update-interval=31536000 --password-store=basic \\
  --disable-web-security \\
  --user-data-dir="$DIR/.chromium" "file://$DIR/index.html"
EOF
chmod +x "$DIR/start.sh"

echo "==> Enabling autostart"
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/weather-dash.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Weather Dashboard
Exec=$DIR/start.sh
X-GNOME-Autostart-enabled=true
EOF

# labwc (default compositor on recent Pi OS) – also add to its autostart in case
# XDG autostart is not processed on this image
if [ -d /etc/xdg/labwc ]; then
  mkdir -p "$HOME/.config/labwc"
  AS="$HOME/.config/labwc/autostart"
  [ -f "$AS" ] || { [ -f /etc/xdg/labwc/autostart ] && cp /etc/xdg/labwc/autostart "$AS" || touch "$AS"; }
  if ! grep -q "lxsession-xdg-autostart" "$AS" && ! grep -q weather-dash "$AS"; then
    echo "$DIR/start.sh &" >> "$AS"
  fi
fi

echo "==> Disabling screen blanking, enabling desktop auto-login"
if command -v raspi-config >/dev/null; then
  sudo raspi-config nonint do_blanking 1 || true   # 1 = disable blanking
  sudo raspi-config nonint do_boot_behaviour B4 || true  # desktop, auto-login
fi

echo
echo "Done. Reboot to start the dashboard:  sudo reboot"
echo "Preview layout without network:        $BROWSER file://$DIR/index.html?demo"
echo "Exit kiosk mode:                       Alt+F4 (or ssh in and: pkill chromium)"
