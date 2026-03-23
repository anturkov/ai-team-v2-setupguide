# Chapter 09 - GitHub Integration

This chapter covers setting up SSH keys, Personal Access Tokens, and configuring OpenClaw to handle GitHub operations for the AI team.

---

## 9.1 Overview

The AI team needs GitHub access for:

- Cloning repositories to work on
- Creating branches for new features
- Committing and pushing code changes
- Creating pull requests for review
- Managing repository files

All GitHub operations go through OpenClaw. Individual models don't access GitHub directly.

---

## 9.2 Generate SSH Keys

SSH keys allow secure, password-less authentication with GitHub. Generate a key pair on **each machine**.

### Step 1: Open PowerShell

Open a regular (non-admin) PowerShell window.

### Step 2: Generate the Key

```powershell
# Generate an SSH key pair
ssh-keygen -t ed25519 -C "ai-team-pc1@yourdomain.com" -f "$env:USERPROFILE\.ssh\id_ed25519_github"
```

When prompted:
- **Passphrase**: Press Enter for no passphrase (simpler for automated use), or enter one for extra security

> **Change the email** for each machine:
> - PC1: `ai-team-pc1@yourdomain.com`
> - PC2: `ai-team-pc2@yourdomain.com`
> - Laptop: `ai-team-laptop@yourdomain.com`

### Step 3: View the Public Key

```powershell
# Display the public key
Get-Content "$env:USERPROFILE\.ssh\id_ed25519_github.pub"
```

Output will look like:

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx ai-team-pc1@yourdomain.com
```

**Copy this entire line.** You'll add it to GitHub in the next step.

### Step 4: Configure SSH to Use This Key for GitHub

Create or edit the SSH config file:

```powershell
# Create the config file if it doesn't exist
if (-not (Test-Path "$env:USERPROFILE\.ssh\config")) {
    New-Item -ItemType File -Path "$env:USERPROFILE\.ssh\config" -Force
}

# Add GitHub configuration
Add-Content -Path "$env:USERPROFILE\.ssh\config" -Value @"

Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github
    IdentitiesOnly yes
"@
```

### Step 5: Add the Key to GitHub

1. Go to https://github.com/settings/keys
2. Click **New SSH key**
3. **Title**: Enter a descriptive name (e.g., `AI Team - PC1`)
4. **Key type**: Keep as "Authentication"
5. **Key**: Paste the public key you copied in Step 3
6. Click **Add SSH key**

**Repeat for each machine** (each machine gets its own key added to the same GitHub account).

### Step 6: Test SSH Connection

On each machine:

```powershell
ssh -T git@github.com
```

Expected output:

```
Hi username! You've successfully authenticated, but GitHub does not provide shell access.
```

If you see "Permission denied", check:
- The public key was added to GitHub correctly
- The SSH config file points to the right key file
- The key file has the right permissions

---

## 9.3 Create a Personal Access Token (PAT)

PATs are needed for GitHub API operations (creating repos, managing PRs, etc.).

### Step 1: Generate the Token

1. Go to https://github.com/settings/tokens?type=beta
2. Click **Generate new token**
3. **Token name**: `AI Team - OpenClaw`
4. **Expiration**: Set to 90 days (you'll need to regenerate periodically)
5. **Repository access**: Select "All repositories" (or specific ones if you prefer)
6. **Permissions** — enable these:
   - **Contents**: Read and write
   - **Pull requests**: Read and write
   - **Issues**: Read and write
   - **Metadata**: Read-only
   - **Commit statuses**: Read and write
7. Click **Generate token**
8. **Copy the token immediately** — you won't see it again

### Step 2: Store the Token Securely

On PC1:

```powershell
# Store the PAT in OpenClaw's secure config
openclaw config set github.token "github_pat_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Set your GitHub username
openclaw config set github.username "your-github-username"

# Set default organization (if applicable)
openclaw config set github.default_org "your-org-name"
```

> **Replace** the placeholder values with your actual token, username, and organization.

### Step 3: Verify GitHub API Access

```powershell
# Test the token
openclaw github test
```

Expected output:

```
GitHub API Connection: OK
Authenticated as: your-github-username
Token permissions: contents:write, pull_requests:write, issues:write
Token expires: 2024-06-15
```

---

## 9.4 Configure Git on Each Machine

Set up Git identity on each machine so commits have the right author:

```powershell
# Set the committer name (same on all machines)
git config --global user.name "AI Development Team"

# Set the committer email (same on all machines)
git config --global user.email "ai-team@yourdomain.com"

# Set default branch name
git config --global init.defaultBranch "main"

# Set default push behavior
git config --global push.default "current"

# Enable credential caching
git config --global credential.helper "store"
```

---

## 9.5 Configure OpenClaw GitHub Integration

### Step 1: Set Up Repository Management

**File**: `C:\AI-Team\openclaw\config\github.yaml`

```yaml
# GitHub Integration Configuration
github:
  enabled: true
  username: "your-github-username"
  token_ref: "config:github.token"    # References the securely stored token

  # Default settings for new repositories
  defaults:
    visibility: "private"              # or "public"
    auto_init: true
    default_branch: "main"
    license: "MIT"                     # or null for no license

  # Working directory for cloned repos
  workspace:
    path: "C:\\AI-Team\\repos"
    auto_sync: true                    # Automatically pull before working
    auto_commit: false                 # Don't auto-commit (let agents decide)

  # Branch strategy
  branching:
    strategy: "feature-branch"         # Each task gets a feature branch
    branch_prefix: "ai-team/"          # Branches created by the team use this prefix
    auto_pr: true                      # Automatically create PR when work is done
    require_review: true               # PR requires review before merge

  # Commit settings
  commits:
    sign_commits: false                # GPG signing (set true if you have GPG set up)
    commit_prefix: "[AI-Team]"         # Prefix for all commits by the team
    include_agent_name: true           # Include which agent made the commit
```

### Step 2: Load the Configuration

```powershell
openclaw github load --config "C:\AI-Team\openclaw\config\github.yaml"
```

---

## 9.6 Common GitHub Operations via OpenClaw

Here are the operations the AI team can perform through OpenClaw:

### 9.6.1 Clone a Repository

```powershell
# Clone a repo to the workspace
openclaw github clone "github.com/your-org/your-repo"

# The repo will be cloned to C:\AI-Team\repos\your-repo\
```

### 9.6.2 Create a New Repository

```powershell
# Create a new private repository
openclaw github create-repo --name "new-project" --private --description "A new project"
```

### 9.6.3 Create a Branch

```powershell
# Create a feature branch for a task
openclaw github branch --repo "your-repo" --name "ai-team/feature-auth" --from "main"
```

### 9.6.4 Commit and Push Changes

```powershell
# Stage and commit changes
openclaw github commit --repo "your-repo" --message "[AI-Team][senior-engineer-2] Implement user authentication endpoint"

# Push to remote
openclaw github push --repo "your-repo"
```

### 9.6.5 Create a Pull Request

```powershell
# Create a PR
openclaw github pr create --repo "your-repo" --title "Add user authentication" --body "Implemented JWT-based auth endpoint" --base "main" --head "ai-team/feature-auth"
```

### 9.6.6 Sync Repository Across Machines

When multiple machines need the same repo:

```powershell
# On PC1: push changes
openclaw github push --repo "your-repo"

# On PC2: pull latest changes
openclaw github pull --repo "your-repo"
```

---

## 9.7 Automated Workflow Example

Here's how a typical development task flows through GitHub:

```
1. Human (Telegram): "Add a login page to the web app"
           │
2. Coordinator: Analyzes task, assigns to Senior Engineer #1 (design) + #2 (implement)
           │
3. OpenClaw: Creates branch "ai-team/feature-login-page" from main
           │
4. Senior Eng #1: Designs the login page (component structure, routes)
           │
5. Senior Eng #2: Implements the code
           │  OpenClaw: Commits "[AI-Team][senior-eng-2] Implement login page"
           │
6. Quality Agent: Reviews the code
           │  If issues found → back to Senior Eng #2
           │
7. Security Agent: Security review
           │  If issues found → back to Senior Eng #2
           │
8. OpenClaw: Creates PR "Add login page to web app"
           │
9. Coordinator: Reports to human via Telegram
           │  "PR created: https://github.com/org/repo/pull/42"
           │
10. Human: Reviews and merges (or requests changes)
```

---

## 9.8 Token Rotation

PATs expire. Set a reminder to rotate them before expiry:

### Check Token Expiry

```powershell
openclaw github token-info
```

### Rotate the Token

1. Go to https://github.com/settings/tokens
2. Generate a new token with the same permissions
3. Update OpenClaw:

```powershell
openclaw config set github.token "github_pat_NEW_TOKEN_HERE"
```

4. Delete the old token on GitHub

> **Tip**: Set a calendar reminder for 1 week before the token expires.

---

## 9.9 Checklist

- [ ] SSH keys generated on all 3 machines
- [ ] All SSH public keys added to GitHub account
- [ ] `ssh -T git@github.com` works on all machines
- [ ] Personal Access Token (PAT) created with correct permissions
- [ ] PAT stored securely in OpenClaw config
- [ ] Git configured with team name and email on all machines
- [ ] GitHub integration configuration loaded in OpenClaw
- [ ] Test clone, commit, push, and PR creation
- [ ] Token expiry date noted and reminder set

---

Next: [Chapter 10 - Task Coordination](10-task-coordination.md)
