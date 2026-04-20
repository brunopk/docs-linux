#!/bin/bash

DOMAIN="YOUR_DOMAIN"
TOKEN="YOUR_TOKEN"
IP_FILE="/var/lib/duckdns/last_ip"

# Fetch current public IP from external service
CURRENT_IP=$(curl -s https://api.ipify.org)

# -z: true if CURRENT_IP is empty (curl failed or returned nothing)
if [[ -z "$CURRENT_IP" ]]; then
    echo "ERROR: Could not retrieve current IP" >&2
    exit 1
fi

# Read last known IP from file; if file doesn't exist, LAST_IP will be empty
LAST_IP=$(cat "$IP_FILE" 2>/dev/null)

# Skip update if IP hasn't changed
if [[ "$CURRENT_IP" == "$LAST_IP" ]]; then
    exit 0
fi

# IP changed — send update to DuckDNS
# Token is passed via stdin (-K -) to avoid exposing it in the process list
RESPONSE=$(echo url="https://www.duckdns.org/update?domains=${DOMAIN}&token=${TOKEN}&ip=${CURRENT_IP}" | curl -sk -K -)

if [[ "$RESPONSE" == "OK" ]]; then
    # :-none: if LAST_IP is unset/empty (first run), print "none" instead
    echo "IP changed: ${LAST_IP:-none} -> ${CURRENT_IP}"
    echo "$CURRENT_IP" > "$IP_FILE"
else
    echo "ERROR: DuckDNS update failed (response: ${RESPONSE})" >&2
    exit 1
fi
