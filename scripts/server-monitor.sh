#!/bin/bash
# Server health monitor — runs every 10 min via cron, posts to n8n if warning detected

N8N_WEBHOOK="http://localhost:8082/webhook/server-alert"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:?TELEGRAM_CHAT_ID not set}"

WARNINGS=()

# CPU temp (k10temp Tctl) — warn >75°C
CPU_TEMP=$(sensors k10temp-pci-00c3 2>/dev/null | grep 'Tctl' | awk '{print $2}' | tr -d '+°C')
if [[ -n "$CPU_TEMP" ]] && (( $(echo "$CPU_TEMP > 75" | bc -l) )); then
  WARNINGS+=("🌡️ <b>CPU caliente:</b> ${CPU_TEMP}°C (límite: 75°C)")
fi

# GPU temp (amdgpu edge) — warn >75°C
GPU_TEMP=$(sensors amdgpu-pci-e500 2>/dev/null | grep 'edge' | awk '{print $2}' | tr -d '+°C')
if [[ -n "$GPU_TEMP" ]] && (( $(echo "$GPU_TEMP > 75" | bc -l) )); then
  WARNINGS+=("🌡️ <b>GPU caliente:</b> ${GPU_TEMP}°C (límite: 75°C)")
fi

# NVMe temp — warn >60°C
NVME_TEMP=$(sensors nvme-pci-0100 2>/dev/null | grep 'Composite' | awk '{print $2}' | tr -d '+°C')
if [[ -n "$NVME_TEMP" ]] && (( $(echo "$NVME_TEMP > 60" | bc -l) )); then
  WARNINGS+=("🌡️ <b>NVMe caliente:</b> ${NVME_TEMP}°C (límite: 60°C)")
fi

# Disk usage — warn >85%
DISK_PCT=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
if [[ "$DISK_PCT" -gt 85 ]]; then
  DISK_USED=$(df -h / | awk 'NR==2 {print $3"/"$2}')
  WARNINGS+=("💾 <b>Disco casi lleno:</b> ${DISK_PCT}% (${DISK_USED})")
fi

# Memory usage — warn >90%
MEM_TOTAL=$(free | awk '/^Mem:/ {print $2}')
MEM_USED=$(free | awk '/^Mem:/ {print $3}')
MEM_PCT=$(( MEM_USED * 100 / MEM_TOTAL ))
if [[ "$MEM_PCT" -gt 90 ]]; then
  MEM_H=$(free -h | awk '/^Mem:/ {print $3"/"$2}')
  WARNINGS+=("🧠 <b>RAM al límite:</b> ${MEM_PCT}% (${MEM_H})")
fi

# Send to n8n if there are warnings
if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  MSG="⚠️ <b>Alerta del servidor</b>\n\n$(printf '%s\n' "${WARNINGS[@]}")"
  curl -s -X POST "$N8N_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\": \"${TELEGRAM_CHAT_ID}\", \"message\": \"$(echo -e "$MSG" | sed 's/"/\\"/g')\"}" \
    > /dev/null
fi
