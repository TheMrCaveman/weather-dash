# Rotterdam weather dashboard (Raspberry Pi 4)

A single-page, full-screen weather display. Data comes from Open-Meteo
(free, no API key; for the Netherlands it blends in KNMI's HARMONIE model).

Layout in the style of a Home Assistant weather dashboard:
- Buienradar rain radar map (the whole map links to buienradar.nl)
- Current conditions from Buienradar's Rotterdam weather station, 5-day forecast
- Rain next 2 hours from Buienradar (5-minute steps), rain last 24 h
- Temperature/dew point, wind/gusts, pressure, humidity charts: last 24 h + next 12 h (Open-Meteo)
Refreshes every 5 minutes. If Buienradar can't be reached, it falls back to Open-Meteo.
Buienradar data is free for non-commercial use with credit to Buienradar.nl.

## Install — Pi as a web server (no monitor) ← recommended
Every PC on the network opens the dashboard in its browser. The Pi also fetches
Buienradar's data for them, so everything works in any browser without special settings.

On the Pi (Raspberry Pi OS Lite):
```
sudo apt-get install -y git
git clone https://github.com/TheMrCaveman/weather-dash.git ~/weather-dash
cd ~/weather-dash && bash install-server.sh
```
Then open **http://<pi-hostname>.local** (e.g. http://weather.local) or http://<pi-ip> on any PC.

Update later: `cd ~/weather-dash && git pull && sudo systemctl restart weather-dash`
Status / logs: `systemctl status weather-dash` · `journalctl -u weather-dash -n 30`

## Alternative — Pi with its own screen, no desktop (kiosk)
1. Flash **Raspberry Pi OS Lite (64-bit)** with Raspberry Pi Imager. In the Imager settings,
   set your username/password and Wi-Fi, and enable SSH.
2. Boot the Pi with the screen connected and run:
   ```
   sudo apt-get install -y git
   git clone https://github.com/TheMrCaveman/weather-dash.git ~/weather-dash
   cd ~/weather-dash && bash install-lite.sh && sudo reboot
   ```
3. Update later: `cd ~/weather-dash && git pull && sudo reboot`

It auto-logs in on the screen and starts Chromium full-screen in `cage` (a minimal
kiosk compositor). SSH sessions are unaffected. To stop it: SSH in and `pkill cage`.

## Alternative — Pi with its own screen and desktop (kiosk)
1. Raspberry Pi OS **with desktop**, connected to Wi-Fi/ethernet.
2. `git clone https://github.com/TheMrCaveman/weather-dash.git ~/weather-dash`
3. `cd ~/weather-dash && bash install.sh && sudo reboot`

## Tweaks (top of the `<script>` in index.html)
- `LAT` / `LON` – location (currently Rotterdam, 51.922 / 4.479)
- `REFRESH_MIN` – data refresh interval
- `BR_STATION` – Buienradar station id (6344 = Rotterdam)
- Open `index.html?demo` in any browser to preview with fake data.

## Notes
- Screen off at night: add to `crontab -e`
  `0 23 * * * WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/$(id -u) wlr-randr --output HDMI-A-1 --off`
  `0 7 * * * WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/$(id -u) wlr-randr --output HDMI-A-1 --on`
  (run `wlr-randr` once to see your output name; on the official DSI screen it's `DSI-1`).

- The kiosk browser runs with `--disable-web-security` (in its own separate profile) so the
  local page may read Buienradar's data, which doesn't allow cross-site requests.
