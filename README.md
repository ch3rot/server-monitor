# server-monitor

![License](https://img.shields.io/github/license/ch3rot/server-monitor)
![Last commit](https://img.shields.io/github/last-commit/ch3rot/server-monitor)
![Shell](https://img.shields.io/badge/shell-bash-blue)
![n8n](https://img.shields.io/badge/n8n-v2.16+-orange)
![Platform](https://img.shields.io/badge/platform-linux-lightgrey)

Server health monitoring and automated reboot notifications using **cron scripts**, **n8n webhooks**, and **Telegram**.

Monitors CPU, GPU, NVMe temperatures, disk usage, and RAM. Sends alerts directly to Telegram. Also handles planned reboot notifications — before and after.

---

## How it works

```
Host (cron)                      n8n webhook                   Telegram
─────────────────────────────────────────────────────────────────────────
server-monitor.sh  (*/10 min)
  reads sensors + disk + RAM  ──►  POST /webhook/server-alert  ──►  ⚠️ alert

server-reboot.sh   (0 4 */3)
  planned reboot              ──►  POST /webhook/server-reboot ──►  🔄 rebooting in 60s
  waits 60s → executes reboot

server-online.sh   (@reboot)
  runs after boot             ──►  POST /webhook/server-reboot ──►  ✅ server online
```

The scripts contain no Telegram credentials — they only call local n8n webhooks. n8n handles the bot token and message delivery.

---

## Requirements

| Tool | Purpose |
|------|---------|
| `lm-sensors` | CPU / GPU / NVMe temperature readings |
| `bc` | Floating-point threshold comparisons |
| `curl` | Webhook calls |
| [n8n](https://n8n.io) | Workflow engine — receives webhooks, sends Telegram messages |

---

## Alert thresholds

| Sensor | Source | Threshold |
|--------|--------|-----------|
| CPU temp | `k10temp` Tctl | > 75°C |
| GPU temp | `amdgpu` edge | > 75°C |
| NVMe temp | `nvme-pci-0100` Composite | > 60°C |
| Disk usage | `/` | > 85% |
| RAM usage | — | > 90% |

Thresholds are defined as variables at the top of each script and can be adjusted freely.

---

## Setup

### 1. Install dependencies

```bash
sudo apt install lm-sensors bc curl -y
sudo sensors-detect --auto
```

### 2. Configure environment

```bash
cp .env.example .env
```

Set your Telegram chat ID in `.env`:
```
TELEGRAM_CHAT_ID=your_chat_id_here
```

To get your chat ID: message your bot on Telegram, then run:
```bash
curl -s "https://api.telegram.org/bot<BOT_TOKEN>/getUpdates" | grep '"id"'
```
Or simply message [@userinfobot](https://t.me/userinfobot).

Add the variable to `/etc/environment` so cron picks it up:
```bash
echo "TELEGRAM_CHAT_ID=your_chat_id" | sudo tee -a /etc/environment
```

### 3. Install scripts

```bash
sudo cp scripts/server-monitor.sh /usr/local/bin/
sudo cp scripts/server-reboot.sh /usr/local/bin/
sudo cp scripts/server-online.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/server-*.sh
```

### 4. Import n8n workflows

1. Open your n8n instance
2. Import both files from `workflows/`
3. Assign your **Telegram Bot** credential to each Telegram node
4. Activate both workflows

### 5. Configure cron

```bash
sudo crontab -e
```

```cron
*/10 * * * * /usr/local/bin/server-monitor.sh
0 4 */3 * * /usr/local/bin/server-reboot.sh
@reboot /usr/local/bin/server-online.sh
```

---

## Testing

Once n8n workflows are active, test each webhook manually:

```bash
# Health alert
curl -s -X POST http://localhost:8082/webhook/server-alert \
  -H "Content-Type: application/json" \
  --data-raw '{"chat_id": "YOUR_CHAT_ID", "message": "⚠️ <b>Test alert</b>\n\n🌡️ <b>CPU caliente:</b> 82°C"}'

# Reboot imminent
curl -s -X POST http://localhost:8082/webhook/server-reboot \
  -H "Content-Type: application/json" \
  --data-raw '{"chat_id": "YOUR_CHAT_ID", "event": "imminent"}'

# Server back online
curl -s -X POST http://localhost:8082/webhook/server-reboot \
  -H "Content-Type: application/json" \
  --data-raw '{"chat_id": "YOUR_CHAT_ID", "event": "online"}'
```

Expected response: `ok` — and the message arrives on Telegram.

---

## Project structure

```
server-monitor/
├── scripts/
│   ├── server-monitor.sh   # reads sensors, posts alert if threshold exceeded
│   ├── server-reboot.sh    # notifies Telegram, waits 60s, reboots
│   └── server-online.sh    # notifies Telegram when server comes back up
├── workflows/
│   ├── server-monitor.json # n8n: receives alert webhook → Telegram
│   └── server-reboot.json  # n8n: receives reboot webhook → Telegram (imminent/online)
├── .env.example
├── .gitignore
├── crontab.txt             # cron reference
└── LICENSE
```

---

## License

[MIT](LICENSE)
