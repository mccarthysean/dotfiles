#!/bin/bash

# Script to create a new feature branch with timestamp.
# Generic version (no worktree mode) — derived from rcom/scripts/new-feature-branch.sh.
#
# Usage: bash scripts/new-feature-branch.sh [--branch <name>] [--from-current]
#
# This script:
# 1. Stashes any uncommitted changes (modified and untracked files)
# 2. Fetches latest from origin/main
# 3. Creates a new branch from origin/main as: <github-username>/YYYY-MM-DD-HHMM
# 4. Pushes the new branch to origin
# 5. Restores stashed changes onto the new branch
#
# Options:
#   --branch, -b <name>   Override the feature branch name
#                         (default: <github-username>/YYYY-MM-DD-HHMM)
#   --from-current, -c    Branch from the current branch instead of origin/main
#   --help, -h            Show this help message

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse command line arguments
BRANCH_OVERRIDE=""
FROM_CURRENT=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --branch|-b)
            BRANCH_OVERRIDE="$2"
            shift 2
            ;;
        --from-current|-c)
            FROM_CURRENT=true
            shift
            ;;
        --from-main)
            # Explicit default: branch from main (no-op, this is the default behavior)
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--branch|-b <name>] [--from-current|-c]"
            echo ""
            echo "Options:"
            echo "  --branch, -b <name>   Override the feature branch name"
            echo "                        Default: <github-username>/YYYY-MM-DD-HHMM"
            echo "  --from-current, -c    Branch from the current branch instead of origin/main"
            echo "  --help, -h            Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}" >&2
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Error handling function
error_exit() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Warning function (doesn't exit)
warning() {
    echo -e "${YELLOW}Warning: $1${NC}" >&2
}

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
if [ -z "$CURRENT_BRANCH" ]; then
    error_exit "Could not determine current branch"
fi

# Get GitHub username from git config (try github.user first)
GITHUB_USERNAME=$(git config github.user 2>/dev/null || true)

# If not set, try user.email to extract username
if [ -z "$GITHUB_USERNAME" ]; then
    USER_EMAIL=$(git config user.email 2>/dev/null || true)
    # Extract username from email if it's a GitHub noreply email
    if [[ "$USER_EMAIL" =~ ^([^@]+)@users\.noreply\.github\.com$ ]]; then
        # Handle both formats: "username@users.noreply.github.com" and "ID+username@users.noreply.github.com"
        EMAIL_PREFIX="${BASH_REMATCH[1]}"
        if [[ "$EMAIL_PREFIX" =~ \+(.+)$ ]]; then
            GITHUB_USERNAME="${BASH_REMATCH[1]}"
        else
            GITHUB_USERNAME="$EMAIL_PREFIX"
        fi
    fi
fi

# If still not found, use the first part of user.name as fallback
if [ -z "$GITHUB_USERNAME" ]; then
    GITHUB_USERNAME=$(git config user.name 2>/dev/null | awk '{print tolower($1)}' || echo "user")
fi

# Determine branch name
if [ -n "$BRANCH_OVERRIDE" ]; then
    NEW_BRANCH="$BRANCH_OVERRIDE"
else
    CURRENT_DATETIME=$(date +%Y-%m-%d-%H%M)
    NEW_BRANCH="${GITHUB_USERNAME}/${CURRENT_DATETIME}"
fi

echo -e "${YELLOW}Current branch: ${CURRENT_BRANCH}${NC}"
echo -e "${YELLOW}New branch will be: ${NEW_BRANCH}${NC}"
echo ""

# Check for uncommitted changes and stash them if present
STASH_CREATED=false
if ! git diff-index --quiet HEAD -- || [ -n "$(git ls-files --others --exclude-standard)" ]; then
    echo -e "${YELLOW}Detected uncommitted changes. Stashing them temporarily...${NC}"

    # Count stashes before
    STASH_COUNT_BEFORE=$(git stash list | wc -l)

    # Attempt to stash changes
    # Note: git stash may return exit code 1 for warnings (e.g., "failed to remove: Device or resource busy")
    # but still successfully create the stash. We check if stash was created rather than relying on exit code.
    if git stash push -u -m "Auto-stash for new-feature-branch script on $(date '+%Y-%m-%d %H:%M:%S')" 2>&1 | tee /tmp/stash-output.txt; then
        : # Stash command completed
    fi

    # Check if warnings occurred but stash was still created
    if grep -q "warning: failed to remove" /tmp/stash-output.txt 2>/dev/null; then
        warning "Some files could not be removed (device busy), but stash was created"
    fi

    # Count stashes after
    STASH_COUNT_AFTER=$(git stash list | wc -l)

    # Verify stash was actually created
    if [ "$STASH_COUNT_AFTER" -gt "$STASH_COUNT_BEFORE" ]; then
        STASH_CREATED=true
        echo -e "${GREEN}✅ Stash entry created${NC}"

        # Verify working directory is actually clean after stash
        # This handles "device busy" cases where stash is created but files remain
        if ! git diff-index --quiet HEAD -- || [ -n "$(git ls-files --others --exclude-standard)" ]; then
            echo -e "${YELLOW}Working directory still has changes after stash (likely due to device busy)${NC}"
            echo -e "${YELLOW}Attempting to restore clean state with git checkout...${NC}"

            # Force checkout to discard working directory changes (stash has them saved)
            if git checkout -- .; then
                echo -e "${GREEN}✅ Working directory cleaned${NC}"
            else
                # If checkout fails, try git restore
                if git restore .; then
                    echo -e "${GREEN}✅ Working directory cleaned with git restore${NC}"
                else
                    error_exit "Failed to clean working directory after stash. Please manually run: git checkout -- ."
                fi
            fi

            # Clean untracked files that couldn't be removed
            git clean -fd 2>/dev/null || true
        fi
        echo ""
    else
        # Check if there are still uncommitted changes
        if ! git diff-index --quiet HEAD -- || [ -n "$(git ls-files --others --exclude-standard)" ]; then
            error_exit "Failed to stash changes. Please commit or stash manually and try again."
        else
            echo -e "${GREEN}No changes needed to be stashed${NC}"
            echo ""
        fi
    fi
fi

if [ "$FROM_CURRENT" = true ]; then
    # Stay on the current branch — new branch will fork from here
    echo -e "${YELLOW}Branching from current branch: ${CURRENT_BRANCH}${NC}"
else
    # Fetch latest main without changing the current branch
    echo -e "${GREEN}Fetching latest changes from origin/main...${NC}"
    if ! git fetch origin main; then
        error_exit "Failed to fetch latest changes from origin/main"
    fi
fi

# Delete existing local branch if it already exists (e.g. re-running with --branch override)
if git show-ref --verify --quiet "refs/heads/$NEW_BRANCH"; then
    echo -e "${YELLOW}Branch '${NEW_BRANCH}' already exists locally. Deleting it...${NC}"
    if ! git branch -D "$NEW_BRANCH"; then
        error_exit "Failed to delete existing branch $NEW_BRANCH"
    fi
fi

# Create and checkout new feature branch
if [ "$FROM_CURRENT" = true ]; then
    echo -e "${GREEN}Creating new feature branch: ${NEW_BRANCH}${NC}"
    if ! git checkout -b "$NEW_BRANCH"; then
        error_exit "Failed to create new branch $NEW_BRANCH"
    fi
else
    echo -e "${GREEN}Creating new feature branch: ${NEW_BRANCH} from origin/main...${NC}"
    if ! git checkout -b "$NEW_BRANCH" origin/main; then
        error_exit "Failed to create new branch $NEW_BRANCH from origin/main"
    fi
fi

# Push the new branch to origin
echo -e "${GREEN}Pushing new branch to origin...${NC}"
if ! git push -u origin "$NEW_BRANCH"; then
    warning "Failed to push branch to origin. You can push manually later with: git push -u origin $NEW_BRANCH"
fi

# Restore stashed changes
if [ "$STASH_CREATED" = true ]; then
    echo ""
    echo -e "${GREEN}Applying stashed changes to new branch...${NC}"
    if git stash pop; then
        echo -e "${GREEN}✅ Stashed changes have been restored${NC}"
    else
        warning "Failed to apply stashed changes. Your changes are still in the stash."
        echo -e "${YELLOW}You can manually apply them with: git stash pop${NC}"
    fi
fi

echo ""
echo -e "${GREEN}✅ Successfully created new feature branch: ${NEW_BRANCH}${NC}"
echo -e "${YELLOW}You can now start working on your new feature!${NC}"
