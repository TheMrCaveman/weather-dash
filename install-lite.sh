#!/usr/bin/env bash
# Weather dashboard kiosk for Raspberry Pi OS LITE (no desktop), Bookworm or Trixie.
# Boots straight into a full-screen Chromium using the "cage" kiosk compositor.
# Run as your normal user (not root):  bash install-lite.sh
set -euo pipefail

DIR="$HOME/weather-dash"
SRC="$(cd "$(dirname "$0")" && pwd)"

echo "==> Installing packages (cage, Chromium, fonts)…"
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends cage fonts-noto-color-emoji fonts-dejavu-core
if ! command -v chromium >/dev/null && ! command -v chromium-browser >/dev/null; then
  sudo apt-get install -y --no-install-recommends chromium || sudo apt-get install -y --no-install-recommends chromium-browser
fi
BROWSER="$(command -v chromium || command -v chromium-browser)"

echo "==> Copying dashboard to $DIR"
mkdir -p "$DIR"
if [ "$SRC" != "$DIR" ]; then cp "$SRC/index.html" "$DIR/index.html"; fi

echo "==> Creating launcher"
cat > "$DIR/start.sh" <<EOF
#!/usr/bin/env bash
# wait for the network so the first update succeeds
for i in \$(seq 1 30); do ping -c1 -W1 buienradar.nl >/dev/null 2>&1 && break; sleep 2; done
exec "$BROWSER" --kiosk --ozone-platform=wayland --noerrdialogs --disable-infobars --no-first-run \\
  --disable-session-crashed-bubble --disable-features=Translate \\
  --check-for-update-interval=31536000 --password-store=basic \\
  --disable-web-security \\
  --user-data-dir="$DIR/.chromium" "file://$DIR/index.html"
EOF
chmod +x "$DIR/start.sh"

echo "==> Giving $USER access to the display hardware"
sudo usermod -aG video,render,input "$USER"

echo "==> Auto-login on the console and start the dashboard there"
if command -v raspi-config >/dev/null; then
  sudo raspi-config nonint do_boot_behaviour B2 || true   # console, auto-login
fi
PROFILE="$HOME/.bash_profile"
touch "$PROFILE"
if ! grep -q "weather-dash/start.sh" "$PROFILE"; then
  cat >> "$PROFILE" <<'EOF'

# Start the weather dashboard on the physical screen (tty1) only, not over SSH
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ]; then
  exec cage -s -- "$HOME/weather-dash/start.sh"
fi
EOF
fi

echo "==> Disabling console screen blanking"
CMDLINE=/boot/firmware/cmdline.txt; [ -f "$CMDLINE" ] || CMDLINE=/boot/cmdline.txt
if [ -f "$CMDLINE" ] && ! grep -q "consoleblank=0" "$CMDLINE"; then
  sudo sed -i '1 s/$/ consoleblank=0/' "$CMDLINE"
fi

echo
echo "Done. Reboot to start the dashboard:  sudo reboot"
echo "To get back to a normal console: SSH in and run  pkill cage"
echo "(it starts again on the next reboot)."
