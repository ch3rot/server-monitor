# server-monitor

Server health monitoring and reboot automation via cron scripts + n8n webhooks + Telegram notifications.

## Architecture

```
Host (cron)                     n8n webhook                  Telegram
────────────────────────────────────────────────────────────────────
server-monitor.sh (*/10 min)
  CPU/GPU/NVMe/disk/RAM  ──►  /webhook/server-alert   ──►  ⚠️ alert message

server-reboot.sh (0 4 */3)
  planned reboot         ──►  /webhook/server-reboot  ──►  🔄 rebooting in 60s
  → waits 60s → reboot

server-online.sh (@reboot)
  server back online     ──►  /webhook/server-reboot  ──►  ✅ server online
```

## Requirements

- `lm-sensors` — CPU/GPU/NVMe temperature readings
- `bc` — floating-point comparisons
- `curl` — webhook calls
- n8n running with workflows imported and active
- Telegram bot credential configured in n8n

## Setup

### 1. Configure environment

```bash
cp .env.example .env
# Edit .env and set TELEGRAM_CHAT_ID
```

Add to `/etc/environment` so cron picks it up:
```
TELEGRAM_CHAT_ID=your_chat_id
```

### 2. Install scripts

```bash
sudo cp scripts/server-monitor.sh /usr/local/bin/
sudo cp scripts/server-reboot.sh /usr/local/bin/
sudo cp scripts/server-online.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/server-*.sh
```

### 3. Import n8n workflows

Import both files from `workflows/` in the n8n UI and assign the `Telegram Bot` credential to each Telegram node. Activate both workflows.

### 4. Add cron entries

```bash
sudo crontab -e
```

```cron
*/10 * * * * /usr/local/bin/server-monitor.sh
0 4 */3 * * /usr/local/bin/server-reboot.sh
@reboot /usr/local/bin/server-online.sh
```

## Alert thresholds

| Sensor | Source | Threshold |
|--------|--------|-----------|
| CPU temp | k10temp Tctl | > 75°C |
| GPU temp | amdgpu edge | > 75°C |
| NVMe temp | nvme-pci-0100 Composite | > 60°C |
| Disk usage | / | > 85% |
| RAM usage | — | > 90% |

## Test webhooks

```bash
# Alert
curl -s -X POST http://localhost:8082/webhook/server-alert \
  -H "Content-Type: application/json" \
  --data-raw '{"chat_id": "YOUR_CHAT_ID", "message": "⚠️ <b>Test alert</b>"}'

# Reboot imminent
curl -s -X POST http://localhost:8082/webhook/server-reboot \
  -H "Content-Type: application/json" \
  --data-raw '{"chat_id": "YOUR_CHAT_ID", "event": "imminent"}'

# Server online
curl -s -X POST http://localhost:8082/webhook/server-reboot \
  -H "Content-Type: application/json" \
  --data-raw '{"chat_id": "YOUR_CHAT_ID", "event": "online"}'
```
