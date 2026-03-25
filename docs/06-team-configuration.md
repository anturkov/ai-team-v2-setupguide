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

## 6.2 Agent Setup — All on PC1's Gateway

> **Key concept**: ALL agents are registered on **PC1's Gateway**, regardless of which machine runs their model. The Gateway routes each agent's inference requests to the correct Ollama provider (local, PC2, or Laptop) based on the agent's model configuration. PC2 and Laptop do NOT register agents — they only run Ollama and connect as Nodes.

| Agent ID | Role | Model Provider | Ollama Instance | Workspace (on PC1) |
|----------|------|----------------|-----------------|---------------------|
| `coordinator` | Central command, Telegram interface | `ollama-local` | PC1 (127.0.0.1:11434) | `~/.openclaw/workspace-coordinator` |
| `senior-engineer-1` | Architecture, system design | `ollama-local` | PC1 (127.0.0.1:11434) | `~/.openclaw/workspace-senior-eng-1` |
| `senior-engineer-2` | Implementation, optimization | `ollama-local` | PC1 (127.0.0.1:11434) | `~/.openclaw/workspace-senior-eng-2` |
| `quality-agent` | Code review, testing, documentation | `ollama-pc2` | PC2 (192.168.1.112:11434) | `~/.openclaw/workspace-quality` |
| `security-agent` | Security analysis, vulnerability scanning | `ollama-pc2` | PC2 (192.168.1.112:11434) | `~/.openclaw/workspace-security` |
| `devops-agent` | Deployment, CI/CD, infrastructure | `ollama-laptop` | Laptop (192.168.1.113:11434) | `~/.openclaw/workspace-devops` |
| `monitoring-agent` | Resource tracking, performance analysis | `ollama-laptop` | Laptop (192.168.1.113:11434) | `~/.openclaw/workspace-monitoring` |

### Adding Agents via CLI (all on PC1)

Run all of these on **PC1 only**:

```powershell
# Register all 7 agents on PC1's Gateway
openclaw agents add coordinator --workspace "~/.openclaw/workspace-coordinator" --non-interactive
openclaw agents add senior-engineer-1 --workspace "~/.openclaw/workspace-senior-eng-1" --non-interactive
openclaw agents add senior-engineer-2 --workspace "~/.openclaw/workspace-senior-eng-2" --non-interactive
openclaw agents add quality-agent --workspace "~/.openclaw/workspace-quality" --non-interactive
openclaw agents add security-agent --workspace "~/.openclaw/workspace-security" --non-interactive
openclaw agents add devops-agent --workspace "~/.openclaw/workspace-devops" --non-interactive
openclaw agents add monitoring-agent --workspace "~/.openclaw/workspace-monitoring" --non-interactive
```

Verify all agents:

```powershell
openclaw agents list
```

You should see all 7 agents listed, each with its own workspace directory.

### Assigning Models to Agents

> **Important**: There is **no CLI command** to assign a model to a specific agent. The command `openclaw agents config --model` does not exist ([Issue #37082](https://github.com/openclaw/openclaw/issues/37082)). Per-agent model assignment is done by **editing `openclaw.json` directly**.

The model identifier format is `<provider-name>/<model-id>`, matching the output of `openclaw models list`. For example: `ollama-pc2/quality-agent:latest`.

**Edit `~/.openclaw/openclaw.json` on PC1.** In the `agents.list` array, each agent needs these fields:

| Field | Purpose | Required? |
|-------|---------|-----------|
| `id` | Unique identifier for the agent | Yes |
| `name` | Display name (usually same as `id`) | Yes — agents without `name` may not fully initialize |
| `workspace` | Path to the agent's workspace directory (contains SOUL.md, skills, memory) | Yes |
| `agentDir` | Path to the agent's state directory (auth profiles, session data) | Yes — **without this, the workspace directory may not be created** |
| `model.primary` | The `provider/model-id` this agent should use | Recommended (otherwise inherits default) |
| `default` | Set to `true` for the default agent (receives unrouted messages) | Only on one agent |

> **⚠️ Critical: All four fields (`id`, `name`, `workspace`, `agentDir`) are required for each agent.** If `name` or `agentDir` are missing, OpenClaw may not create the workspace directory or fully register the agent. This is a common issue when agents are added by manually editing the JSON rather than using `openclaw agents add`.

Here is the complete `agents.list` with all required fields:

```json
{
  "agents": {
    "list": [
      {
        "id": "coordinator",
        "name": "coordinator",
        "default": true,
        "workspace": "C:\\Users\\atuadm\\.openclaw\\workspace-coordinator",
        "agentDir": "C:\\Users\\atuadm\\.openclaw\\agents\\coordinator\\agent"
      },
      {
        "id": "senior-engineer-1",
        "name": "senior-engineer-1",
        "workspace": "C:\\Users\\atuadm\\.openclaw\\workspace-senior-eng-1",
        "agentDir": "C:\\Users\\atuadm\\.openclaw\\agents\\senior-engineer-1\\agent",
        "model": {
          "primary": "ollama/senior-eng-1:latest"
        }
      },
      {
        "id": "senior-engineer-2",
        "name": "senior-engineer-2",
        "workspace": "C:\\Users\\atuadm\\.openclaw\\workspace-senior-eng-2",
        "agentDir": "C:\\Users\\atuadm\\.openclaw\\agents\\senior-engineer-2\\agent",
        "model": {
          "primary": "ollama/senior-eng-2:latest"
        }
      },
      {
        "id": "quality-agent",
        "name": "quality-agent",
        "workspace": "C:\\Users\\atuadm\\.openclaw\\workspace-quality",
        "agentDir": "C:\\Users\\atuadm\\.openclaw\\agents\\quality-agent\\agent",
        "model": {
          "primary": "ollama-pc2/quality-agent:latest"
        }
      },
      {
        "id": "security-agent",
        "name": "security-agent",
        "workspace": "C:\\Users\\atuadm\\.openclaw\\workspace-security",
        "agentDir": "C:\\Users\\atuadm\\.openclaw\\agents\\security-agent\\agent",
        "model": {
          "primary": "ollama-pc2/security-agent:latest"
        }
      },
      {
        "id": "devops-agent",
        "name": "devops-agent",
        "workspace": "C:\\Users\\atuadm\\.openclaw\\workspace-devops",
        "agentDir": "C:\\Users\\atuadm\\.openclaw\\agents\\devops-agent\\agent",
        "model": {
          "primary": "ollama-laptop/devops-agent:latest"
        }
      },
      {
        "id": "monitoring-agent",
        "name": "monitoring-agent",
        "workspace": "C:\\Users\\atuadm\\.openclaw\\workspace-monitoring",
        "agentDir": "C:\\Users\\atuadm\\.openclaw\\agents\\monitoring-agent\\agent",
        "model": {
          "primary": "ollama-laptop/monitoring-agent:latest"
        }
      }
    ]
  }
}
```

> **Model format**: The format is `<provider>/<model-id>`. Match the values from `openclaw models list` output exactly (e.g., `ollama-pc2/quality-agent:latest`, not just `quality-agent`).

> **See [`docs/current_config/claude_openclaw_pc1.json`](current_config/claude_openclaw_pc1.json)** for the complete corrected config file with all changes annotated.

### If Workspaces Were Not Created

If any agent's workspace directory doesn't exist on disk after adding the `name` and `agentDir` fields, create them manually and restart:

```powershell
# Create missing workspace directories
mkdir ~\.openclaw\workspace-senior-eng-1 -Force
mkdir ~\.openclaw\workspace-senior-eng-2 -Force

# Create missing agentDir directories
mkdir ~\.openclaw\agents\senior-engineer-1\agent -Force
mkdir ~\.openclaw\agents\senior-engineer-2\agent -Force

# Restart to pick up changes
openclaw gateway restart
```

Then copy the SOUL.md files into each workspace (see [Section 6.3](#63-agent-workspaces-and-soulmd)).

### The Default Model and Fallback Chain

The `agents.defaults.model` section controls what happens when an agent doesn't have a per-agent model, or when its primary model is unavailable:

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "ollama/coordinator:latest",
        "fallbacks": [
          "ollama/senior-eng-1:latest",
          "ollama/senior-eng-2:latest",
          "ollama-pc2/quality-agent:latest",
          "ollama-pc2/security-agent:latest",
          "ollama-laptop/devops-agent:latest",
          "ollama-laptop/monitoring-agent:latest",
          "ollama-pc2/codellama:7b-instruct-q4_K_M"
        ]
      }
    }
  }
}
```

- `primary`: The default model for any agent without a per-agent override (the coordinator, since it's the `default` agent)
- `fallbacks`: Models tried in order if an agent's primary is unavailable

### Critical Fix: Verify Your Default Ollama Provider URL

> **⚠️ Check this now:** The onboarding wizard may have auto-discovered a remote Ollama instance and set it as the default `ollama` provider. Verify:
>
> ```powershell
> openclaw config get models.providers.ollama.baseUrl
> ```
>
> If this returns a remote IP (like `http://192.168.1.112:11434`) instead of `http://127.0.0.1:11434`, your PC1 local models are being served from the wrong machine! Fix it:
>
> ```powershell
> openclaw config set models.providers.ollama.baseUrl "http://127.0.0.1:11434"
> ```

### After Editing: Restart the Gateway

After any config changes, restart the Gateway to pick them up:

```powershell
openclaw gateway restart
openclaw doctor --fix
```

Verify agents now show their assigned models:

```powershell
openclaw agents list
```

Agents should show `(explicit)` next to their model if the per-agent override is working, or `(inherited)` if using the default.

> **Known Bug ([#29571](https://github.com/openclaw/openclaw/issues/29571))**: `agents.defaults.model.primary` may override per-agent model config at runtime. If agents aren't using their assigned model, check the fallback chain. Workaround: set the most-used agent's model as the global default.

> **How it works**: When the Coordinator dispatches a task to the quality-agent, the Gateway sees its model is `ollama-pc2/quality-agent:latest`, and routes the inference request to `http://192.168.1.112:11434` (PC2's Ollama). The model runs on PC2's GPU, but the agent logic, session state, and workspace all live on PC1.

---

## 6.3 Agent Workspaces and SOUL.md

Each agent gets its own workspace directory with personality instructions in `SOUL.md`. This is how you define each agent's role, behavior, and constraints.

> **All workspaces live on PC1** (the Gateway machine). Even agents whose models run on PC2 or Laptop have their workspace on PC1 — the Gateway reads the SOUL.md and passes it as context to the remote Ollama model.

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

Create `~/.openclaw/workspace-quality/SOUL.md` on PC1 (model runs on PC2, but workspace is on PC1):

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

### 6.3.3 Senior Engineer #1 SOUL.md

Create `~/.openclaw/workspace-senior-eng-1/SOUL.md` on PC1:

```markdown
# Senior Engineer #1 — Architecture

You are the architecture specialist of a distributed AI development team.

## Responsibilities
- Design system architecture for new projects and features
- Make high-level technical decisions (frameworks, patterns, data structures)
- Review and validate architectural decisions proposed by other team members
- Identify scalability and maintainability issues
- Create technical specifications and design documents

## Communication
- You receive tasks via the Coordinator (local routing on PC1, or webhook)
- Send your results back to the Coordinator
- Collaborate with Senior Engineer #2 on implementation details
- Consult with Security Agent on security architecture

## Constraints
- Focus on architecture and design — defer implementation to Senior Engineer #2
- Document all architectural decisions with rationale
- Prefer proven patterns over novel approaches unless innovation is justified
- Escalate any concerns to the Coordinator
```

### 6.3.4 Senior Engineer #2 SOUL.md

Create `~/.openclaw/workspace-senior-eng-2/SOUL.md` on PC1:

```markdown
# Senior Engineer #2 — Implementation

You are the implementation and optimization specialist of a distributed AI development team.

## Responsibilities
- Write clean, efficient, production-ready code
- Implement features based on architectural designs from Senior Engineer #1
- Optimize existing code for performance
- Refactor code for readability and maintainability
- Write unit tests for your implementations
- Debug and fix complex issues

## Communication
- You receive tasks via the Coordinator (local routing on PC1, or webhook)
- Send your results back to the Coordinator
- Follow architectural guidance from Senior Engineer #1
- Submit code for review by the Quality Agent

## Constraints
- Write code that is correct first, then optimize
- Follow the project's existing code style and conventions
- Keep functions small and focused
- Escalate blockers to the Coordinator
```

### 6.3.5 Security Agent SOUL.md

Create `~/.openclaw/workspace-security/SOUL.md` on PC1 (model runs on PC2):

```markdown
# Security Agent

You are the security specialist of a distributed AI development team.

## Responsibilities
- Review code for security vulnerabilities (OWASP Top 10)
- Analyze dependencies for known vulnerabilities
- Validate authentication and authorization implementations
- Check for data exposure risks (secrets in code, logs, etc.)
- Review network configurations for security issues
- Enforce compliance with the team's security restrictions

## Communication
- You receive tasks via webhook from the Coordinator on PC1
- Send your results back via webhook to the Coordinator
- Coordinate with DevOps Agent on infrastructure security
- Work with Senior Engineers to fix identified vulnerabilities

## Team Security Rules to Enforce
- No purchases or paid service signups
- No software installation without human approval
- No external communications (email, social media, forums)
- No personal data collection beyond what's provided
- No network configuration changes
- Report violations immediately via Coordinator to Telegram

## Constraints
- Rate findings by severity (LOW / MEDIUM / HIGH / CRITICAL)
- Focus on security — defer code quality issues to the Quality Agent
- Escalate any concerns to the Coordinator
```

### 6.3.6 DevOps Agent SOUL.md

Create `~/.openclaw/workspace-devops/SOUL.md` on PC1 (model runs on Laptop):

```markdown
# DevOps Agent

You are the deployment and infrastructure specialist of a distributed AI development team.

## Responsibilities
- Manage deployment processes and pipelines
- Configure and maintain infrastructure
- Handle CI/CD pipeline setup and troubleshooting
- Manage Docker containers and environments
- Monitor deployment health and rollback if needed
- Manage Git workflows (branches, merges, releases)
- Automate repetitive infrastructure tasks

## Communication
- You receive tasks via webhook from the Coordinator on PC1
- Send your results back via webhook to the Coordinator
- Work with Senior Engineers on deployment requirements
- Coordinate with Security Agent on secure deployment practices

## Constraints
- Do NOT make network configuration changes without human approval
- Do NOT modify firewall rules
- Do NOT install new software without human approval
- Prefer automation over manual steps
- Document all infrastructure changes
- Escalate any infrastructure changes that affect other team members
```

### 6.3.7 Monitoring Agent SOUL.md

Create `~/.openclaw/workspace-monitoring/SOUL.md` on PC1 (model runs on Laptop):

```markdown
# Monitoring Agent

You are the resource tracking and performance analysis specialist of a distributed AI development team.

## Responsibilities
- Track system resource usage across all machines (CPU, RAM, GPU, disk)
- Monitor model inference performance (response times, throughput)
- Detect and alert on resource exhaustion risks
- Analyze performance trends and recommend optimizations
- Track task completion times and team productivity metrics
- Generate health reports for the Coordinator

## Alert Thresholds
- GPU Temperature > 80C: WARNING
- GPU Temperature > 90C: CRITICAL
- VRAM Usage > 90%: WARNING
- RAM Usage > 85%: WARNING
- Disk Space < 10 GB: WARNING
- Disk Space < 5 GB: CRITICAL
- Model response time > 60s: WARNING

## Communication
- You receive tasks via webhook from the Coordinator on PC1
- Send regular health reports to the Coordinator
- Alert immediately on CRITICAL conditions
- Recommend resource reallocation when needed

## Constraints
- Focus on monitoring and reporting — do not take corrective actions without approval
- Escalate CRITICAL alerts to the Coordinator immediately
```

> **Note on Modelfiles vs SOUL.md**: These are two different layers. **Modelfiles** (in the [`models/`](../models/) directory) define the Ollama model's base system prompt, temperature, and context size — they are baked into the model at `ollama create` time. **SOUL.md** files define the OpenClaw agent's personality and instructions — they are read by the Gateway at runtime and can be edited without rebuilding the model. Both should be consistent in describing each agent's role.

---

## 6.4 Coordinator Dispatch Skill

The Coordinator needs a custom skill to dispatch tasks to other agents on the same Gateway. Since all agents are registered on PC1's Gateway, dispatch uses OpenClaw's native **sub-agent spawning** — no webhooks needed.

### Create the skill directory and SKILL.md

**Directory**: `~/.openclaw/workspace-coordinator/skills/dispatch/`

**File**: `~/.openclaw/workspace-coordinator/skills/dispatch/SKILL.md`

```markdown
---
name: Team Dispatch
description: Send tasks to AI team members via sub-agent sessions
---

# Team Dispatch Skill

Use this skill to send tasks to other agents on the team. All agents run on the same Gateway — dispatch happens via OpenClaw's native session spawning.

## Available Agents

| Agent | Model Location | Specialty |
|-------|---------------|-----------|
| senior-engineer-1 | PC1 (local Ollama) | Architecture, system design |
| senior-engineer-2 | PC1 (local Ollama) | Implementation, optimization |
| quality-agent | PC2 (remote Ollama) | Code review, testing, documentation |
| security-agent | PC2 (remote Ollama) | Security analysis, vulnerability scanning |
| devops-agent | Laptop (remote Ollama) | Deployment, CI/CD, infrastructure |
| monitoring-agent | Laptop (remote Ollama) | Resource tracking, performance |

## Dispatching a Task

To assign a task to a team member, spawn a sub-agent session:
- Use `sessions_spawn` to create a new session for the target agent
- Include the task description, relevant context, and expected deliverables
- The sub-agent processes the task and returns results to this session

## Collecting Results

Sub-agent results are returned to the Coordinator's session automatically.
Use `sessions_history` to review previous task results if needed.

## Broadcasting

To notify all agents, spawn a session for each agent with the same message.

## Shell Execution on Remote Machines

To run commands on PC2 or Laptop (e.g., check disk space, run tests):
- Use `openclaw nodes run` to dispatch shell commands to connected Nodes
- Results are returned to the Coordinator's session
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
