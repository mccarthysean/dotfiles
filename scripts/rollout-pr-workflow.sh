#!/bin/bash
#
# rollout-pr-workflow.sh
#
# Roll out the RCOM-style PR workflow to a list of target repos:
# 1. Create a feature branch off origin/main
# 2. Copy scripts/new-feature-branch.sh from dotfiles
# 3. Copy .claude/skills/git-workflow/SKILL.md from dotfiles
# 4. Commit
# 5. Push and open a PR
#
# Idempotent: if the target files already match, skips the commit/PR.
# Supports --dry-run to preview without making any changes.
#
# Usage:
#   bash rollout-pr-workflow.sh [--dry-run] [--repo <path>]...
#
# If no --repo is given, defaults to the 9 in-scope ijack-technologies repos.

set -uo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_SCRIPT="$DOTFILES_DIR/scripts/new-feature-branch.sh"
SOURCE_SKILL="$DOTFILES_DIR/skills/git-workflow/SKILL.md"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

DRY_RUN=false
REPOS=()

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --repo|-r)
            REPOS+=("$2")
            shift 2
            ;;
        --help|-h)
            cat <<EOF
Usage: $0 [--dry-run|-n] [--repo|-r <path>]...

Options:
  --dry-run, -n         Preview actions without making changes
  --repo, -r <path>     Add a repo path (can be repeated)
  --help, -h            Show this help

If no --repo is given, defaults to the 9 in-scope ijack-technologies repos.
EOF
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}" >&2
            exit 1
            ;;
    esac
done

# Default repo list if none provided.
# Note: ijack-technologies/myijack-api and ijack-technologies/alerts are archived
# on GitHub (read-only) and are skipped — see ~/.claude/projects/.../archived_repos.md
if [ ${#REPOS[@]} -eq 0 ]; then
    REPOS=(
        "$HOME/git_wsl/timescale_db"
        "$HOME/git_wsl/gateway_can_to_mqtt"
        "$HOME/git_wsl/mqtt_jobs"
        "$HOME/git_wsl/mqtt_listener"
        "$HOME/git_wsl/traefik_ijack"
        "$HOME/git_wsl/monitoring"
        "$HOME/git_wsl/pgadmin"
    )
fi

# Pre-flight checks
if [ ! -f "$SOURCE_SCRIPT" ]; then
    echo -e "${RED}Source script not found: $SOURCE_SCRIPT${NC}" >&2
    exit 1
fi
if [ ! -f "$SOURCE_SKILL" ]; then
    echo -e "${RED}Source skill not found: $SOURCE_SKILL${NC}" >&2
    exit 1
fi

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}=== DRY RUN MODE — no changes will be made ===${NC}"
fi
echo ""
echo -e "${CYAN}Source script: $SOURCE_SCRIPT${NC}"
echo -e "${CYAN}Source skill:  $SOURCE_SKILL${NC}"
echo -e "${CYAN}Targets: ${#REPOS[@]} repos${NC}"
echo ""

DATESTAMP=$(date +%Y-%m-%d-%H%M)
ROLLOUT_BRANCH="sean/${DATESTAMP}-pr-workflow-rollout"

SUCCESSES=()
SKIPS=()
FAILURES=()

for repo in "${REPOS[@]}"; do
    echo -e "${CYAN}=== Processing: $repo ===${NC}"

    if [ ! -d "$repo/.git" ]; then
        echo -e "${RED}  Skipping: not a git repo${NC}"
        FAILURES+=("$repo (not a git repo)")
        continue
    fi

    # Determine target paths
    TARGET_SCRIPT="$repo/scripts/new-feature-branch.sh"
    TARGET_SKILL="$repo/.claude/skills/git-workflow/SKILL.md"

    # Check if already up to date
    SCRIPT_NEEDS_UPDATE=true
    SKILL_NEEDS_UPDATE=true
    if [ -f "$TARGET_SCRIPT" ] && cmp -s "$SOURCE_SCRIPT" "$TARGET_SCRIPT"; then
        SCRIPT_NEEDS_UPDATE=false
    fi
    if [ -f "$TARGET_SKILL" ] && cmp -s "$SOURCE_SKILL" "$TARGET_SKILL"; then
        SKILL_NEEDS_UPDATE=false
    fi

    if [ "$SCRIPT_NEEDS_UPDATE" = false ] && [ "$SKILL_NEEDS_UPDATE" = false ]; then
        echo -e "${GREEN}  Already up to date — skipping${NC}"
        SKIPS+=("$repo")
        continue
    fi

    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}  Would: fetch origin main${NC}"
        echo -e "${YELLOW}  Would: checkout -b $ROLLOUT_BRANCH origin/main${NC}"
        if [ "$SCRIPT_NEEDS_UPDATE" = true ]; then
            echo -e "${YELLOW}  Would: copy script -> $TARGET_SCRIPT${NC}"
        fi
        if [ "$SKILL_NEEDS_UPDATE" = true ]; then
            echo -e "${YELLOW}  Would: copy skill  -> $TARGET_SKILL${NC}"
        fi
        echo -e "${YELLOW}  Would: git add + commit + push + gh pr create${NC}"
        SUCCESSES+=("$repo (dry-run)")
        echo ""
        continue
    fi

    # Real execution
    echo "  Fetching origin/main..."
    if ! git -C "$repo" fetch origin main 2>&1 | sed 's/^/    /'; then
        echo -e "${RED}  Failed to fetch origin/main${NC}"
        FAILURES+=("$repo (fetch failed)")
        continue
    fi

    # Check if rollout branch already exists locally; if so, delete it
    if git -C "$repo" show-ref --verify --quiet "refs/heads/$ROLLOUT_BRANCH"; then
        echo "  Removing pre-existing local rollout branch..."
        git -C "$repo" branch -D "$ROLLOUT_BRANCH" >/dev/null 2>&1 || true
    fi

    echo "  Creating branch $ROLLOUT_BRANCH from origin/main..."
    if ! git -C "$repo" checkout -b "$ROLLOUT_BRANCH" origin/main 2>&1 | sed 's/^/    /'; then
        echo -e "${RED}  Failed to create branch${NC}"
        FAILURES+=("$repo (branch creation failed)")
        continue
    fi

    # Copy files
    if [ "$SCRIPT_NEEDS_UPDATE" = true ]; then
        mkdir -p "$repo/scripts"
        cp "$SOURCE_SCRIPT" "$TARGET_SCRIPT"
        chmod +x "$TARGET_SCRIPT"
        echo "  Copied script."
    fi
    if [ "$SKILL_NEEDS_UPDATE" = true ]; then
        mkdir -p "$repo/.claude/skills/git-workflow"
        cp "$SOURCE_SKILL" "$TARGET_SKILL"
        echo "  Copied skill."
    fi

    # Stage and commit
    git -C "$repo" add scripts/new-feature-branch.sh .claude/skills/git-workflow/SKILL.md 2>/dev/null || true

    if git -C "$repo" diff --cached --quiet; then
        echo -e "${YELLOW}  No staged changes after copy — skipping commit${NC}"
        SKIPS+=("$repo (no diff)")
        # Switch back to main to leave repo in clean state
        git -C "$repo" checkout main 2>/dev/null || true
        git -C "$repo" branch -D "$ROLLOUT_BRANCH" 2>/dev/null || true
        continue
    fi

    COMMIT_MSG="chore: adopt RCOM-style PR workflow (script + git-workflow skill)

- Add scripts/new-feature-branch.sh for post-merge feature branch creation
- Refresh .claude/skills/git-workflow/SKILL.md to match RCOM's current version
- Aligns this repo with the IJACK PR-required workflow being rolled out
  across all ijack-technologies repos

🤖 Generated with Claude Code

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"

    if ! git -C "$repo" commit -m "$COMMIT_MSG" 2>&1 | sed 's/^/    /'; then
        echo -e "${RED}  Commit failed${NC}"
        FAILURES+=("$repo (commit failed)")
        continue
    fi

    echo "  Pushing branch..."
    if ! git -C "$repo" push -u origin "$ROLLOUT_BRANCH" 2>&1 | sed 's/^/    /'; then
        echo -e "${RED}  Push failed${NC}"
        FAILURES+=("$repo (push failed)")
        continue
    fi

    echo "  Creating PR..."
    PR_BODY="## Summary
- Adds \`scripts/new-feature-branch.sh\` (227-line generic version, no worktree mode)
- Refreshes \`.claude/skills/git-workflow/SKILL.md\` to match RCOM's current version
- Part of the IJACK PR-workflow rollout: every ijack-technologies repo gets the same script + skill, then a \`protect main\` ruleset is applied

## After merge
A repository ruleset matching RCOM's \`protect main\` (id 5490382) will be applied to this repo, requiring PRs for all changes to \`main\`, blocking force-pushes/deletions, requiring linear history, and allowing only squash merges.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"

    PR_URL=$(gh pr create \
        --repo "$(git -C "$repo" remote get-url origin | sed -E 's#.*[:/]([^/]+/[^/]+)\.git$#\1#')" \
        --base main \
        --head "$ROLLOUT_BRANCH" \
        --title "chore: adopt RCOM-style PR workflow" \
        --body "$PR_BODY" 2>&1)

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✅ PR created: $PR_URL${NC}"
        SUCCESSES+=("$repo -> $PR_URL")
    else
        echo -e "${RED}  PR creation failed: $PR_URL${NC}"
        FAILURES+=("$repo (PR creation failed)")
    fi

    echo ""
done

# Summary
echo ""
echo -e "${CYAN}=== Rollout Summary ===${NC}"
echo -e "${GREEN}Successes (${#SUCCESSES[@]}):${NC}"
for s in "${SUCCESSES[@]}"; do echo "  ✅ $s"; done
echo -e "${YELLOW}Skipped (${#SKIPS[@]}):${NC}"
for s in "${SKIPS[@]}"; do echo "  ⊝ $s"; done
echo -e "${RED}Failures (${#FAILURES[@]}):${NC}"
for f in "${FAILURES[@]}"; do echo "  ❌ $f"; done
