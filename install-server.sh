#!/usr/bin/env bash
# Run the weather dashboard as a web server on a headless Raspberry Pi (no monitor).
# Every PC on the network can then open  http://<hostname>.local
# Run from the cloned repo folder as your normal user:  bash install-server.sh
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
PORT="${PORT:-80}"

echo "==> Undoing the screen kiosk setup (if it was installed)"
if [ -f "$HOME/.bash_profile" ] && grep -q "weather-dash/start.sh" "$HOME/.bash_profile"; then
  python3 - "$HOME/.bash_profile" <<'EOF'
import re, sys
p = sys.argv[1]; s = open(p).read()
s = re.sub(r"\n# Start the weather dashboard on the physical screen.*?\nfi\n", "\n", s, flags=re.S)
open(p, "w").write(s)
EOF
fi
command -v raspi-config >/dev/null && sudo raspi-config nonint do_boot_behaviour B1 || true  # console, no auto-login

echo "==> Installing service"
sudo tee /etc/systemd/system/weather-dash.service >/dev/null <<EOF
[Unit]
Description=Weather dashboard web server
Wants=network-online.target
After=network-online.target

[Service]
User=$USER
WorkingDirectory=$DIR
ExecStart=/usr/bin/python3 $DIR/server.py $PORT
Restart=always
RestartSec=5
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now weather-dash.service
sudo systemctl restart weather-dash.service

# make sure <hostname>.local works on the network
sudo apt-get install -y avahi-daemon >/dev/null 2>&1 || true

sleep 2
HOST="$(hostname)"; IP="$(hostname -I | awk '{print $1}')"
SUFFIX=""; [ "$PORT" != "80" ] && SUFFIX=":$PORT"
echo
if systemctl is-active --quiet weather-dash.service; then
  echo "Running. Open on any PC on the network:"
  echo "   http://$HOST.local$SUFFIX"
  echo "   http://$IP$SUFFIX"
else
  echo "Service did not start. Check:  journalctl -u weather-dash -n 30"
fi
