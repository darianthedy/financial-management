#!/usr/bin/env bash
# Deletes everything the T3 XCUITests (HappyPathUITests) leave in the test
# account: its transactions, then its accounts (their monthly balance rows
# cascade). Runs after every T3 run, pass or fail (ios-duo-gate.yml).
#
# Needs SUPABASE_URL, SUPABASE_ANON_KEY, UITEST_EMAIL and UITEST_PASSWORD.
# Signs in as the test user, so row-level security limits it to that user.
set -euo pipefail

for v in SUPABASE_URL SUPABASE_ANON_KEY UITEST_EMAIL UITEST_PASSWORD; do
  if [ -z "${!v:-}" ]; then
    echo "error: $v is not set" >&2
    exit 1
  fi
done

# Guard against a misconfigured secret wiping a real account.
case "$UITEST_EMAIL" in
  *uitest*) ;;
  *) echo "error: refusing to clean '$UITEST_EMAIL': not a uitest account" >&2; exit 1 ;;
esac

json() { python3 -c "import json, sys; print($1)"; }

login="$(python3 -c 'import json, os; print(json.dumps({"email": os.environ["UITEST_EMAIL"], "password": os.environ["UITEST_PASSWORD"]}))' |
  curl -sf "$SUPABASE_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $SUPABASE_ANON_KEY" -H "Content-Type: application/json" -d @-)"
token="$(json 'json.load(sys.stdin)["access_token"]' <<<"$login")"
user="$(json 'json.load(sys.stdin)["user"]["id"]' <<<"$login")"

# DELETE with return=representation, so the count of removed rows is logged.
delete() {
  curl -sf -X DELETE "$SUPABASE_URL/rest/v1/$1?user_id=eq.$user&select=id" \
    -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $token" \
    -H "Prefer: return=representation" | json 'len(json.load(sys.stdin))'
}

# Transactions first: they reference accounts with ON DELETE RESTRICT.
echo "deleted $(delete transactions) transactions, $(delete accounts) accounts from the test account"
