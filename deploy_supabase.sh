#!/bin/bash
set -euo pipefail

# ==============================================================================
# Spiritbound — one-shot Supabase setup (Docs/LAUNCH_READINESS.md §1-§3)
# ==============================================================================
# Closes the three things that live entirely outside the repo and therefore cannot be done by
# anyone without Supabase project access:
#
#   1. the two tables (`client_events`, `entitlements`) from Docs/sql/
#   2. the two Edge Functions (`delete-account`, `verify-purchase`)
#   3. the secrets each function needs before it can do anything useful — printed, never stored
#
# Usage:
#   ./deploy_supabase.sh --project-ref <ref>              # link + deploy functions, print SQL steps
#   ./deploy_supabase.sh --project-ref <ref> --db-url "postgresql://..."   # also run the SQL
#   ./deploy_supabase.sh --project-ref <ref> --dry-run    # print what would happen, do nothing
#
# The project ref is the subdomain in your project URL, e.g. "abcdefghijklmnop" for
# https://abcdefghijklmnop.supabase.co — this repo's client points at the project whose URL is
# in Godot/scripts/supabase_client.gd's SUPABASE_URL, so read the ref from there if unsure.
#
# NOTE: the service-role key is injected by the platform into deployed functions. Never set it
# here, never commit it, never ship it in the Godot client.
# ==============================================================================

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

PROJECT_REF=""
DB_URL="${SUPABASE_DB_URL:-}"
DRY_RUN=false
FUNCTIONS=("delete-account" "verify-purchase")
SQL_FILES=("Docs/sql/2026_client_events.sql" "Docs/sql/2026_entitlements.sql")

while [ $# -gt 0 ]; do
    case "$1" in
        --project-ref) PROJECT_REF="${2:-}"; shift 2 ;;
        --db-url)      DB_URL="${2:-}"; shift 2 ;;
        --dry-run)     DRY_RUN=true; shift ;;
        -h|--help)     sed -n '4,22p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) echo -e "${RED}Unknown argument: $1${NC}"; exit 1 ;;
    esac
done

run() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}  [dry-run] $*${NC}"
    else
        "$@"
    fi
}

echo -e "${BLUE}=================================================="
echo -e "  Spiritbound: Supabase setup"
echo -e "==================================================${NC}"

# ---- Preflight ---------------------------------------------------------------
if ! command -v supabase >/dev/null 2>&1; then
    echo -e "${RED}✗ The Supabase CLI is not installed.${NC}"
    echo "  Install it, then re-run:"
    echo "    brew install supabase/tap/supabase"
    exit 1
fi

if [ -z "$PROJECT_REF" ]; then
    echo -e "${RED}✗ --project-ref is required.${NC}"
    echo "  It is the subdomain of your project URL. This repo's client currently points at:"
    grep -o 'https://[a-z0-9]*\.supabase\.co' "$REPO_DIR/Godot/scripts/supabase_client.gd" | sed -n '1p' | sed 's/^/    /'
    exit 1
fi

for f in "${SQL_FILES[@]}"; do
    [ -f "$REPO_DIR/$f" ] || { echo -e "${RED}✗ Missing $f${NC}"; exit 1; }
done

echo -e "\n${YELLOW}[1/4] Linking project $PROJECT_REF (requires an interactive login on first use)...${NC}"
echo "  If this fails with 'not logged in', run: supabase login"
run supabase link --project-ref "$PROJECT_REF"

# ---- Tables ------------------------------------------------------------------
# These are plain DDL files, not a migrations directory, so `supabase db push` does not apply.
# Applying them needs a direct database connection; with --db-url we run them ourselves,
# otherwise the dashboard SQL editor is the supported path (and the one LAUNCH_READINESS.md
# already documents).
echo -e "\n${YELLOW}[2/4] Tables${NC}"
if [ -n "$DB_URL" ] && command -v psql >/dev/null 2>&1; then
    for f in "${SQL_FILES[@]}"; do
        echo -e "  Running ${f}..."
        run psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$REPO_DIR/$f"
    done
    echo -e "${GREEN}✓ Tables applied.${NC}"
elif [ -n "$DB_URL" ]; then
    echo -e "${YELLOW}⚠ --db-url was given but psql is not installed; falling back to the dashboard.${NC}"
    DB_URL=""
fi
if [ -z "$DB_URL" ]; then
    echo -e "${YELLOW}  Not applied automatically. Paste each of these into the Supabase dashboard's"
    echo -e "  SQL editor and run it once (both are idempotent — safe to re-run):${NC}"
    for f in "${SQL_FILES[@]}"; do echo "      $f  (sql/$(basename "$f"))"; done
    echo "  Or re-run this script with --db-url \"postgresql://...\" (Settings → Database → Connection string)."
fi

# ---- Edge Functions ----------------------------------------------------------
echo -e "\n${YELLOW}[3/4] Deploying Edge Functions...${NC}"
for fn in "${FUNCTIONS[@]}"; do
    [ -d "$REPO_DIR/supabase/functions/$fn" ] || { echo -e "${RED}✗ Missing supabase/functions/$fn${NC}"; exit 1; }
    echo -e "  Deploying $fn..."
    run supabase functions deploy "$fn" --project-ref "$PROJECT_REF"
done

# ---- Smoke test --------------------------------------------------------------
echo -e "\n${YELLOW}[4/4] Verifying the functions answer (401 without a token is the expected pass)...${NC}"
if [ "$DRY_RUN" = false ]; then
    for fn in "${FUNCTIONS[@]}"; do
        code=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
            "https://${PROJECT_REF}.supabase.co/functions/v1/${fn}" || echo "000")
        if [ "$code" = "401" ] || [ "$code" = "400" ]; then
            echo -e "${GREEN}  ✓ $fn responds (HTTP $code from an unauthenticated call, as expected)${NC}"
        else
            echo -e "${RED}  ✗ $fn answered HTTP $code — expected 401/400 for a tokenless call."
            echo -e "    A 404 usually means the deploy did not land; a 500 means it deployed but${NC}"
            echo -e "    threw on startup (check 'supabase functions logs $fn')."
        fi
    done
fi

# ---- Remaining secrets -------------------------------------------------------
echo -e "\n${YELLOW}Still required before the purchase gate can unlock anything:${NC}"
cat <<'EOF'
  verify-purchase fails closed (grants nothing) until the store credentials exist. Set them as
  function secrets — never in this repo, never in the Godot client:

    # Apple (App Store Server API) — the .p8 is downloaded once from App Store Connect
    supabase secrets set APPLE_ISSUER_ID=... APPLE_KEY_ID=... APPLE_BUNDLE_ID=com.jiacong.spiritbound
    supabase secrets set APPLE_ENVIRONMENT=Sandbox   # switch to Production at launch
    supabase secrets set APPLE_PRIVATE_KEY="$(cat AuthKey_XXXXXXXXXX.p8)"

    # Google (Play Developer API) — service-account JSON with the Play Developer API enabled
    supabase secrets set GOOGLE_PACKAGE_NAME=com.jiacong.spiritbound
    supabase secrets set GOOGLE_SERVICE_ACCOUNT_JSON="$(cat service-account.json)"

  Then finish the store side: create the product (PurchaseService.PRODUCT_SEASON_PASS =
  spiritbound_season_pass_1) in App Store Connect / Play Console, and see Docs/STORE_SUBMISSION.md.

  The Apple/Google verification calls inside supabase/functions/verify-purchase/index.ts are
  still honest stubs that return verified:false — deploying this function alone does NOT make
  purchases work. Implement those two functions against the vendored SDKs first.
EOF

if [ "$DRY_RUN" = true ]; then
    echo -e "\n${YELLOW}(dry run — nothing was changed)${NC}"
else
    echo -e "\n${GREEN}Done. Re-run anytime: both SQL files and both functions are idempotent.${NC}"
fi
