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
| Coordinator | Any Agent | Yes | Task assignment and queries |
| Coordinator | Human | Yes | Via Telegram (results, escalation) |
| Any Agent | Coordinator | Yes | Results, status updates, questions |
| Agent | Agent (peer) | Yes | Via OpenClaw, for collaboration on tasks |
| Any Agent | Human | **No** | Must go through Coordinator |
| Any Agent | External | **No** | Only Coordinator contacts External Consultant |

### 6.1.2 Setting Up Communication Rules in OpenClaw

On PC1 (Coordinator), configure the routing rules:

```powershell
# Set the coordinator as the primary message router
openclaw config set routing.mode "coordinator-first"

# Allow peer-to-peer for approved collaborations
openclaw config set routing.allow_peer "true"

# All external communications must go through coordinator
openclaw config set routing.external_via_coordinator "true"

# Set message timeout (how long to wait for a response)
openclaw config set routing.timeout_seconds 300
```

---

## 6.2 Team Configuration File

Create a team configuration file that defines all roles and their relationships.

**File**: `C:\AI-Team\openclaw\config\team.yaml`

```yaml
# AI Team Configuration
# This file defines the team structure, roles, and communication rules

team:
  name: "AI Development Team"
  version: "1.0"

roles:
  coordinator:
    model: "coordinator"
    node: "pc1-coordinator"
    description: "Central command and human interface"
    capabilities:
      - task_decomposition
      - task_assignment
      - conflict_resolution
      - human_communication
      - external_consultation
    always_loaded: true
    telegram_access: true

  senior-engineer-1:
    model: "senior-engineer-1"
    node: "pc1-coordinator"
    description: "Architecture and complex problem solving"
    capabilities:
      - architecture_design
      - code_review
      - technical_specification
      - system_design
    fallback_node: "pc2-worker"      # Can run on PC2 if PC1 is overloaded
    fallback_model: "backup-engineer"

  senior-engineer-2:
    model: "senior-engineer-2"
    node: "pc1-coordinator"
    description: "Implementation and optimization"
    capabilities:
      - code_implementation
      - optimization
      - refactoring
      - debugging
      - unit_testing
    fallback_node: "pc2-worker"
    fallback_model: "backup-engineer"

  quality-agent:
    model: "quality-agent"
    node: "pc2-worker"
    description: "Code review, testing, documentation"
    capabilities:
      - code_review
      - test_creation
      - documentation
      - style_checking
      - best_practices

  security-agent:
    model: "security-agent"
    node: "pc2-worker"
    description: "Security analysis and best practices"
    capabilities:
      - vulnerability_scanning
      - security_review
      - dependency_audit
      - compliance_checking
      - threat_modeling

  devops-agent:
    model: "devops-agent"
    node: "laptop-monitor"
    description: "Deployment and infrastructure"
    capabilities:
      - deployment
      - ci_cd
      - infrastructure
      - git_workflow
      - containerization
    fallback_node: "pc2-worker"

  monitoring-agent:
    model: "monitoring-agent"
    node: "laptop-monitor"
    description: "Resource tracking and performance analysis"
    capabilities:
      - resource_monitoring
      - performance_analysis
      - alerting
      - health_reporting
    always_loaded: true

  external-consultant:
    type: "external"
    provider: "claude"
    description: "Complex problems requiring advanced reasoning"
    capabilities:
      - complex_reasoning
      - code_generation
      - architecture_review
      - second_opinion
    rate_limited: true
    max_requests_per_hour: 20       # Limit API costs

# Communication rules
communication:
  # All messages are logged for audit
  audit_logging: true
  log_path: "C:\\AI-Team\\logs\\communication.log"

  # Message format
  format:
    include_sender: true
    include_timestamp: true
    include_task_id: true

  # Escalation rules
  escalation:
    # Auto-escalate to human if...
    conditions:
      - type: "conflict_unresolved"
        timeout_minutes: 10
      - type: "task_stalled"
        timeout_minutes: 30
      - type: "security_violation"
        immediate: true
      - type: "resource_critical"
        immediate: true
      - type: "restricted_action_requested"
        immediate: true

# Task assignment rules
task_assignment:
  # Default task routing based on task type
  routing:
    architecture:
      primary: "senior-engineer-1"
      reviewer: "quality-agent"
    implementation:
      primary: "senior-engineer-2"
      reviewer: "quality-agent"
      security_check: "security-agent"
    bug_fix:
      primary: "senior-engineer-2"
      reviewer: "quality-agent"
    security_audit:
      primary: "security-agent"
      reviewer: "senior-engineer-1"
    deployment:
      primary: "devops-agent"
      reviewer: "security-agent"
    documentation:
      primary: "quality-agent"
    performance:
      primary: "monitoring-agent"
      consultant: "senior-engineer-1"
    complex_problem:
      primary: "external-consultant"
      reviewer: "senior-engineer-1"
```

### Apply the team configuration:

```powershell
openclaw team load --config "C:\AI-Team\openclaw\config\team.yaml"
```

### Verify:

```powershell
openclaw team status
```

---

## 6.3 Task Types and Routing

When the coordinator receives a task, it classifies it and routes it to the right agent(s). Here's the decision tree:

### 6.3.1 Task Classification

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
     │         → external-consultant (Claude.ai)
     │         → senior-engineer-1 (review answer)
     │
     └─── "Other"
              → coordinator handles directly
              → or asks human for clarification
```

### 6.3.2 Multi-Agent Workflows

Some tasks require multiple agents working in sequence:

**Example: "Build a REST API endpoint"**

```
Step 1: Coordinator receives task
Step 2: Senior Eng #1 → designs the endpoint (method, route, schema)
Step 3: Senior Eng #2 → implements the code based on the design
Step 4: Quality Agent → reviews the code for correctness
Step 5: Security Agent → checks for vulnerabilities
Step 6: DevOps Agent → prepares deployment configuration
Step 7: Coordinator → compiles results and reports to human
```

---

## 6.4 Agent Capability Permissions

Define what each agent is allowed to do through OpenClaw:

```powershell
# Coordinator - full access
openclaw permissions set coordinator --github read,write --files read,write --network outbound --telegram send,receive

# Senior Engineers - code access
openclaw permissions set senior-engineer-1 --github read,write --files read,write --network none
openclaw permissions set senior-engineer-2 --github read,write --files read,write --network none

# Quality Agent - read-heavy access
openclaw permissions set quality-agent --github read,write --files read,write --network none

# Security Agent - read + audit access
openclaw permissions set security-agent --github read --files read --network none --audit read

# DevOps Agent - deployment access
openclaw permissions set devops-agent --github read,write --files read,write --network outbound

# Monitoring Agent - read-only + metrics
openclaw permissions set monitoring-agent --github read --files read --network none --metrics read,write
```

---

## 6.5 Context Sharing Between Agents

When the coordinator assigns a task, it needs to pass context to the agent. OpenClaw handles this through **task contexts**:

```yaml
# Example task context sent from coordinator to an agent
task:
  id: "task-2024-001"
  type: "implementation"
  assigned_to: "senior-engineer-2"
  assigned_by: "coordinator"
  priority: "high"
  context:
    description: "Implement user authentication endpoint"
    requirements:
      - "Use JWT tokens"
      - "Support email/password login"
      - "Include rate limiting"
    related_files:
      - "src/auth/routes.py"
      - "src/models/user.py"
    architecture_notes: "See design from senior-engineer-1 in task-2024-000"
    repository: "github.com/team/project"
    branch: "feature/auth-endpoint"
  constraints:
    deadline: "2024-03-15"
    review_required: true
    security_check_required: true
```

---

## 6.6 Warm-Up Sequence

After all machines are running, execute this warm-up sequence to preload critical models:

### Create the warm-up script:

**File**: `C:\AI-Team\scripts\warmup.ps1`

```powershell
# Warm-up script - run after system boot
Write-Host "=== AI Team Warm-Up Sequence ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Verify cluster is healthy
Write-Host "[1/4] Checking cluster health..." -ForegroundColor Yellow
openclaw cluster status
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Cluster is not healthy. Fix issues before continuing." -ForegroundColor Red
    exit 1
}

# Step 2: Warm up coordinator (always loaded)
Write-Host "[2/4] Warming up Coordinator..." -ForegroundColor Yellow
openclaw message send --to coordinator --content "System startup. Run self-check and confirm ready status." --wait
Write-Host "Coordinator: READY" -ForegroundColor Green

# Step 3: Warm up monitoring agent (always loaded)
Write-Host "[3/4] Warming up Monitoring Agent..." -ForegroundColor Yellow
openclaw message send --to monitoring-agent --content "System startup. Begin monitoring all nodes." --wait
Write-Host "Monitoring Agent: READY" -ForegroundColor Green

# Step 4: Quick check on other agents (don't load them, just verify they're available)
Write-Host "[4/4] Verifying agent availability..." -ForegroundColor Yellow
$agents = @("senior-engineer-1", "senior-engineer-2", "quality-agent", "security-agent", "devops-agent")
foreach ($agent in $agents) {
    $status = openclaw model status $agent 2>&1
    if ($status -match "READY") {
        Write-Host "  $agent : AVAILABLE" -ForegroundColor Green
    } else {
        Write-Host "  $agent : NOT AVAILABLE" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Warm-Up Complete ===" -ForegroundColor Cyan
Write-Host "Send tasks via Telegram to begin working."
```

### Run it:

```powershell
powershell -ExecutionPolicy Bypass -File C:\AI-Team\scripts\warmup.ps1
```

---

## 6.7 Checklist

- [ ] Team configuration file (`team.yaml`) created and loaded
- [ ] Communication rules configured (coordinator-first routing)
- [ ] Permissions set for all agents
- [ ] Warm-up script created and tested
- [ ] All agents respond to ready-check messages
- [ ] Coordinator correctly routes test tasks to appropriate agents
- [ ] Escalation rules configured for human notification

---

Next: [Chapter 07 - Telegram Bot Setup](07-telegram-bot-setup.md)
