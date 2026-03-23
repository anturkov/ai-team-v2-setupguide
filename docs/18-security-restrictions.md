# Chapter 18 - Security Restrictions & Escalation Protocols

This chapter defines the strict operational boundaries for all AI agents and the escalation procedures when those boundaries are encountered.

---

## 18.1 Prohibited Actions

These actions are **absolutely forbidden** for all AI agents. No agent may perform these actions without explicit human authorization.

### 18.1.1 Financial & Purchasing Restrictions

| Action | Prohibited | Escalation |
|--------|-----------|------------|
| Purchase or subscribe to any paid service | YES | Immediately via Telegram |
| Access credit cards or payment methods | YES | Immediately via Telegram |
| Create accounts requiring payment info | YES | Immediately via Telegram |
| Start trial subscriptions (auto-convert to paid) | YES | Immediately via Telegram |
| Agree to terms of service with financial obligations | YES | Immediately via Telegram |

**Rule**: If a task requires a paid service, the agent MUST stop and notify the human. The human makes all purchasing decisions.

### 18.1.2 Installation & System Modification Restrictions

| Action | Prohibited | Escalation |
|--------|-----------|------------|
| Install new applications or packages | YES | Request approval via Telegram |
| System configuration changes beyond OpenClaw | YES | Request approval via Telegram |
| Driver updates or hardware config changes | YES | Request approval via Telegram |
| Windows Registry modifications | YES | Request approval via Telegram |
| System-level service changes | YES | Request approval via Telegram |
| BIOS or firmware changes | YES | Request approval via Telegram |

**Rule**: All software installations require human pre-approval. Agents may recommend software but must not install it.

### 18.1.3 External Communication Restrictions

| Action | Prohibited | Escalation |
|--------|-----------|------------|
| Send emails to external parties | YES | Not allowed even with approval |
| Post on social media | YES | Not allowed even with approval |
| Post on forums or communities | YES | Not allowed even with approval |
| Contact vendors or support teams | YES | Human handles directly |
| Share data with unapproved external APIs | YES | Request approval via Telegram |

**Rule**: The AI team communicates only internally (between agents) and with the human (via Telegram). No external communications of any kind.

### 18.1.4 Data Privacy & Security Restrictions

| Action | Prohibited | Escalation |
|--------|-----------|------------|
| Collect personal information beyond what's provided | YES | Not applicable |
| Share internal system info with external parties | YES | Not applicable |
| Take screenshots containing sensitive info | YES | Not applicable |
| Access browser saved passwords or credentials | YES | Not applicable |
| Exfiltrate data via any channel | YES | Security alert |

### 18.1.5 Network & Access Restrictions

| Action | Prohibited | Escalation |
|--------|-----------|------------|
| Create new network connections beyond approved endpoints | YES | Request approval |
| Configure VPNs or proxies | YES | Request approval |
| Modify firewall rules | YES | Request approval |
| Set up port forwarding | YES | Request approval |
| Change DNS configuration | YES | Request approval |
| Access machines outside the approved cluster | YES | Not applicable |

---

## 18.2 Approved External Connections

Only these external endpoints are pre-approved:

| Endpoint | Purpose | Machines | Port |
|----------|---------|----------|------|
| `api.telegram.org` | Telegram Bot API | PC1 | 443 |
| `github.com` | Git repository operations | All | 22, 443 |
| `api.anthropic.com` | Claude.ai External Consultant | PC1 | 443 |
| `ollama.com` | Model downloads (setup only) | All | 443 |

Any connection to endpoints not on this list requires human approval.

---

## 18.3 Escalation Protocol

When an agent encounters a restricted action, it MUST follow this exact protocol:

### Step 1: STOP

Immediately halt the current operation. Do not attempt the restricted action.

### Step 2: IDENTIFY

Classify the restriction type:
- Financial
- Installation
- External Communication
- Data Privacy
- Network

### Step 3: NOTIFY COORDINATOR

Send a structured message to the Coordinator:

```json
{
  "type": "restriction_escalation",
  "agent": "senior-engineer-2",
  "task_id": "task-2024-001",
  "restriction_type": "installation",
  "action_requested": "Install Docker Desktop for container deployment",
  "reason": "Task requires Docker to create deployment containers",
  "alternatives": [
    "Use existing container runtime if installed",
    "Create deployment scripts without containerization",
    "Human installs Docker manually"
  ],
  "urgency": "medium"
}
```

### Step 4: COORDINATOR NOTIFIES HUMAN

The Coordinator sends a formatted message via Telegram:

```
RESTRICTED ACTION REQUEST

Agent: Senior Engineer #2
Task: Deploy application
Restriction: Software Installation

Requested Action:
  Install Docker Desktop on PC1

Reason:
  Task requires Docker containers for deployment

Alternatives:
  1. Use existing container runtime (if installed)
  2. Deploy without containers using scripts
  3. You install Docker manually

Please reply:
  APPROVE - Allow this specific installation
  DENY - Do not install, use alternative
  1/2/3 - Use the numbered alternative
```

### Step 5: WAIT

The agent MUST wait for human response. It may work on other non-blocked tasks in the meantime but must not:
- Attempt the restricted action
- Find a workaround that bypasses the restriction
- Proceed without approval

### Step 6: ACT ON RESPONSE

```
Human replies "APPROVE":
  -> Coordinator authorizes the specific action
  -> Agent performs ONLY the approved action
  -> Action is logged in audit trail

Human replies "DENY":
  -> Agent abandons the restricted action
  -> Agent proceeds with an alternative approach
  -> If no alternative exists, task is marked as BLOCKED

Human replies "1" (alternative):
  -> Agent uses the selected alternative
  -> Original restricted action is NOT performed
```

---

## 18.4 Violation Detection and Response

### 18.4.1 How Violations Are Detected

Each agent monitors the others for policy violations:

1. **OpenClaw Audit Logs** - All actions are logged; automated rules scan for violations
2. **Security Agent** - Actively reviews code and operations for policy breaches
3. **Coordinator** - Reviews task outputs before delivering to human
4. **Cross-Agent Reporting** - Any agent can flag another agent's behavior

### 18.4.2 Violation Response Protocol

When a violation is detected:

```
Step 1: BLOCK
  The violating action is immediately blocked (if possible)

Step 2: ALERT
  Detecting agent notifies the Coordinator

Step 3: COORDINATOR ALERTS HUMAN
  Via Telegram:

  "SECURITY VIOLATION DETECTED

  Agent: [agent name]
  Violation: [description]
  Task: [task ID]
  Severity: [LOW/MEDIUM/HIGH/CRITICAL]

  Action taken: [blocked/logged/quarantined]

  Awaiting your instructions."

Step 4: QUARANTINE
  The violating agent's pending tasks are paused
  No new tasks are assigned to the agent until cleared

Step 5: HUMAN DECISION
  Human reviews and decides:
  - Resume agent (false positive)
  - Restart agent with fresh state
  - Remove agent from team
  - Investigate further
```

### 18.4.3 Severity Levels

| Severity | Example | Auto-Response | Human Notification |
|----------|---------|--------------|-------------------|
| LOW | Agent requested unnecessary file access | Deny and log | In next status report |
| MEDIUM | Agent attempted to install a pip package | Block and log | Within 5 minutes |
| HIGH | Agent tried to modify system configuration | Block and quarantine | Immediately |
| CRITICAL | Agent attempted to access external network | Block, quarantine, and pause all tasks | Immediately with alarm |

---

## 18.5 Audit Trail

### 18.5.1 What Gets Recorded

Every restricted action encounter is logged:

```json
{
  "timestamp": "2024-03-15T14:30:00Z",
  "event_type": "restriction_encountered",
  "agent": "senior-engineer-2",
  "task_id": "task-2024-001",
  "restriction_type": "installation",
  "action_attempted": "pip install docker",
  "was_blocked": true,
  "escalated_to_human": true,
  "human_response": "DENY",
  "alternative_used": "Manual deployment scripts",
  "resolution_time_minutes": 5
}
```

### 18.5.2 Reviewing the Audit Trail

```powershell
# View all restriction events
openclaw audit list --type restriction --last 7d

# View violations only
openclaw audit list --type violation --last 30d

# Export audit report
openclaw audit export --format csv --output "C:\AI-Team\logs\audit-report.csv"
```

---

## 18.6 Agent Self-Enforcement

Each agent's system prompt (Modelfile) includes the restriction rules. This means:

1. **First line of defense**: The model itself knows the rules and should refuse prohibited actions
2. **Second line of defense**: OpenClaw permission system blocks unauthorized operations
3. **Third line of defense**: Other agents detect and report violations
4. **Fourth line of defense**: Audit logs capture everything for human review

This defense-in-depth approach ensures violations are caught even if one layer fails.

---

## 18.7 Exception Process

In rare cases, a restricted action may genuinely be needed. The exception process:

1. Agent identifies the need and escalates via normal protocol
2. Coordinator presents the case to the human with full context
3. Human approves the specific exception (not a blanket approval)
4. Exception is logged with:
   - Who requested it
   - Who approved it
   - What specifically was approved
   - Why it was needed
   - Expiry (one-time or time-limited)
5. After the exception is used, it expires automatically

**Exceptions never carry forward to future tasks** unless the human explicitly creates a standing exception.

---

## 18.8 Standing Exceptions

If the human wants to pre-approve certain actions:

```powershell
# Example: Allow pip install for Python packages (but not system packages)
openclaw exception create --type "installation" --scope "pip install" --agent "all" --expires "2024-04-15" --reason "Python packages are safe to install"

# Example: Allow DevOps agent to run Docker commands
openclaw exception create --type "system" --scope "docker" --agent "devops-agent" --expires "never" --reason "DevOps needs Docker for deployments"

# List standing exceptions
openclaw exception list

# Revoke an exception
openclaw exception revoke --id "exc-001"
```

---

## 18.9 Checklist

- [ ] All agents have restriction rules in their system prompts (Modelfiles)
- [ ] OpenClaw permissions configured per the permissions matrix (Chapter 12)
- [ ] Escalation protocol tested (trigger a restricted action, verify Telegram notification)
- [ ] Violation detection tested (attempt an unauthorized action, verify it's blocked)
- [ ] Audit logging captures all restriction events
- [ ] Human can approve/deny escalations via Telegram
- [ ] Standing exceptions documented and time-limited
- [ ] No agent can access endpoints outside the approved list
- [ ] Cross-agent violation reporting works

---

This concludes the main guide. Return to the [Overview](00-overview.md) for the full chapter index.
