# Chapter 10 - Task Coordination

This chapter describes the complete workflow from receiving a task to delivering results, including task decomposition, assignment, tracking, quality gates, and reporting.

---

## 10.1 Task Lifecycle

Every task goes through these stages:

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│ RECEIVED │───►│ ANALYZED │───►│ ASSIGNED │───►│ IN       │───►│ REVIEW   │
│          │    │          │    │          │    │ PROGRESS │    │          │
└──────────┘    └──────────┘    └──────────┘    └──────────┘    └────┬─────┘
                                                                     │
                                                              ┌──────▼─────┐
                                                              │ Pass?      │
                                                              │            │
                                                         Yes  │    No      │
                                                    ┌─────────┤            │
                                                    │         └──────┬─────┘
                                               ┌────▼─────┐         │
                                               │DELIVERED │    ┌────▼─────┐
                                               │          │    │ REVISION │──► Back to
                                               └──────────┘    └──────────┘   IN PROGRESS
```

### Task States

| State | Description | Who |
|-------|-------------|-----|
| RECEIVED | Task enters the system via Telegram | Coordinator |
| ANALYZED | Coordinator understands what's needed | Coordinator |
| ASSIGNED | Sub-tasks sent to team members | Coordinator |
| IN_PROGRESS | Team members are working on it | Assigned agents |
| REVIEW | Quality and/or security review | Quality/Security agents |
| REVISION | Issues found, needs fixes | Assigned agents |
| DELIVERED | Final result sent to human | Coordinator |
| CANCELLED | Task was cancelled by human | Coordinator |
| FAILED | Task couldn't be completed | Coordinator |

---

## 10.2 Task Intake (How Tasks Enter the System)

### 10.2.1 Via Telegram Message

The most common way. The human sends a message:

```
You: Build a REST API for managing a todo list with CRUD operations
```

The coordinator receives this and begins processing.

### 10.2.2 Via Telegram Command

For structured requests:

```
/assign Build a REST API for managing a todo list
```

### 10.2.3 Via OpenClaw CLI (for testing)

```powershell
openclaw task create --description "Build a REST API for managing a todo list with CRUD operations" --priority high
```

---

## 10.3 Task Analysis and Decomposition

When the coordinator receives a task, it follows this process:

### Step 1: Understand the Request

The coordinator identifies:
- **What** needs to be done
- **Type** of task (architecture, implementation, bug fix, etc.)
- **Scope** (how big is this?)
- **Dependencies** (does this need anything else first?)

### Step 2: Decompose into Sub-Tasks

For the todo list API example:

```
Main Task: Build a REST API for managing a todo list
│
├── Sub-task 1: Design the API architecture
│   Assigned to: Senior Engineer #1
│   Deliverable: API specification (endpoints, data models, auth)
│
├── Sub-task 2: Implement the API
│   Assigned to: Senior Engineer #2
│   Depends on: Sub-task 1
│   Deliverable: Working API code
│
├── Sub-task 3: Code review
│   Assigned to: Quality Agent
│   Depends on: Sub-task 2
│   Deliverable: Review report
│
├── Sub-task 4: Security review
│   Assigned to: Security Agent
│   Depends on: Sub-task 2
│   Deliverable: Security assessment
│
└── Sub-task 5: Deployment configuration
    Assigned to: DevOps Agent
    Depends on: Sub-tasks 3 & 4 (must pass)
    Deliverable: Docker/deployment config
```

### Step 3: Assign and Track

```powershell
# The coordinator creates and assigns sub-tasks via OpenClaw
openclaw task assign --task-id "task-001-sub-1" --to senior-engineer-1 --content "Design REST API architecture for todo list management..."
openclaw task assign --task-id "task-001-sub-2" --to senior-engineer-2 --depends-on "task-001-sub-1" --content "Implement the API based on the architecture design..."
# ... etc
```

---

## 10.4 Coordinator's Decision-Making Process

The coordinator uses a systematic approach:

### 10.4.1 Task Classification

```
Input: "Build a REST API for managing a todo list"

Classification:
- Category: Implementation (with architecture design needed)
- Complexity: Medium
- Estimated agents needed: 4-5
- Estimated time: 30-60 minutes
- Risk level: Low
- Requires human approval: No
```

### 10.4.2 Agent Selection

```
Required Capabilities:
1. API design → Senior Engineer #1 (architecture_design capability)
2. Code implementation → Senior Engineer #2 (code_implementation capability)
3. Code review → Quality Agent (code_review capability)
4. Security check → Security Agent (vulnerability_scanning capability)
5. Deployment → DevOps Agent (deployment capability)

Agent Availability:
- Senior Engineer #1: AVAILABLE (PC1)
- Senior Engineer #2: AVAILABLE (PC1)
- Quality Agent: AVAILABLE (PC2)
- Security Agent: AVAILABLE (PC2)
- DevOps Agent: AVAILABLE (Laptop)

Decision: Proceed with all agents
```

### 10.4.3 When to Escalate to Human

The coordinator escalates when:

- The task is ambiguous and needs clarification
- A restricted action is required (software install, purchases, etc.)
- Team members disagree and can't reach consensus
- A task fails after multiple retries
- Security concerns are identified
- Resources are insufficient for the task

---

## 10.5 Progress Tracking

### 10.5.1 Task Dashboard

Check the status of all tasks:

```powershell
# View all active tasks
openclaw task list --status active

# View details of a specific task
openclaw task show --id "task-001"

# View task history
openclaw task history --limit 20
```

### 10.5.2 Status Updates via Telegram

The coordinator sends periodic updates:

```
📋 Task Update: Build REST API for todo list

Sub-task 1 (Architecture): ✅ Complete
Sub-task 2 (Implementation): 🔄 In Progress (Senior Eng #2)
Sub-task 3 (Code Review): ⏳ Waiting for Sub-task 2
Sub-task 4 (Security Review): ⏳ Waiting for Sub-task 2
Sub-task 5 (Deployment): ⏳ Waiting for Sub-tasks 3 & 4

Estimated completion: ~20 minutes
```

### 10.5.3 Automatic Progress Notifications

Configure when to send updates:

```yaml
# In team.yaml or separate task config
task_tracking:
  notify_on_subtask_complete: true
  notify_on_review_complete: true
  notify_on_error: true
  notify_interval_minutes: 10    # Send update every 10 minutes for long tasks
  notify_on_completion: true
```

---

## 10.6 Quality Gates

Before a task is considered complete, it must pass quality gates:

### Gate 1: Code Review (Quality Agent)

The quality agent checks:
- [ ] Code compiles and runs without errors
- [ ] Logic is correct
- [ ] Error handling is adequate
- [ ] Code follows project conventions
- [ ] No obvious bugs or edge case failures

**Pass criteria**: No critical issues. Minor suggestions are noted but don't block.

### Gate 2: Security Review (Security Agent)

The security agent checks:
- [ ] No hardcoded secrets or credentials
- [ ] Input validation on all external inputs
- [ ] No SQL injection, XSS, or command injection vulnerabilities
- [ ] Authentication/authorization implemented correctly
- [ ] Dependencies don't have known vulnerabilities

**Pass criteria**: No high or critical severity findings.

### Gate 3: Coordinator Final Review

The coordinator:
- [ ] Verifies the result matches the original request
- [ ] Ensures all sub-tasks are complete
- [ ] Checks that reviews passed
- [ ] Compiles the final deliverable

---

## 10.7 Handling Revisions

When a quality gate fails:

```
Quality Agent Review Result:
  Status: NEEDS_REVISION
  Issues:
    1. [HIGH] Missing input validation on POST /todos endpoint
    2. [MEDIUM] No pagination on GET /todos endpoint
    3. [LOW] Inconsistent error response format

Coordinator Action:
  → Send issues back to Senior Engineer #2
  → Assign: "Fix the 3 issues found in quality review"
  → After fix: Re-run quality review
```

The cycle repeats until the code passes all quality gates (maximum 3 revision cycles before escalating to human).

---

## 10.8 Task Delivery

When all quality gates pass:

```
Coordinator → Telegram:

✅ Task Complete: Build REST API for todo list

Summary:
- Created REST API with CRUD endpoints for todo management
- Endpoints: GET/POST /todos, GET/PUT/DELETE /todos/{id}
- JWT authentication included
- Input validation on all endpoints
- Unit tests included (15 tests, all passing)

Files changed:
- src/routes/todos.py (new)
- src/models/todo.py (new)
- src/tests/test_todos.py (new)
- requirements.txt (updated)

PR: https://github.com/org/repo/pull/42
Branch: ai-team/feature-todo-api

Review Status:
- Quality Review: ✅ Passed
- Security Review: ✅ Passed

Please review the PR and merge when ready.
```

---

## 10.9 Concurrent Task Handling

The team can work on multiple tasks simultaneously:

```
Task A: "Build login page"
  → Senior Eng #1 (designing) + Senior Eng #2 (waiting)

Task B: "Fix database connection bug"
  → Senior Eng #2 (implementing) — different model instance

Task C: "Review PR #38"
  → Quality Agent (reviewing)

Task D: "Check system health"
  → Monitoring Agent (monitoring)
```

### Limitations

- PC1 can only run one large model at a time, so Senior Engineers may queue
- PC2 can run two 7B models simultaneously (Quality + Security in parallel)
- Laptop can handle one model at a time
- The coordinator manages prioritization when resources are constrained

---

## 10.10 Checklist

- [ ] Task intake via Telegram works
- [ ] Coordinator correctly classifies tasks
- [ ] Sub-task decomposition produces logical breakdowns
- [ ] Agent assignment follows the routing rules
- [ ] Progress tracking shows real-time status
- [ ] Telegram updates arrive during task execution
- [ ] Quality gates function (code review + security review)
- [ ] Revision cycle works when issues are found
- [ ] Final delivery message is clear and complete
- [ ] Concurrent tasks don't cause conflicts

---

Next: [Chapter 11 - Monitoring Setup](11-monitoring-setup.md)
