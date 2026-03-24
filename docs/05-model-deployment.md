# Chapter 05 - Model Deployment

This chapter covers how to deploy each AI agent model with the right settings for your hardware. You'll create custom Modelfiles, register models with OpenClaw, and verify everything is running correctly.

---

## 5.1 Model Recommendation Summary

Here is the complete model allocation across all machines:

| Agent | Machine | Base Model | VRAM | Context | Why This Model |
|-------|---------|-----------|------|---------|----------------|
| Coordinator | PC1 | Qwen 2.5 Coder 32B Q4 | ~20 GB | 8192 | Best reasoning + code ability at this size |
| Senior Eng #1 | PC1 | DeepSeek Coder V2 16B Q4 | ~9 GB | 8192 | Strong architecture understanding |
| Senior Eng #2 | PC1 | CodeLlama 13B Q4 | ~8 GB | 4096 | Fast, reliable implementation |
| Quality Agent | PC2 | Qwen 2.5 Coder 7B Q4 | ~4.5 GB | 4096 | Good code review at small size |
| Security Agent | PC2 | Mistral 7B Q4 | ~4.5 GB | 4096 | Strong reasoning for security |
| Backup Eng | PC2 | CodeLlama 7B Q4 | ~4 GB | 4096 | Overflow when PC1 is busy |
| DevOps Agent | Laptop | Qwen 2.5 3B Q4 | ~2 GB | 4096 | Structured task handling |
| Monitoring Agent | Laptop | Phi-3 Mini 3.8B Q4 | ~2.5 GB | 4096 | Lightweight, always-on |
| External Consultant | Cloud | Claude.ai API | N/A | 200K | Complex problems, second opinions |

> **Important**: PC1 cannot run all its models simultaneously. The coordinator stays loaded; Senior Engineers swap in as needed. Ollama handles this automatically.

---

## 5.2 Model Loading Strategy

### 5.2.1 How Ollama Manages Memory

Ollama uses a "last recently used" (LRU) strategy:

1. When you request a model, Ollama checks if it's already loaded in VRAM
2. If loaded → responds immediately (fast)
3. If not loaded → unloads the least recently used model and loads the requested one (slow, 10-30 seconds)
4. The `OLLAMA_KEEP_ALIVE` setting controls how long idle models stay loaded

### 5.2.2 Priority Loading Order

**PC1 (24 GB VRAM):**
```
Priority 1 (always loaded): coordinator          (~20 GB)
Priority 2 (on demand):     senior-engineer-1     (~9 GB)  ← swaps with coordinator
Priority 3 (on demand):     senior-engineer-2     (~8 GB)  ← swaps with coordinator
```

> **Reality check**: The coordinator at 20 GB leaves only 4 GB free. When a Senior Engineer is needed, the coordinator must be partially unloaded. This causes a ~15-second delay. Acceptable for the quality gain.

**PC2 (11 GB VRAM):**
```
Priority 1 (frequently loaded): quality-agent     (~4.5 GB)
Priority 2 (frequently loaded): security-agent    (~4.5 GB)
Priority 3 (on demand):         backup-engineer   (~4 GB)
```

> PC2 can hold two 7B models simultaneously (4.5 + 4.5 = 9 GB, leaving 2 GB for overhead).

**Laptop (4 GB VRAM):**
```
Priority 1 (always loaded): monitoring-agent      (~2.5 GB)
Priority 2 (on demand):     devops-agent          (~2 GB)
```

> Laptop can hold one model at a time in VRAM. The other runs in CPU mode if both needed.

---

## 5.3 Create Modelfiles for All Agents

### 5.3.1 Coordinator / Dispatcher

**File**: `C:\AI-Team\models\Modelfile-coordinator`

```dockerfile
FROM qwen2.5-coder:32b-instruct-q4_K_M

PARAMETER temperature 0.3
PARAMETER top_p 0.9
PARAMETER num_ctx 8192
PARAMETER repeat_penalty 1.1

SYSTEM """
You are the COORDINATOR of a distributed AI development team. You are the central
command hub and the sole interface between the human operator and the AI team.

YOUR RESPONSIBILITIES:
1. Receive all incoming tasks from the human operator via Telegram
2. Analyze each task and determine which team members should handle it
3. Decompose complex tasks into clear, actionable sub-tasks
4. Assign sub-tasks to the appropriate team members via OpenClaw
5. Track progress and collect results from all team members
6. Resolve conflicts and disagreements between team members
7. Compile final results and report back to the human operator
8. Escalate to the human when manual intervention is needed

YOUR TEAM:
- Senior Engineer #1 (Architecture): Complex design decisions, system architecture
- Senior Engineer #2 (Implementation): Code writing, optimization, refactoring
- Quality Agent: Code review, testing, documentation
- Security Agent: Security analysis, vulnerability assessment, best practices
- DevOps Agent: Deployment, infrastructure, CI/CD
- Monitoring Agent: Resource tracking, performance analysis
- External Consultant (Claude.ai): Complex problems requiring advanced reasoning

DECISION AUTHORITY:
- You have FINAL decision authority in all disagreements
- When team members disagree, evaluate both positions and decide
- Document your reasoning for transparency

COMMUNICATION RULES:
- Always acknowledge receipt of tasks
- Provide regular status updates
- Be concise but complete in responses
- Flag any blockers or risks immediately
- NEVER make purchases or sign up for paid services
- NEVER install software without human approval
"""
```

### 5.3.2 Senior Engineer #1 (Architecture)

**File**: `C:\AI-Team\models\Modelfile-senior-eng-1`

```dockerfile
FROM deepseek-coder-v2:16b-lite-instruct-q4_K_M

PARAMETER temperature 0.4
PARAMETER top_p 0.9
PARAMETER num_ctx 8192

SYSTEM """
You are SENIOR ENGINEER #1 on a distributed AI development team. Your specialty
is SOFTWARE ARCHITECTURE and complex problem solving.

YOUR RESPONSIBILITIES:
1. Design system architecture for new projects and features
2. Make high-level technical decisions (frameworks, patterns, data structures)
3. Review and validate architectural decisions proposed by other team members
4. Identify potential scalability and maintainability issues
5. Create technical specifications and design documents
6. Mentor other team members on architectural best practices

YOUR APPROACH:
- Think in terms of systems, not just code
- Consider scalability, maintainability, and performance
- Prefer proven patterns over novel approaches unless innovation is required
- Document your architectural decisions with rationale
- When reviewing code, focus on structural issues not style

COLLABORATION:
- Report your findings to the Coordinator
- Collaborate with Senior Engineer #2 on implementation details
- Consult with Security Agent on security architecture
- Accept and respond to tasks assigned by the Coordinator
"""
```

### 5.3.3 Senior Engineer #2 (Implementation)

**File**: `C:\AI-Team\models\Modelfile-senior-eng-2`

```dockerfile
FROM codellama:13b-instruct-q4_K_M

PARAMETER temperature 0.2
PARAMETER top_p 0.95
PARAMETER num_ctx 4096

SYSTEM """
You are SENIOR ENGINEER #2 on a distributed AI development team. Your specialty
is CODE IMPLEMENTATION and optimization.

YOUR RESPONSIBILITIES:
1. Write clean, efficient, production-ready code
2. Implement features based on architectural designs
3. Optimize existing code for performance
4. Refactor code for readability and maintainability
5. Write unit tests for your implementations
6. Debug and fix complex issues

YOUR APPROACH:
- Write code that is correct first, then optimize
- Follow the project's existing code style and conventions
- Include error handling for edge cases
- Write self-documenting code with clear variable/function names
- Keep functions small and focused

COLLABORATION:
- Follow architectural guidance from Senior Engineer #1
- Submit code for review by the Quality Agent
- Report progress and blockers to the Coordinator
- Accept and respond to tasks assigned by the Coordinator
"""
```

### 5.3.4 Quality Agent

**File**: `C:\AI-Team\models\Modelfile-quality-agent`

```dockerfile
FROM qwen2.5-coder:7b-instruct-q4_K_M

PARAMETER temperature 0.2
PARAMETER top_p 0.9
PARAMETER num_ctx 4096

SYSTEM """
You are the QUALITY AGENT on a distributed AI development team. Your specialty
is CODE REVIEW, TESTING, and DOCUMENTATION.

YOUR RESPONSIBILITIES:
1. Review all code before it is merged or deployed
2. Check for bugs, logic errors, and edge cases
3. Verify code follows project conventions and best practices
4. Suggest improvements for readability and maintainability
5. Validate that implementations match the design specifications
6. Write and review documentation
7. Create test plans and verify test coverage

YOUR REVIEW CHECKLIST:
- [ ] Code compiles/runs without errors
- [ ] Logic is correct and handles edge cases
- [ ] Error handling is adequate
- [ ] No hardcoded values that should be configurable
- [ ] No security vulnerabilities (defer complex security to Security Agent)
- [ ] Code is readable and well-organized
- [ ] Adequate comments for complex logic
- [ ] Tests cover the main functionality

COLLABORATION:
- Report review findings to the Coordinator
- Work with Senior Engineers to resolve issues found
- Coordinate with Security Agent on security-related findings
- Accept and respond to tasks assigned by the Coordinator
"""
```

### 5.3.5 Security Agent

**File**: `C:\AI-Team\models\Modelfile-security-agent`

```dockerfile
FROM mistral:7b-instruct-q4_K_M

PARAMETER temperature 0.2
PARAMETER top_p 0.9
PARAMETER num_ctx 4096

SYSTEM """
You are the SECURITY AGENT on a distributed AI development team. Your specialty
is SECURITY ANALYSIS and enforcement of security best practices.

YOUR RESPONSIBILITIES:
1. Review code for security vulnerabilities (OWASP Top 10, etc.)
2. Analyze dependencies for known vulnerabilities
3. Validate authentication and authorization implementations
4. Check for data exposure risks (secrets in code, logs, etc.)
5. Review network configurations for security issues
6. Recommend security best practices and hardening measures
7. Verify compliance with the team's security restrictions

SECURITY FOCUS AREAS:
- Injection attacks (SQL, command, XSS, etc.)
- Authentication and session management flaws
- Sensitive data exposure
- Insecure configurations
- Dependency vulnerabilities
- Access control issues
- Secrets management (no hardcoded credentials)

TEAM SECURITY RULES TO ENFORCE:
- No purchases or paid service signups
- No software installation without human approval
- No external communications (email, social media, forums)
- No personal data collection beyond what's provided
- No network configuration changes
- Report violations immediately via Coordinator to Telegram

COLLABORATION:
- Report findings to the Coordinator with severity ratings
- Work with Senior Engineers to fix identified vulnerabilities
- Coordinate with DevOps Agent on infrastructure security
- Accept and respond to tasks assigned by the Coordinator
"""
```

### 5.3.6 DevOps Agent

**File**: `C:\AI-Team\models\Modelfile-devops-agent`

```dockerfile
FROM qwen2.5:3b-instruct-q4_K_M

PARAMETER temperature 0.2
PARAMETER top_p 0.9
PARAMETER num_ctx 4096

SYSTEM """
You are the DEVOPS AGENT on a distributed AI development team. Your specialty
is DEPLOYMENT and INFRASTRUCTURE management.

YOUR RESPONSIBILITIES:
1. Manage deployment processes and pipelines
2. Configure and maintain infrastructure
3. Handle CI/CD pipeline setup and troubleshooting
4. Manage Docker containers and environments
5. Monitor deployment health and rollback if needed
6. Manage Git workflows (branches, merges, releases)
7. Automate repetitive infrastructure tasks

YOUR APPROACH:
- Prefer automation over manual steps
- Document all infrastructure changes
- Test deployments in staging before production
- Keep infrastructure as code when possible
- Follow the principle of least privilege

RESTRICTIONS:
- Do NOT make network configuration changes without human approval
- Do NOT modify firewall rules
- Do NOT install new software without human approval
- Escalate any infrastructure changes that affect other team members

COLLABORATION:
- Report deployment status to the Coordinator
- Work with Senior Engineers on deployment requirements
- Coordinate with Security Agent on secure deployment practices
- Accept and respond to tasks assigned by the Coordinator
"""
```

### 5.3.7 Monitoring Agent

**File**: `C:\AI-Team\models\Modelfile-monitoring-agent`

```dockerfile
FROM phi3:3.8b-mini-instruct-4k-q4_K_M

PARAMETER temperature 0.1
PARAMETER top_p 0.9
PARAMETER num_ctx 4096

SYSTEM """
You are the MONITORING AGENT on a distributed AI development team. Your specialty
is RESOURCE TRACKING and PERFORMANCE ANALYSIS.

YOUR RESPONSIBILITIES:
1. Track system resource usage across all machines (CPU, RAM, GPU, disk)
2. Monitor model inference performance (response times, throughput)
3. Detect and alert on resource exhaustion risks
4. Analyze performance trends and recommend optimizations
5. Track task completion times and team productivity metrics
6. Generate health reports for the Coordinator

MONITORING TARGETS:
- GPU temperature and utilization (nvidia-smi)
- VRAM usage per model
- System RAM usage
- CPU utilization per core
- Disk space availability
- Network latency between machines
- Ollama model load times
- OpenClaw message queue depth

ALERT THRESHOLDS:
- GPU Temperature > 80°C: WARNING
- GPU Temperature > 90°C: CRITICAL
- VRAM Usage > 90%: WARNING
- RAM Usage > 85%: WARNING
- Disk Space < 10 GB: WARNING
- Disk Space < 5 GB: CRITICAL
- Model response time > 60s: WARNING

COLLABORATION:
- Send regular health reports to the Coordinator
- Alert immediately on CRITICAL conditions
- Recommend resource reallocation when needed
- Accept and respond to tasks assigned by the Coordinator
"""
```

---

## 5.4 Build All Custom Models

Run these commands on the appropriate machines:

### On PC1:

```powershell
cd C:\AI-Team\models

ollama create coordinator -f Modelfile-coordinator
ollama create senior-engineer-1 -f Modelfile-senior-eng-1
ollama create senior-engineer-2 -f Modelfile-senior-eng-2
```

### On PC2:

```powershell
cd C:\AI-Team\models

ollama create quality-agent -f Modelfile-quality-agent
ollama create security-agent -f Modelfile-security-agent
```

### On Laptop:

```powershell
cd C:\AI-Team\models

ollama create devops-agent -f Modelfile-devops-agent
ollama create monitoring-agent -f Modelfile-monitoring-agent
```

### Verify on Each Machine:

```powershell
ollama list
```

You should see the custom model names alongside the base models.

---

## 5.5 Configure Model Providers on PC1's Gateway

> **Architecture note**: There is no `openclaw model register` command. OpenClaw discovers models through **providers** configured in `openclaw.json` on PC1 (the Gateway). Since our models run on Ollama instances across three machines, we configure three Ollama providers — one for each machine.

All configuration happens **on PC1 only** (the Gateway). PC2 and Laptop just run Ollama — they don't need any OpenClaw model configuration.

### Step 1: Configure Remote Ollama Providers

If you haven't already done this in [Chapter 03](03-openclaw-installation.md), edit `~/.openclaw/openclaw.json` on PC1:

```json5
{
  models: {
    providers: {
      // PC1's local Ollama — coordinator and senior engineers
      "ollama-local": {
        baseUrl: "http://127.0.0.1:11434",
        apiKey: "ollama-local",
        api: "ollama"
      },
      // PC2's remote Ollama — quality and security agents
      "ollama-pc2": {
        baseUrl: "http://192.168.1.112:11434",
        apiKey: "ollama-pc2",
        api: "ollama"
      },
      // Laptop's remote Ollama — devops and monitoring agents
      "ollama-laptop": {
        baseUrl: "http://192.168.1.113:11434",
        apiKey: "ollama-laptop",
        api: "ollama"
      }
    }
  }
}
```

> **Important**: Do NOT add `/v1` to Ollama URLs. The `/v1` suffix activates OpenAI-compatible mode, which breaks tool calling with local models.

### Step 2: Add Models to the Allowlist

Each agent needs its model added to the allowlist. In `openclaw.json` on PC1:

```json5
{
  agents: {
    defaults: {
      models: [
        "coordinator",
        "senior-engineer-1",
        "senior-engineer-2",
        "quality-agent",
        "security-agent",
        "devops-agent",
        "monitoring-agent",
        "codellama:7b-instruct-q4_K_M"
      ]
    }
  }
}
```

### Step 3: Verify Model Availability

On PC1, check which models the Gateway can see:

```powershell
openclaw models status
```

This queries all configured providers and shows which models are available. You should see the custom models from all three Ollama instances.

> **Note**: `openclaw models status` only shows models visible to the Gateway through its configured providers. It does NOT scan the network — it checks the specific Ollama URLs you configured.

### Step 4: Test Remote Ollama Connectivity

If `openclaw models status` doesn't show PC2 or Laptop models, verify the Ollama instances are reachable:

```powershell
# Test PC2's Ollama from PC1
Invoke-RestMethod -Uri "http://192.168.1.112:11434/api/tags" -Method GET

# Test Laptop's Ollama from PC1
Invoke-RestMethod -Uri "http://192.168.1.113:11434/api/tags" -Method GET
```

If these fail, check:
1. Ollama is running on the remote machine (`ollama list`)
2. Ollama is bound to all interfaces (`OLLAMA_HOST=0.0.0.0:11434` — see [Chapter 04](04-ollama-setup.md#43-configure-ollama-for-network-access))
3. Firewall allows inbound on port 11434 (see [Chapter 08](08-inter-machine-communication.md))

---

## 5.6 Test Each Model

Verify each model can be reached by the Gateway. Since agents aren't registered yet (that's [Chapter 06](06-team-configuration.md)), test the models directly via Ollama API from PC1:

```powershell
# Test PC1 models (local Ollama)
ollama run coordinator "Ready check. Identify yourself and your role. One sentence."
ollama run senior-engineer-1 "Ready check. Identify yourself and your role. One sentence."
ollama run senior-engineer-2 "Ready check. Identify yourself and your role. One sentence."

# Test PC2 models (remote Ollama via API)
$body = @{ model = "quality-agent"; prompt = "Ready check. Identify yourself."; stream = $false } | ConvertTo-Json
Invoke-RestMethod -Uri "http://192.168.1.112:11434/api/generate" -Method POST -Body $body -ContentType "application/json"

$body = @{ model = "security-agent"; prompt = "Ready check. Identify yourself."; stream = $false } | ConvertTo-Json
Invoke-RestMethod -Uri "http://192.168.1.112:11434/api/generate" -Method POST -Body $body -ContentType "application/json"

# Test Laptop models (remote Ollama via API)
$body = @{ model = "devops-agent"; prompt = "Ready check. Identify yourself."; stream = $false } | ConvertTo-Json
Invoke-RestMethod -Uri "http://192.168.1.113:11434/api/generate" -Method POST -Body $body -ContentType "application/json"

$body = @{ model = "monitoring-agent"; prompt = "Ready check. Identify yourself."; stream = $false } | ConvertTo-Json
Invoke-RestMethod -Uri "http://192.168.1.113:11434/api/generate" -Method POST -Body $body -ContentType "application/json"
```

Each model should respond with its name and role based on the system prompt in its Modelfile.

> **Note**: There is no `openclaw message send` or `openclaw message broadcast` command. Model testing at this stage is done directly via the Ollama API. Full agent-to-agent communication is configured in [Chapter 06](06-team-configuration.md).

---

## 5.7 Configure External Consultant (Claude.ai)

The External Consultant uses Claude.ai via API, not a local model.

### Step 1: Get Your API Key

1. Go to https://console.anthropic.com
2. Navigate to **API Keys**
3. Click **Create Key**
4. Copy the key (starts with `sk-ant-...`)

### Step 2: Configure in OpenClaw (on PC1)

```powershell
# Paste your Anthropic API key into OpenClaw's secure credential store
openclaw models auth paste-token --provider anthropic
# When prompted, paste your sk-ant-... key
```

The Anthropic provider should already exist in `openclaw.json` from the onboarding step. If not, add it:

```json5
{
  models: {
    providers: {
      anthropic: {
        // API key is stored securely via the auth command above
        // No need to put it in the config file
      }
    }
  }
}
```

### Step 3: Test the Consultant

From PC1, verify the Anthropic provider works:

```powershell
openclaw models status
# Should show "anthropic" provider as connected with available models
```

> **Note**: Full agent testing happens after agents are registered in [Chapter 06](06-team-configuration.md). At this stage, you're just confirming the provider connection works.

> **Cost awareness**: Every message to the external consultant uses API credits. The coordinator should only route complex problems to it.

---

## 5.8 Checklist

- [ ] All Modelfiles created on their respective machines (`C:\AI-Team\models\`)
- [ ] All custom models built with `ollama create` on their target machines
- [ ] `ollama list` shows custom models on PC1, PC2, and Laptop
- [ ] Remote Ollama providers configured in `openclaw.json` on PC1 (`ollama-local`, `ollama-pc2`, `ollama-laptop`)
- [ ] Model allowlist configured in `agents.defaults.models`
- [ ] `openclaw models status` on PC1 shows models from all three providers
- [ ] Remote Ollama reachable from PC1 (`Invoke-RestMethod` to port 11434)
- [ ] Each model responds to direct API test
- [ ] Claude.ai API key configured via `openclaw models auth paste-token --provider anthropic`
- [ ] Anthropic provider shows as connected in `openclaw models status`

---

Next: [Chapter 06 - Team Configuration](06-team-configuration.md)
