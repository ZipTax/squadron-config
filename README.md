# Squadron Config

Configuration repository for [Squadron](https://docs.squadron.sh/) -- a declarative AI agent orchestration platform that lets you build, run, and version multi-agent workflows as config.

This repo defines the agents, models, plugins, skills, and missions used to automate code development, QA, and peer review workflows for the ZipTax project.

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

Four specialized agents are defined in `agents.hcl`, all powered by Claude Opus 4.6:

| Agent               | Role | Tools |
|---------------------|------|-------|
| **`codegen`**         | Delegates development tasks to Devin. Provides clear task descriptions and coding guidelines so Devin can create branches, implement changes, and open PRs. | `code_develop`, `check_session` |
| **`quality_assurance`** | Manages QA review. Analyzes diffs for regressions, logic errors, missing test coverage, and edge cases. Produces structured QA reports with pass/fail verdicts. | `code_develop`, `code_qa`, `check_session` |
| **`peer_review`**     | Performs peer code review. Evaluates correctness, maintainability, and security. Posts inline comments directly on GitHub PRs. | `code_develop`, `code_review`, `check_session` |
| **`linear`**          | Gathers and prepares technical issue details from Linear for engineers implementing the work. | All Linear MCP tools |

## Skills

Skills provide detailed instructions that are loaded into agents when they use specific tools:

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

## Further Reading

- [Squadron Documentation](https://docs.squadron.sh/)
- [Squadron SDK](https://github.com/mlund01/squadron-sdk)
