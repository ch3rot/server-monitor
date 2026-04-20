#!/bin/bash
# Pre-reboot notification — call before rebooting, waits 60s then reboots

N8N_WEBHOOK="http://localhost:8082/webhook/server-reboot"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:?TELEGRAM_CHAT_ID not set}"

curl -s -X POST "$N8N_WEBHOOK" \
  -H "Content-Type: application/json" \
  -d "{\"chat_id\": \"${TELEGRAM_CHAT_ID}\", \"event\": \"imminent\"}" \
  > /dev/null

sleep 60
/sbin/reboot
