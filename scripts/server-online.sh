#!/bin/bash
# Post-reboot notification — run at @reboot via cron

N8N_WEBHOOK="http://localhost:8082/webhook/server-reboot"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:?TELEGRAM_CHAT_ID not set}"

# Wait for n8n to be ready
sleep 90
until curl -sf http://localhost:8088/healthz > /dev/null 2>&1; do
  sleep 10
done

curl -s -X POST "$N8N_WEBHOOK" \
  -H "Content-Type: application/json" \
  -d "{\"chat_id\": \"${TELEGRAM_CHAT_ID}\", \"event\": \"online\"}" \
  > /dev/null
