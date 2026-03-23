# Chapter 13 - Conflict Resolution

This chapter covers how the AI team handles disagreements between agents, the coordinator's decision-making process, and when to escalate to human oversight.

---

## 13.1 Types of Conflicts

| Conflict Type | Example | Frequency |
|--------------|---------|-----------|
| **Technical Disagreement** | Eng #1 prefers REST, Eng #2 prefers GraphQL | Common |
| **Quality vs Speed** | Quality Agent wants more tests, Coordinator wants fast delivery | Common |
| **Security vs Functionality** | Security Agent flags a feature as risky, Engineer disagrees | Occasional |
| **Resource Contention** | Two tasks competing for the same GPU/model | Occasional |
| **Scope Disagreement** | Agent interprets the task differently than intended | Rare |

---

## 13.2 Resolution Protocol

### 13.2.1 Automatic Resolution (No Human Needed)

For most conflicts, the coordinator resolves automatically:

```
Step 1: DETECT
  Coordinator notices conflicting opinions from agents

Step 2: GATHER
  Coordinator asks both sides to explain their reasoning

Step 3: EVALUATE
  Coordinator weighs the arguments based on:
  - Task requirements (what did the human ask for?)
  - Best practices (what does the industry recommend?)
  - Pragmatism (what's the simplest correct solution?)
  - Risk (what has less downside?)

Step 4: DECIDE
  Coordinator makes a final decision

Step 5: COMMUNICATE
  Coordinator informs both agents of the decision and reasoning

Step 6: LOG
  Decision is logged for audit trail
```

### 13.2.2 Example: Technical Disagreement

```
Coordinator receives: "Build an API for the mobile app"

Senior Engineer #1 says:
  "Use GraphQL - it's more flexible for mobile clients,
   reduces over-fetching, and allows the frontend to
   request exactly what it needs."

Senior Engineer #2 says:
  "Use REST - it's simpler, better understood,
   easier to cache, and our team has more experience with it."

Coordinator's Evaluation:
  - Task scope: Mobile app backend (moderate complexity)
  - Team experience: REST (based on existing codebase patterns)
  - Timeline: Not mentioned -> default to simpler approach
  - Flexibility: GraphQL advantage exists but adds complexity

Coordinator's Decision:
  "Use REST for this API. Reasoning:
   1. The team's existing code uses REST patterns
   2. REST is simpler to implement and test
   3. The mobile app's needs don't require GraphQL's flexibility
   4. We can migrate to GraphQL later if needed

   Senior Engineer #2 will implement the REST API.
   Senior Engineer #1, please review the endpoint design for completeness."
```

### 13.2.3 Consensus Building

Before making a unilateral decision, the coordinator attempts consensus:

```
Coordinator to Both Agents:
  "I see you disagree on the API approach. Before I decide:
   - Eng #1: Can you identify any risks with REST for this use case?
   - Eng #2: Can you identify any benefits of GraphQL that REST can't provide here?

   If there are no strong technical blockers either way,
   I'll go with the simpler approach (REST) by default."
```

If both agents agree there are no strong blockers, the decision is easier.

---

## 13.3 Escalation to Human

### 13.3.1 When to Escalate

The coordinator escalates to human (via Telegram) when:

1. **High-stakes disagreement**: The technical decision has significant cost or risk implications
2. **Ambiguous requirements**: The original task description doesn't provide enough guidance
3. **Security concern**: The security agent flags something the engineers disagree with
4. **Policy violation**: An agent requests a prohibited action
5. **Repeated failures**: A task has failed 3+ times
6. **Resource deadlock**: Two critical tasks need the same resource
7. **Timeout**: A conflict isn't resolved within 10 minutes

### 13.3.2 Escalation Message Format

```
ESCALATION: Technical Decision Required

Task: Build API for mobile app
Conflict: REST vs GraphQL architecture

Position A (Senior Engineer #1):
  GraphQL - More flexible for mobile, reduces over-fetching

Position B (Senior Engineer #2):
  REST - Simpler, better caching, team has more experience

My recommendation: REST (simpler, matches existing patterns)

Please reply with:
  A - Go with GraphQL
  B - Go with REST (my recommendation)
  C - Need more information
```

### 13.3.3 Human Response Handling

```
Human replies: "B"
  -> Coordinator proceeds with REST
  -> Logs: "Decision: REST. Decided by: human. Reason: human override."

Human replies: "C"
  -> Coordinator asks: "What additional information do you need?"
  -> Waits for clarification before proceeding
```

---

## 13.4 Resource Contention

When multiple tasks compete for the same hardware:

### 13.4.1 Priority-Based Resolution

```
Task A (HIGH priority): "Fix critical production bug"
  Needs: Senior Engineer #2 on PC1

Task B (MEDIUM priority): "Add dark mode to settings page"
  Needs: Senior Engineer #2 on PC1

Resolution:
  1. Task A gets Senior Engineer #2 (higher priority)
  2. Task B is queued or reassigned to backup-engineer on PC2
  3. Human is notified: "Task B delayed due to higher priority Task A"
```

### 13.4.2 VRAM Contention

When two models both need GPU memory:

```
Available: 24 GB VRAM on PC1
Coordinator needs: 20 GB (always loaded)
Senior Eng #1 needs: 9 GB (requested)

Resolution:
  1. Coordinator partially offloads to CPU (frees ~10 GB VRAM)
  2. Senior Eng #1 loads in the freed VRAM
  3. Coordinator performance temporarily reduced
  4. After Senior Eng #1 finishes, coordinator reloads fully to GPU
```

---

## 13.5 Security vs Functionality Conflicts

The security agent has special authority to block changes:

```
Scenario: Senior Eng #2 commits code with eval() in a web endpoint

Security Agent: "BLOCKED - eval() in web endpoint is a critical security
                vulnerability (arbitrary code execution). This must be
                refactored to use safe alternatives."

Senior Eng #2: "But eval() is the simplest way to parse the dynamic
                expression the user provides."

Coordinator Decision:
  "Security Agent's concern is valid - eval() in a web endpoint is
   a well-known critical vulnerability. Senior Eng #2, please use
   a safe expression parser library instead. The Security Agent will
   re-review after the change."
```

**Rule**: Security concerns ALWAYS take priority over convenience unless the human explicitly overrides.

---

## 13.6 Decision Audit Trail

All conflict resolutions are logged:

```json
{
  "conflict_id": "conflict-2024-003",
  "timestamp": "2024-03-15T14:30:00Z",
  "task_id": "task-2024-001",
  "type": "technical_disagreement",
  "parties": ["senior-engineer-1", "senior-engineer-2"],
  "topic": "API architecture: REST vs GraphQL",
  "positions": {
    "senior-engineer-1": "GraphQL for mobile flexibility",
    "senior-engineer-2": "REST for simplicity and team experience"
  },
  "decision": "REST",
  "decided_by": "coordinator",
  "reasoning": "Simpler approach matches existing patterns; GraphQL benefits not critical for this use case",
  "escalated_to_human": false,
  "resolution_time_seconds": 45
}
```

View the audit trail:

```powershell
# View recent conflict resolutions
openclaw conflicts list --last 7d

# View details of a specific conflict
openclaw conflicts show --id "conflict-2024-003"
```

---

## 13.7 Conflict Prevention

### 13.7.1 Clear Task Descriptions

The best way to prevent conflicts is clear, unambiguous task descriptions:

**Bad**: "Build an API"
**Good**: "Build a REST API with CRUD endpoints for managing todo items. Use Express.js, PostgreSQL, and JWT authentication."

### 13.7.2 Pre-Task Architecture Review

For complex tasks, have Senior Engineer #1 create an architecture spec before implementation begins. This prevents disagreements during implementation.

### 13.7.3 Established Conventions

Document your project conventions so agents don't argue about style:

```yaml
# Project conventions (stored in repo as .ai-conventions.yaml)
conventions:
  api_style: "REST"
  language: "Python 3.11+"
  framework: "FastAPI"
  database: "PostgreSQL"
  orm: "SQLAlchemy"
  testing: "pytest"
  code_style: "black + ruff"
  naming: "snake_case for Python, camelCase for JavaScript"
```

---

## 13.8 Checklist

- [ ] Coordinator can detect conflicting opinions from agents
- [ ] Automatic resolution works for simple disagreements
- [ ] Escalation to Telegram works when needed
- [ ] Human can respond to escalation messages and coordinator acts on the response
- [ ] Resource contention is handled by priority
- [ ] Security concerns take precedence over convenience
- [ ] All conflict resolutions are logged with audit trail
- [ ] Project conventions documented to prevent common conflicts

---

Next: [Chapter 14 - Error Handling & Recovery](14-error-handling-recovery.md)
