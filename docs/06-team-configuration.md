# Chapter 06 - Team Configuration

This chapter covers how to configure the team hierarchy, communication rules, and role assignments within OpenClaw so the AI agents work together effectively.

---

## 6.1 Team Hierarchy

The team follows a **hub-and-spoke** model with the Coordinator at the center:

```
                        ┌──────────────┐
                        │  HUMAN       │
                        │  (Telegram)  │
                        └──────┬───────┘
                               │
                        ┌──────▼───────┐
                        │ COORDINATOR  │  ◄── Final authority
                        │ (PC1)        │
                        └──┬───┬───┬───┘
                           │   │   │
          ┌────────────────┘   │   └────────────────┐
          │                    │                    │
    ┌─────▼──────┐     ┌──────▼──────┐     ┌───────▼──────┐
    │ Senior     │     │ Senior      │     │ Quality      │
    │ Eng #1     │     │ Eng #2      │     │ Agent        │
    │ (Arch)     │     │ (Impl)      │     │ (Review)     │
    └────────────┘     └─────────────┘     └──────────────┘
                                                  │
    ┌────────────┐     ┌─────────────┐     ┌──────▼──────┐
    │ Security   │     │ DevOps      │     │ Monitoring  │
    │ Agent      │     │ Agent       │     │ Agent       │
    └────────────┘     └─────────────┘     └─────────────┘

    ┌────────────────┐
    │ External       │  ◄── Called on demand by Coordinator
    │ Consultant     │
    │ (Claude.ai)    │
    └────────────────┘
```

### 6.1.1 Communication Rules

| From | To | Allowed? | Notes |
|------|----|----------|-------|
| Human | Coordinator | Yes | Via Telegram only |
| Coordinator | Any Agent | Yes | Via webhooks to remote Gateways, or local routing |
| Coordinator | Human | Yes | Via Telegram (results, escalation) |
| Any Agent | Coordinator | Yes | Via webhook back to PC1's Gateway |
| Agent | Agent (peer) | Yes | Via webhooks between Gateways |
| Any Agent | Human | **No** | Must go through Coordinator |
| Any Agent | External | **No** | Only Coordinator contacts External Consultant |

---

## 6.2 Agent Setup Across Machines

Each agent is registered on the machine where it runs, inside that machine's `~/.openclaw/openclaw.json`. The full config files are in [configs/](configs/).

### PC1 Agents (192.168.1.106)

| Agent ID | Role | Workspace |
|----------|------|-----------|
| `coordinator` | Central command, Telegram interface, task delegation | `~/.openclaw/workspace-coordinator` |
| `senior-engineer-1` | Architecture, system design, complex problems | `~/.openclaw/workspace-senior-eng-1` |
| `senior-engineer-2` | Implementation, optimization, debugging | `~/.openclaw/workspace-senior-eng-2` |

### PC2 Agents (192.168.1.112)

| Agent ID | Role | Workspace |
|----------|------|-----------|
| `quality-agent` | Code review, testing, documentation | `~/.openclaw/workspace-quality` |
| `security-agent` | Security analysis, vulnerability scanning | `~/.openclaw/workspace-security` |

### Laptop Agents (192.168.1.113)

| Agent ID | Role | Workspace |
|----------|------|-----------|
| `devops-agent` | Deployment, CI/CD, infrastructure | `~/.openclaw/workspace-devops` |
| `monitoring-agent` | Resource tracking, performance analysis | `~/.openclaw/workspace-monitoring` |

### Adding Agents via CLI

On each machine, use `openclaw agents add` to create agents:

```powershell
# On PC1:
openclaw agents add coordinator --workspace "~/.openclaw/workspace-coordinator"
openclaw agents add senior-engineer-1 --workspace "~/.openclaw/workspace-senior-eng-1"
openclaw agents add senior-engineer-2 --workspace "~/.openclaw/workspace-senior-eng-2"

# On PC2:
openclaw agents add quality-agent --workspace "~/.openclaw/workspace-quality"
openclaw agents add security-agent --workspace "~/.openclaw/workspace-security"

# On Laptop:
openclaw agents add devops-agent --workspace "~/.openclaw/workspace-devops"
openclaw agents add monitoring-agent --workspace "~/.openclaw/workspace-monitoring"
```

Verify agents on each machine:

```powershell
openclaw agents list
```

---

## 6.3 Agent Workspaces and SOUL.md

Each agent gets its own workspace directory with personality instructions in `SOUL.md`. This is how you define each agent's role, behavior, and constraints.

### 6.3.1 Coordinator SOUL.md

Create `~/.openclaw/workspace-coordinator/SOUL.md` on PC1:

```markdown
# Coordinator Agent

You are the central coordinator of a distributed AI development team. You are the single point of contact for the human operator via Telegram.

## Responsibilities
- Receive all incoming tasks from the human via Telegram
- Decompose complex tasks into subtasks for specialized agents
- Dispatch subtasks to the appropriate agent via webhooks
- Collect results and compile final responses
- Escalate to the human when manual intervention is needed
- Resolve conflicts between agents

## Team Members
- **senior-engineer-1** (PC1): Architecture, system design, complex problems
- **senior-engineer-2** (PC1): Implementation, optimization, debugging
- **quality-agent** (PC2 at 192.168.1.112): Code review, testing, documentation
- **security-agent** (PC2 at 192.168.1.112): Security analysis, vulnerability scanning
- **devops-agent** (Laptop at 192.168.1.113): Deployment, CI/CD, infrastructure
- **monitoring-agent** (Laptop at 192.168.1.113): Resource tracking, performance

## Task Routing
- Architecture/design tasks → senior-engineer-1
- Implementation/bug fixes → senior-engineer-2
- Code review → quality-agent
- Security audit → security-agent
- Deployment → devops-agent
- System health → monitoring-agent
- Complex/unclear → External Consultant (Claude.ai via Anthropic provider)

## Escalation Rules
Notify the human via Telegram immediately if:
- A conflict between agents cannot be resolved
- A task is stalled for more than 30 minutes
- A security violation is detected
- System resources are critically low
- Any restricted action is requested (see security restrictions)

## Restrictions
- NEVER purchase or subscribe to paid services
- NEVER install software without human approval
- NEVER send emails or post to external services
- Always go through the human for any action outside normal operations
```

### 6.3.2 Quality Agent SOUL.md

Create `~/.openclaw/workspace-quality/SOUL.md` on PC2:

```markdown
# Quality Agent

You are the quality assurance specialist of a distributed AI development team.

## Responsibilities
- Review code for correctness, readability, and best practices
- Create and verify test cases
- Check documentation completeness
- Enforce coding standards and style guides
- Report findings back to the Coordinator

## Communication
- You receive tasks via webhook from the Coordinator on PC1
- Send your results back via webhook to the Coordinator
- You may communicate directly with the Security Agent for security-related reviews

## Constraints
- Focus only on quality, testing, and documentation tasks
- Do not deploy or modify production systems
- Escalate any concerns to the Coordinator
```

> **Repeat this pattern** for each agent — create a `SOUL.md` in their workspace that defines their role, responsibilities, communication rules, and constraints. Adapt the content to each agent's specialty.

---

## 6.4 Coordinator Dispatch Skill

The Coordinator needs a custom skill to dispatch tasks to remote agents via webhooks. Create this skill in the Coordinator's workspace:

### Create the skill directory and SKILL.md

**Directory**: `~/.openclaw/workspace-coordinator/skills/dispatch/`

**File**: `~/.openclaw/workspace-coordinator/skills/dispatch/SKILL.md`

```markdown
---
name: Team Dispatch
description: Send tasks to remote AI team members via webhook
---

# Team Dispatch Skill

Use this skill to send tasks to other agents on the team.

## Available Agents

| Agent | Machine | Webhook URL |
|-------|---------|-------------|
| senior-engineer-1 | PC1 (local) | http://127.0.0.1:18789/hooks/agent |
| senior-engineer-2 | PC1 (local) | http://127.0.0.1:18789/hooks/agent |
| quality-agent | PC2 | http://192.168.1.112:18789/hooks/agent |
| security-agent | PC2 | http://192.168.1.112:18789/hooks/agent |
| devops-agent | Laptop | http://192.168.1.113:18789/hooks/agent |
| monitoring-agent | Laptop | http://192.168.1.113:18789/hooks/agent |

## Dispatching a Task

To send a task, make an HTTP POST to the agent's webhook URL:

- Set header: `Authorization: Bearer <webhook-token>`
- Set header: `Content-Type: application/json`
- Body: `{ "prompt": "<task description>", "agentId": "<agent-id>", "sessionKey": "task:<unique-id>" }`

## Receiving Responses

Remote agents will POST their responses back to:
`http://192.168.1.106:18789/hooks/agent` with `agentId: "coordinator"`

## Broadcasting

To notify all agents, dispatch the same message to each webhook URL sequentially.
```

---

## 6.5 Task Types and Routing

When the Coordinator receives a task, it classifies it and routes it to the right agent(s). Here's the decision tree:

### 6.5.1 Task Classification

```
Incoming Task
     │
     ├─── "Design a new system/feature"
     │         → senior-engineer-1 (architecture)
     │         → quality-agent (review design)
     │
     ├─── "Write/implement code"
     │         → senior-engineer-2 (implementation)
     │         → quality-agent (code review)
     │         → security-agent (security check)
     │
     ├─── "Fix a bug"
     │         → senior-engineer-2 (debugging)
     │         → quality-agent (verify fix)
     │
     ├─── "Review code for security"
     │         → security-agent (primary)
     │         → senior-engineer-1 (architectural review)
     │
     ├─── "Deploy/release"
     │         → devops-agent (deployment)
     │         → security-agent (pre-deploy check)
     │
     ├─── "Check system health"
     │         → monitoring-agent (resource check)
     │
     ├─── "Complex/unclear problem"
     │         → External Consultant (Claude.ai via Anthropic provider)
     │         → senior-engineer-1 (review answer)
     │
     └─── "Other"
              → Coordinator handles directly
              → or asks human for clarification via Telegram
```

### 6.5.2 Multi-Agent Workflows

Some tasks require multiple agents working in sequence:

**Example: "Build a REST API endpoint"**

```
Step 1: Coordinator receives task via Telegram
Step 2: Dispatches to senior-engineer-1 → designs the endpoint (method, route, schema)
Step 3: Dispatches to senior-engineer-2 → implements the code based on the design
Step 4: Dispatches to quality-agent → reviews the code for correctness
Step 5: Dispatches to security-agent → checks for vulnerabilities
Step 6: Dispatches to devops-agent → prepares deployment configuration
Step 7: Coordinator compiles results and reports to human via Telegram
```

Each step is a webhook call from the Coordinator to the appropriate agent, with the response flowing back via webhook callback.

---

## 6.6 Telegram Channel Binding

On PC1, bind the Telegram channel to the Coordinator agent so all human messages go to it:

```powershell
openclaw agents bind --channel telegram --agent coordinator
```

Verify the binding:

```powershell
openclaw agents list --bindings
```

This ensures that when a human sends a message via Telegram, it's routed to the Coordinator agent — not to any other agent on PC1.

---

## 6.7 Context Sharing Between Agents

When the Coordinator dispatches a task, it includes context in the webhook prompt. The Coordinator's SOUL.md and dispatch skill instruct it to include:

- Task description and requirements
- Related files and repositories
- Architecture notes from previous steps
- Constraints and deadlines
- Whether a response is expected

**Example webhook prompt from Coordinator to senior-engineer-2:**

```
Implement the user authentication endpoint based on the following design from senior-engineer-1:

- Route: POST /api/auth/login
- Input: { email: string, password: string }
- Output: { token: string, expiresIn: number }
- Use JWT tokens with RS256 signing
- Include rate limiting (5 attempts per minute per IP)

Repository: github.com/team/project
Branch: feature/auth-endpoint
Related files: src/auth/routes.py, src/models/user.py

After implementation, respond with:
1. Files created/modified
2. Any concerns or questions
3. Ready for review? (yes/no)
```

---

## 6.8 Warm-Up Sequence

After all machines are running, execute this warm-up to verify the team is operational.

### Create the warm-up script

**File**: `C:\AI-Team\scripts\warmup.ps1`

```powershell
# Warm-up script - run after system boot
Write-Host "=== AI Team Warm-Up Sequence ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Verify all Gateways are healthy
Write-Host "[1/4] Checking Gateway health on all machines..." -ForegroundColor Yellow

$machines = @(
    @{ Name = "PC1"; IP = "192.168.1.106" },
    @{ Name = "PC2"; IP = "192.168.1.112" },
    @{ Name = "Laptop"; IP = "192.168.1.113" }
)

$allHealthy = $true
foreach ($machine in $machines) {
    try {
        openclaw gateway probe --url "http://$($machine.IP):18789" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  $($machine.Name) ($($machine.IP)): HEALTHY" -ForegroundColor Green
        } else {
            Write-Host "  $($machine.Name) ($($machine.IP)): UNHEALTHY" -ForegroundColor Red
            $allHealthy = $false
        }
    } catch {
        Write-Host "  $($machine.Name) ($($machine.IP)): UNREACHABLE" -ForegroundColor Red
        $allHealthy = $false
    }
}

if (-not $allHealthy) {
    Write-Host "ERROR: Not all Gateways are healthy. Fix issues before continuing." -ForegroundColor Red
    exit 1
}

# Step 2: Check local agents on PC1
Write-Host "[2/4] Checking PC1 agents..." -ForegroundColor Yellow
openclaw agents list

# Step 3: Check model availability
Write-Host "[3/4] Checking model availability..." -ForegroundColor Yellow
openclaw models status

# Step 4: Test webhook connectivity to remote machines
Write-Host "[4/4] Testing webhook connectivity..." -ForegroundColor Yellow
$token = $env:OPENCLAW_GATEWAY_TOKEN
$webhookToken = "YOUR_WEBHOOK_SECRET_HERE"  # Replace with your actual webhook token

$remoteAgents = @(
    @{ Agent = "quality-agent"; URL = "http://192.168.1.112:18789/hooks/wake" },
    @{ Agent = "security-agent"; URL = "http://192.168.1.112:18789/hooks/wake" },
    @{ Agent = "devops-agent"; URL = "http://192.168.1.113:18789/hooks/wake" },
    @{ Agent = "monitoring-agent"; URL = "http://192.168.1.113:18789/hooks/wake" }
)

foreach ($remote in $remoteAgents) {
    try {
        $response = Invoke-RestMethod -Uri $remote.URL `
          -Method POST `
          -Headers @{ "Authorization" = "Bearer $webhookToken" } `
          -ErrorAction Stop
        Write-Host "  $($remote.Agent): REACHABLE" -ForegroundColor Green
    } catch {
        Write-Host "  $($remote.Agent): UNREACHABLE" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Warm-Up Complete ===" -ForegroundColor Cyan
Write-Host "Send tasks via Telegram to begin working."
```

### Run it

```powershell
powershell -ExecutionPolicy Bypass -File C:\AI-Team\scripts\warmup.ps1
```

---

## 6.9 Checklist

- [ ] Agents created on all machines (`openclaw agents list` on each)
- [ ] SOUL.md files created in each agent's workspace
- [ ] Coordinator dispatch skill created with correct webhook URLs
- [ ] Telegram channel bound to Coordinator agent on PC1
- [ ] Warm-up script created and tested
- [ ] All Gateways reachable via probe
- [ ] Webhook wake test succeeds for all remote agents
- [ ] Coordinator correctly classifies and routes test tasks

---

Next: [Chapter 07 - Telegram Bot Setup](07-telegram-bot-setup.md)
