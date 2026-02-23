#!/usr/bin/env bash
set -euo pipefail

# ── Neiron watchOS Deploy Script ──
# Usage: ./deploy.sh "commit message"
# Commits, pushes to main, and monitors GitHub Actions build

REPO="apple-watch-neiron"
BRANCH="main"
WORKFLOW="build-watchos.yml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

msg="${1:-}"
if [[ -z "$msg" ]]; then
    echo -e "${RED}Usage: ./deploy.sh \"commit message\"${NC}"
    exit 1
fi

echo -e "${CYAN}=== Neiron watchOS Deploy ===${NC}"

# 1. Check for changes
if git diff --quiet && git diff --cached --quiet && [[ -z $(git ls-files --others --exclude-standard) ]]; then
    echo -e "${YELLOW}No changes to commit${NC}"
    exit 0
fi

# 2. Commit
echo -e "${GREEN}[1/4] Committing...${NC}"
git add -A
git commit -m "$msg"

# 3. Push
echo -e "${GREEN}[2/4] Pushing to ${BRANCH}...${NC}"
git push origin "$BRANCH"

# 4. Wait for workflow to start
echo -e "${GREEN}[3/4] Waiting for GitHub Actions...${NC}"
sleep 5

# 5. Monitor build
echo -e "${GREEN}[4/4] Monitoring build...${NC}"
run_id=""
for i in $(seq 1 10); do
    run_id=$(gh run list --workflow="$WORKFLOW" --branch="$BRANCH" --limit=1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || true)
    if [[ -n "$run_id" ]]; then
        break
    fi
    sleep 3
done

if [[ -z "$run_id" ]]; then
    echo -e "${YELLOW}Could not find workflow run. Check manually:${NC}"
    echo "  gh run list --workflow=$WORKFLOW"
    exit 0
fi

echo -e "${CYAN}Run ID: ${run_id}${NC}"
echo -e "${CYAN}Watching build (Ctrl+C to stop)...${NC}"
gh run watch "$run_id" --exit-status || {
    echo -e "${RED}Build failed! Check logs:${NC}"
    echo "  gh run view $run_id --log-failed"
    exit 1
}

echo -e "${GREEN}=== Build uploaded to TestFlight! ===${NC}"
