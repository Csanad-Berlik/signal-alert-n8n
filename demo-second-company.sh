#!/usr/bin/env bash
# Send three visitor-days on /pricing for a second company, to show that a new target needs no workflow edit.
#
#   WEBHOOK_URL=http://localhost:5678/webhook/<path> SIGNAL_SECRET=<secret> bash demo-second-company.sh [domain] [first_day]
#
#   domain     must be a row in the targets table with path /pricing (default: initech.com)
#   first_day  day of October 2026 for the first event, the next two are the following days (default: 14)
#
# Expected: all three HTTP codes are 200. The third event makes the count reach 3, so the run goes
# through Create a company (the company is new in HubSpot) and the HubSpot workflow makes one task.
# To run it again for the same domain, empty the alerts table first or pick a first_day more than 7 days later.

set -u
: "${WEBHOOK_URL:?Set WEBHOOK_URL to the production webhook URL}"
: "${SIGNAL_SECRET:?Set SIGNAL_SECRET to the header auth secret}"
DOMAIN="${1:-initech.com}"
FIRST="${2:-14}"
TAG="$(date +%H%M%S)"

i=0
for who in Fay Gus Hana; do
  day=$(printf '%02d' $((FIRST + i)))
  i=$((i + 1))
  body=$(printf '{"event_id":"%s-d%s","visitor_id":"%s","email":"%s@example.com","domain":"%s","path":"/pricing","ts":"2026-10-%sT09:15:00Z"}' \
    "$TAG" "$i" "$who" "$(echo "$who" | tr 'A-Z' 'a-z')" "$DOMAIN" "$day")
  code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$WEBHOOK_URL" \
    -H "X-Signal-Secret: $SIGNAL_SECRET" -H "Content-Type: application/json" -d "$body")
  printf 'event %s  %s  %s  /pricing  2026-10-%s  HTTP %s\n' "$i" "$who" "$DOMAIN" "$day" "$code"
  sleep 2
done
echo "Now open Executions in n8n, then the company in HubSpot."
