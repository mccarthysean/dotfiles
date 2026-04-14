#!/bin/bash
#
# audit-stranded-work.sh
#
# Scan ~/git_wsl/* for stranded work: unpushed commits, uncommitted
# changes, untracked files, orphaned branches. Prints one compact
# block per repo that has something worth attention.
#
# Usage: bash audit-stranded-work.sh [--root <dir>] [--all]
#
# Options:
#   --root <dir>    Root directory to scan (default: ~/git_wsl)
#   --all           Include repos with no stranded work
#   --help, -h      Show this help

set -uo pipefail

ROOT="$HOME/git_wsl"
SHOW_ALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --root)
            ROOT="$2"
            shift 2
            ;;
        --all)
            SHOW_ALL=true
            shift
            ;;
        --help|-h)
            sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

if [ ! -d "$ROOT" ]; then
    echo -e "${RED}Root directory not found: $ROOT${NC}" >&2
    exit 1
fi

REPOS_WITH_WORK=0
REPOS_CLEAN=0
TOTAL_UNPUSHED=0
TOTAL_DIRTY_FILES=0

for repo in "$ROOT"/*/; do
    [ -d "$repo/.git" ] || continue
    repo_name=$(basename "$repo")

    # Check if current branch has unpushed commits
    branch=$(git -C "$repo" branch --show-current 2>/dev/null)
    [ -z "$branch" ] && continue

    # Get upstream; may not exist if branch isn't tracking anything
    upstream=$(git -C "$repo" rev-parse --abbrev-ref "${branch}@{upstream}" 2>/dev/null || echo "")

    unpushed_count=0
    unpushed_commits=""
    if [ -n "$upstream" ]; then
        unpushed_count=$(git -C "$repo" rev-list --count "${upstream}..HEAD" 2>/dev/null || echo 0)
        if [ "$unpushed_count" -gt 0 ]; then
            unpushed_commits=$(git -C "$repo" log --oneline "${upstream}..HEAD" 2>/dev/null)
        fi
    fi

    # Check dirty tree
    dirty_count=0
    dirty_summary=""
    if ! git -C "$repo" diff-index --quiet HEAD -- 2>/dev/null; then
        mod_count=$(git -C "$repo" diff-index --name-only HEAD -- 2>/dev/null | wc -l)
        dirty_count=$((dirty_count + mod_count))
    fi
    untracked_count=$(git -C "$repo" ls-files --others --exclude-standard 2>/dev/null | wc -l)
    dirty_count=$((dirty_count + untracked_count))

    # Skip clean repos unless --all
    if [ "$unpushed_count" -eq 0 ] && [ "$dirty_count" -eq 0 ]; then
        REPOS_CLEAN=$((REPOS_CLEAN + 1))
        if [ "$SHOW_ALL" = true ]; then
            printf "${DIM}%-30s %s (clean)${NC}\n" "$repo_name" "$branch"
        fi
        continue
    fi

    REPOS_WITH_WORK=$((REPOS_WITH_WORK + 1))
    TOTAL_UNPUSHED=$((TOTAL_UNPUSHED + unpushed_count))
    TOTAL_DIRTY_FILES=$((TOTAL_DIRTY_FILES + dirty_count))

    echo -e "${CYAN}=== $repo_name ${DIM}($branch)${NC}"
    if [ "$unpushed_count" -gt 0 ]; then
        echo -e "${YELLOW}  $unpushed_count unpushed commit(s) ahead of $upstream:${NC}"
        echo "$unpushed_commits" | sed 's/^/    /'
    fi
    if [ "$dirty_count" -gt 0 ]; then
        if [ "$mod_count" -gt 0 ]; then
            echo -e "${YELLOW}  Modified ($mod_count):${NC}"
            git -C "$repo" diff-index --name-only HEAD -- 2>/dev/null | sed 's/^/    M /'
        fi
        if [ "$untracked_count" -gt 0 ]; then
            echo -e "${YELLOW}  Untracked ($untracked_count):${NC}"
            git -C "$repo" ls-files --others --exclude-standard 2>/dev/null | sed 's/^/    ? /'
        fi
    fi
    echo ""
done

# Summary
echo -e "${CYAN}=== Summary ===${NC}"
echo -e "Repos with stranded work: ${REPOS_WITH_WORK}"
echo -e "Clean repos:              ${REPOS_CLEAN}"
echo -e "Total unpushed commits:   ${TOTAL_UNPUSHED}"
echo -e "Total dirty files:        ${TOTAL_DIRTY_FILES}"
if [ "$REPOS_WITH_WORK" -eq 0 ]; then
    echo -e "${GREEN}All repos are clean.${NC}"
fi
