# Available Team Members

## senior-engineer-1
- **Role**: Architecture specialist
- **Expertise**: System design, API design, database schema, design patterns, scalability
- **Model**: qwen2.5-coder:32b on PC1 (ATU-RIG02) local Ollama
- **When to use**: Architecture decisions, system design, complex technical problems, design reviews

## senior-engineer-2
- **Role**: Implementation specialist
- **Expertise**: Writing production code, optimization, debugging, refactoring, unit tests
- **Model**: codellama:13b on PC1 (ATU-RIG02) local Ollama
- **When to use**: Code implementation, bug fixes, performance optimization, code refactoring

## quality-agent
- **Role**: Quality assurance specialist
- **Expertise**: Code review, testing, documentation, coding standards
- **Model**: qwen2.5-coder:7b on PC2 (ATURIG01) remote Ollama
- **When to use**: Code reviews, test creation, documentation checks, style enforcement

## security-agent
- **Role**: Security specialist
- **Expertise**: OWASP Top 10, vulnerability scanning, dependency audits, auth/authz review
- **Model**: mistral:7b on PC2 (ATURIG01) remote Ollama
- **When to use**: Security audits, vulnerability checks, dependency reviews, compliance

## devops-agent
- **Role**: DevOps and infrastructure specialist
- **Expertise**: CI/CD, Docker, deployment, Git workflows, infrastructure automation
- **Model**: qwen2.5:3b on Laptop (LTATU01) remote Ollama
- **When to use**: Deployments, CI/CD setup, infrastructure tasks, Git workflow management

## monitoring-agent
- **Role**: Monitoring and performance specialist
- **Expertise**: Resource tracking, performance analysis, health checks, alerting
- **Model**: phi3:3.8b on Laptop (LTATU01) remote Ollama
- **When to use**: System health checks, resource monitoring, performance analysis, alerting
