#!/usr/bin/env bash
# Send the nine sample events to the n8n webhook, one by one, and print what each should do.
#
#   WEBHOOK_URL=http://localhost:5678/webhook/<path> SIGNAL_SECRET=<secret> bash replay.sh [tag]
#
# Before a run:
#   - Empty both n8n data tables (visits and alerts), or the counts start above zero.
#   - Event IDs are prefixed with a tag (default: the time), because Remove Duplicates
#     remembers every ID it has seen. Use a new tag for every run.
#   - HubSpot only starts the task workflow when signal_status changes. A second run on the
#     same dates writes the same alert text, so it makes no new task.
#
# n8n answers 200 "Workflow was started" before the checks run, so the HTTP code only shows
# that the event was received (or refused, for a wrong secret). Open Executions in n8n to see
# where each run stopped, and compare it with the last column.

set -u
: "${WEBHOOK_URL:?Set WEBHOOK_URL to the production webhook URL}"
: "${SIGNAL_SECRET:?Set SIGNAL_SECRET to the header auth secret}"
TAG="${1:-$(date +%H%M%S)}"

failures=0

send() {  # label, id, visitor, domain, path, day, secret, want_code, expected
  local label="$1" id="$2" visitor="$3" domain="$4" path="$5" day="$6" secret="$7" want="$8" expected="$9"
  local body code
  body=$(printf '{"event_id":"%s-%s","visitor_id":"%s","email":"%s@example.com","domain":"%s","path":"%s","ts":"2026-10-%sT09:15:00Z"}' \
    "$TAG" "$id" "$visitor" "$(echo "$visitor" | tr 'A-Z' 'a-z')" "$domain" "$path" "$day")
  code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$WEBHOOK_URL" \
    -H "X-Signal-Secret: $secret" -H "Content-Type: application/json" -d "$body")
  local ok="yes"
  if [ "$code" != "$want" ]; then ok="NO"; failures=$((failures + 1)); fi
  printf '%-3s %-6s HTTP %-4s (want %s) %-4s %s\n' "$label" "$id" "$code" "$want" "$ok" "$expected"
  sleep 2
}

printf '%-3s %-6s %s\n' "#" "event" "result, then where the run should stop in Executions"
send 1 e1 Anna  acme.com  /pricing 09 "$SIGNAL_SECRET" 200 "3 or more (count 1)"
send 2 e2 Anna  acme.com  /pricing 09 "$SIGNAL_SECRET" 200 "New visitor-day (same visitor, same day)"
# Event 3 reuses event 1's ID, so it must have exactly event 1's content.
send 3 e1 Anna  acme.com  /pricing 09 "$SIGNAL_SECRET" 200 "Remove Duplicates (ID already seen)"
send 4 e3 Ben   acme.com  /blog    10 "$SIGNAL_SECRET" 200 "Is a target (not /pricing)"
send 5 e4 Ben   acme.com  /pricing 11 "$SIGNAL_SECRET" 200 "3 or more (count 2)"
send 6 e5 Cara  globex.io /pricing 11 "$SIGNAL_SECRET" 200 "Is a target (not the target domain)"
send 7 e6 Dan   acme.com  /pricing 12 "$SIGNAL_SECRET" 200 "Create a company or Update company (count 3, alert)"
send 8 e7 Eva   acme.com  /pricing 13 "$SIGNAL_SECRET" 200 "Cooldown over (count 4, inside the 7-day cooldown)"
send 9 e8 Nina  acme.com  /pricing 13 "wrong-secret"   403 "no run starts (403 Forbidden)"

echo
if [ "$failures" -eq 0 ]; then echo "All HTTP codes as expected. Now check Executions."; else echo "$failures HTTP code(s) not as expected."; fi
