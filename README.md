# Squadron Config

Configuration repository for [Squadron](https://docs.squadron.sh/) -- a declarative AI agent orchestration platform that lets you build, run, and version multi-agent workflows as config.

This repo defines the agents, models, plugins, skills, and missions used to automate code development, QA, and peer review workflows for the ZipTax project.

## Writing missions and agent instructions

A task's objective goes to its commander. The commander delegates tool work to the Squadron
agents selected by the task's `agents` field. Those agents use their configured tools to
coordinate Devin sessions and perform other assigned actions, such as Slack updates.

| Definition | Responsibility |
| --- | --- |
| Task in `missions/*.hcl` | Objective, allowed agents, accepted output, and routes |
| Commander | Break down the objective, delegate work, assess returned evidence, and select the route |
| Agent in `agents.hcl` | Reusable persona, role, tools, and available skills |
| Squadron skill | Reusable procedure loaded by a Squadron agent when needed |
| Devin session | Delegated repository work and analysis, guided by its playbook and repository skills |

When writing a task objective:

1. State the work, ordering, and acceptance criteria. Agent selection and persona already come
   from configuration; write the steps directly, such as "Publish the root status using
   case_slack."
2. Distinguish Squadron actions from Devin work: "Ask the existing fix session to correct the
   regression, then assess its returned evidence." A Squadron agent and a Devin session are
   separate participants; reusing an agent profile does not identify an existing Devin session.
3. Put repeated procedures in skills and task-specific decisions in the objective. Supply
   Devin with the relevant assignment and context; it does not inherit the mission objective.

For the rate workflow, see [phase ownership and routing](docs/rate-ticket-orchestration.md).

## Prerequisites

- [Squadron CLI](https://docs.squadron.sh/) installed
- API keys configured as Squadron variables (see [Variables](#variables))

## Repository Structure

```
.
├── system.hcl            # System-level settings (storage backend)
├── variables.hcl         # Secret variable declarations
├── models.hcl            # AI model provider definitions
├── plugins.hcl           # Plugin configurations (Devin, Shell)
├── tools.hcl             # Custom tool definitions
├── agents.hcl            # Agent definitions
├── skills.hcl            # Embedded skill instructions
├── mcp/
│   └── linear.hcl        # Linear MCP integration
├── missions/
│   ├── devy.hcl          # Full dev lifecycle mission
│   └── linear.hcl        # Linear issue info gathering mission
└── skills/
    ├── devin_code.md     # Code development skill guide
    ├── devin_qa.md       # QA review skill guide
    └── devin_review.md   # Peer review skill guide
```

## Configuration Overview

### System (`system.hcl`)

Configures Squadron to use SQLite as the storage backend for persisting mission state. This enables crash recovery -- missions resume from where they failed.

### Variables (`variables.hcl`)

Declares secret variables required by plugins and integrations. All are marked `secret = true` so values are masked in output.

| Variable            | Purpose                                      |
|---------------------|----------------------------------------------|
| `anthropic_api_key` | Anthropic API access for Claude models       |
| `devin_api_key`     | Devin service user token (`cog_` prefix)     |
| `github_token`      | GitHub personal access token for API operations |
| `linear_token`      | Linear project management API token          |
| `devin_org_id`      | Devin organization identifier                |

Set variables using the Squadron CLI:

```sh
squadron vars set anthropic_api_key <value>
squadron vars set devin_api_key <value>
squadron vars set github_token <value>
squadron vars set linear_token <value>
squadron vars set devin_org_id <value>
```

### Models (`models.hcl`)

Defines the Anthropic model provider with the following allowed models:

- `claude_sonnet_4` / `claude_sonnet_4_6`
- `claude_3_5_haiku` / `claude_haiku_4_5`
- `claude_opus_4` / `claude_opus_4_6`

### Plugins (`plugins.hcl`)

| Plugin  | Source                              | Purpose                                              |
|---------|-------------------------------------|------------------------------------------------------|
| `devin` | Local                               | Integrates with Devin AI for code development, QA, and review. 240-minute poll timeout. |
| `shell` | `github.com/mlund01/plugin_shell`   | Bash shell execution in local mode.                  |

### MCP Integrations (`mcp/`)

**Linear** (`mcp/linear.hcl`) -- Connects to [Linear](https://linear.app) via the Model Context Protocol for issue tracking. Authenticates using the `linear_token` variable.

## Agents

Define reusable agent profiles in [agents.hcl](agents.hcl), choosing the persona, model,
tools, and skills appropriate to each role. Tasks select the profiles they need through
`agents`; task-specific work and acceptance criteria belong in the objective.

## Skills

Skills provide reusable procedures that Squadron agents load when needed. Examples include:

- **devin_code** -- Workflow guide for using the `code_develop` tool: parameter documentation, prompt tips, and session inspection.
- **devin_qa** -- Workflow guide for the `code_qa` tool: what Devin checks (bugs, edge cases, error handling, test coverage, regressions, performance), and how to interpret results.
- **devin_review** -- Workflow guide for the `code_review` tool: what Devin reviews (code quality, correctness, security, best practices), inline comment posting, and effective review tips.

## Missions

### devy (`missions/devy.hcl`)

The primary autonomous development mission. Implements a full development lifecycle from a Linear issue through to a merge-ready PR.

**Inputs:**
- `repo_url` -- GitHub repository URL
- `branch` -- Branch name for Devin to create (optional)
- `base_branch` -- Target branch for PR merge (default: `stage`)
- `issue` -- Linear issue ID

**Task pipeline:**

```
develop --> qa_cycle --> review_cycle --> complete
```

1. **develop** -- Fetches the Linear issue (including any linked Technical Spec document), then uses Devin to create a branch, implement changes, and open a PR.
2. **qa_cycle** -- Iterative loop: QA agent reviews the PR, and if issues are found, `codegen` applies targeted fixes. Repeats until QA passes.
3. **review_cycle** -- Iterative loop: `peer_review` agent reviews the PR, and if changes are needed, `codegen` applies them. Repeats until the review is clean.
4. **complete** -- Compiles a final mission summary with the PR URL ready for merge.

### linear_ticket_info (`missions/linear.hcl`)

A lightweight mission that retrieves and structures Linear issue details for engineering consumption.

**Input:**
- `issue` -- Linear issue ID

**Output:** Issue title, description, comments, linked documents, and any Technical Spec content.

## Contract checks

Run the rate-workflow contract checks before changing its missions, report schemas, or examples:

```sh
uv run --with-requirements tests/requirements.txt python -m unittest discover -s tests -p test_rate_findings.py -v
```

These checks cover local contracts and fixtures; they do not exercise a live Squadron or Devin run.

## Further Reading

- [Project documentation](docs/README.md)
- [Squadron Documentation](https://docs.squadron.sh/)
- [Squadron SDK](https://github.com/mlund01/squadron-sdk)
