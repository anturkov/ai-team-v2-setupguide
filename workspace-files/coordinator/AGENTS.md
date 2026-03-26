# Available Team Members

Use `sessions_send` for quick questions (waits for reply) or `sessions_spawn` for independent tasks (non-blocking).

## senior-engineer-1
- **Role**: Architecture specialist
- **Expertise**: System design, API design, database schema, design patterns, scalability, technical specifications
- **Model**: qwen3-coder:30b-a3b on PC1 (ATU-RIG02)
- **When to use**: Architecture decisions, system design, complex technical problems, design reviews, technical specs
- **Dispatch**: `sessions_send` or `sessions_spawn` with agentId `senior-engineer-1`

## senior-engineer-2
- **Role**: Implementation specialist
- **Expertise**: Writing production code, optimization, debugging, refactoring, unit tests, code fixes
- **Model**: qwen3-coder:30b-a3b on PC1 (ATU-RIG02)
- **When to use**: Code implementation, bug fixes, performance optimization, code refactoring, writing tests
- **Dispatch**: `sessions_send` or `sessions_spawn` with agentId `senior-engineer-2`

## quality-agent
- **Role**: Quality assurance specialist
- **Expertise**: Code review, testing, documentation, coding standards, best practices
- **Model**: qwen3:14b on PC2 (ATURIG01)
- **When to use**: Code reviews, test creation, documentation checks, style enforcement
- **Dispatch**: `sessions_send` or `sessions_spawn` with agentId `quality-agent`

## security-agent
- **Role**: Security specialist
- **Expertise**: OWASP Top 10, vulnerability scanning, dependency audits, auth/authz review, data exposure
- **Model**: qwen3:14b on PC2 (ATURIG01)
- **When to use**: Security audits, vulnerability checks, dependency reviews, compliance checks
- **Dispatch**: `sessions_send` or `sessions_spawn` with agentId `security-agent`

## devops-agent
- **Role**: DevOps and infrastructure specialist
- **Expertise**: CI/CD, Docker, deployment pipelines, Git workflows, infrastructure automation
- **Model**: qwen3:4b on Laptop (LTATU01)
- **When to use**: Deployments, CI/CD setup, Docker configuration, infrastructure tasks
- **Dispatch**: `sessions_send` or `sessions_spawn` with agentId `devops-agent`

## monitoring-agent
- **Role**: Monitoring and performance specialist
- **Expertise**: Resource tracking (CPU, RAM, GPU, disk), performance analysis, health checks, alerting
- **Model**: qwen3:4b on Laptop (LTATU01)
- **When to use**: System health checks, resource monitoring, performance reports, capacity planning
- **Dispatch**: `sessions_send` or `sessions_spawn` with agentId `monitoring-agent`
