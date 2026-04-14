---
name: "git-workflow"
description: "Manage Git workflows with branch creation, commits, pull requests, and automatic IJACK Roadmap (Project #12) integration. Create feature branches via scripts/new-feature-branch.sh, write commit messages, generate PRs, add issues to project board, manage git history, and follow git best practices. CRITICAL: ALL issues must be added to IJACK Roadmap (Project #12). Use when creating branches, committing changes, making PRs, writing commit messages, managing git, adding issues to project board, creating feature branches, or handling version control."
allowed-tools: [Bash, Read]
---

# Git Workflow Skill

## Purpose
Manage Git workflows including feature branches, commits, pull requests, and GitHub issue tracking with IJACK Roadmap project board integration.

## When to Use This Skill
- Creating feature branches
- Committing code changes
- Creating pull requests
- Adding issues to project board
- Git workflow management
- Branch management
- Issue tracking

## Critical: IJACK Roadmap Project Board

### MANDATORY: All Issues Must Go to Project #12
**IJACK Roadmap (Project #12)** is the **default and only project board** for ALL issues:
- Features
- Bugs
- Epics
- User stories
- Service requests
- Ideas

**Project URL**: https://github.com/orgs/ijack-technologies/projects/12/views/

### Add Issue to Project Board
```bash
# Add the issue to Project #12
gh project item-add 12 --owner ijack-technologies --url <ISSUE_URL>
```

## Feature Branch Workflow

### Create New Feature Branch (Standard, After PR Merge)

This repository follows a **PR-required workflow**: direct pushes to `main` are blocked by branch ruleset. After you merge a PR, run this script to start the next feature branch off a fresh `origin/main`:

```bash
bash scripts/new-feature-branch.sh
```

**What it does:**
1. Stashes any uncommitted changes (modified and untracked files)
2. Fetches latest from `origin/main`
3. Creates a new branch as `<github-username>/YYYY-MM-DD-HHMM`
4. Pushes the new branch to origin
5. Restores stashed changes onto the new branch

**Options:**
- `--branch <name>` / `-b <name>` — Override the auto-generated branch name
- `--from-current` / `-c` — Branch from the current branch instead of `origin/main` (for stacking branches on an unmerged feature)
- `--help` / `-h` — Show help

**Set your GitHub username** (one-time, optional — the script can usually auto-detect):
```bash
git config --global github.user "your-github-username"
```

### Manual Branch Creation (If Not Using Script)
```bash
git fetch origin main
git checkout -b <github-username>/$(date +%Y-%m-%d-%H%M) origin/main
git push -u origin HEAD
```

### Branch Naming Convention
- **Default (from script)**: `<github-username>/YYYY-MM-DD-HHMM` (e.g. `sean/2026-04-13-1742`)
- **Manual override**: `feature/<description>`, `bugfix/<description>`, `hotfix/<description>`, `refactor/<description>`, `docs/<description>`

## Commit Workflow

### Standard Commit Process
```bash
git status                         # 1. Check status
git diff                           # 2. Review changes
git add <files>                    # 3. Stage files
git commit -m "feat: ..."          # 4. Commit (see format below)
```

### Commit Message Format
```
<type>: <subject>

<body>

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code refactoring
- `docs`: Documentation
- `test`: Tests
- `chore`: Maintenance
- `perf`: Performance improvements

### Using Heredoc for Multi-Line Commits
```bash
git commit -m "$(cat <<'EOF'
feat: Add user authentication system

Implements JWT-based authentication with role-based access control.
Includes login, logout, and session management.

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

## Pull Request Creation

### Workflow (PR Required — Direct Pushes to main Blocked)

```bash
# 1. Confirm you're on a feature branch (NOT main)
git branch --show-current

# 2. Push your work
git push

# 3. Create PR (non-draft so GitHub Copilot auto-reviews it)
gh pr create --base main --fill

# 4. View the PR in browser to verify Copilot review starts
gh pr view --web
```

### Full PR Body Template
```bash
gh pr create --title "Add user authentication" --body "$(cat <<'EOF'
## Summary
- Implement JWT-based authentication
- Add role-based access control
- Create login/logout endpoints

## Test Plan
- [ ] Test user login flow
- [ ] Verify token generation
- [ ] Test role permissions
- [ ] Validate session management

🤖 Generated with Claude Code
EOF
)"
```

### PR Best Practices
1. **Clear title**: Describe what the PR does (under 70 characters)
2. **Summary section**: Bullet points of changes
3. **Test plan**: Checklist of testing steps
4. **Link issues**: Reference related issues with `Closes #123`
5. **Screenshots**: For UI changes
6. **Wait for Copilot review**: Copilot auto-reviews on this repo — read its comments before merging
7. **Merge via squash**: This repo only allows squash merges (enforced by ruleset)

### After Merge
```bash
# Start the next feature branch from the freshly-merged main
bash scripts/new-feature-branch.sh
```

## Issue Management

### Get Current GitHub User
```bash
# Always use dynamic lookup — never hardcode usernames
gh api user --jq '.login'
```

### Check Available Labels Before Creating Issues
**⚠️ ALWAYS run this FIRST** to avoid label errors (label names are case-sensitive and many repos use emoji prefixes):

```bash
gh label list --limit 100
```

### Standard Workflow for All Issues
```bash
# 1. Get current user
CURRENT_USER=$(gh api user --jq '.login')

# 2. Create issue with appropriate template
gh issue create --title "Issue Title" --assignee "$CURRENT_USER" --body "..."

# 3. IMMEDIATELY add to IJACK Roadmap project (REQUIRED)
gh project item-add 12 --owner ijack-technologies --url <ISSUE_URL>
```

### Available Issue Templates
Located in `.github/ISSUE_TEMPLATE/` (if present):
- 🐛 Bug Reports
- 📍 Features
- 💡 Ideas
- 🙋 Service Requests
- 🏌️ User Stories
- ⛳ Epics

## Common Git Operations

### Update Feature Branch from Main
```bash
# Fetch latest main without changing branches
git fetch origin main

# Rebase your feature branch onto origin/main (preferred — keeps linear history)
git rebase origin/main

# Or merge (less preferred — creates merge commits)
git merge origin/main
```

### Stash Changes
```bash
git stash push -u -m "WIP: description"   # Save (incl. untracked)
git stash list                            # List
git stash pop                             # Apply and remove top stash
```

### Amend Commit
```bash
# Amend last commit (ONLY if not pushed!)
git add <files>
git commit --amend --no-edit
```

### Reset Changes
```bash
git reset HEAD <file>      # Unstage a file
git checkout -- <file>     # Discard changes in working tree
git reset --hard HEAD      # Reset everything (DANGER — discards working tree)
```

## Branch Management

### List Branches
```bash
git branch        # Local
git branch -r     # Remote
git branch -a     # All
```

### Delete Branch
```bash
git branch -d feature/completed              # Local (merged only)
git branch -D feature/abandoned              # Local (force, unmerged)
git push origin --delete feature/completed   # Remote
```

## Git History and Logs

```bash
git log --oneline -10                # Recent commits, compact
git log --graph --oneline --all      # Visual graph
git log --follow <file>              # File-specific history
git diff                             # Unstaged changes
git diff --staged                    # Staged changes
git diff main..feature/branch        # Compare branches
```

## Troubleshooting

### Merge Conflicts
```bash
git status                           # Show conflicted files
# Edit conflicting files (look for <<<<<<, ======, >>>>>> markers)
git add <resolved-files>             # Mark resolved
git commit                           # Or git rebase --continue if rebasing
```

### Undo Last Commit (Not Yet Pushed)
```bash
git reset --soft HEAD~1   # Keep changes staged
git reset --mixed HEAD~1  # Keep changes unstaged
git reset --hard HEAD~1   # Discard changes (DANGER)
```

### Recover Lost Commits
```bash
git reflog                           # Show ref history
git checkout <commit-hash>           # View lost commit
git branch recovery <commit-hash>    # Save it on a new branch
```

## Best Practices

1. **Use `scripts/new-feature-branch.sh` after every merge** — never push directly to `main` (it's blocked by ruleset anyway)
2. **Commit often**: Small, focused commits
3. **Write clear messages**: Describe *why*, not *what*
4. **Test before commit**: Run linters and tests
5. **Pull/rebase before push**: Keep branch updated
6. **Open draft PRs early**: Get Copilot's review running while you finish
7. **Add issues to Project #12**: ALWAYS add all issues to IJACK Roadmap
8. **Delete merged branches**: Clean up after PR merge
9. **Squash merges only**: This repo's ruleset only allows squash merges (enforces linear history)

## Integration
This skill automatically activates when:
- Creating feature branches
- Committing code changes
- Creating pull requests
- Managing git workflows
- Adding issues to project board
- Branch management tasks
- Issue tracking
- Git troubleshooting
