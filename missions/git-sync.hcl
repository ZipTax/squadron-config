# ==============================================================================
# git_sync.hcl — push / pull / sync a local git worktree against its remote
# ==============================================================================
#
#   squadron mission git_sync -c ~/squadron/config --input mode=push
#   squadron mission git_sync -c ~/squadron/config --input mode=pull
#   squadron mission git_sync -c ~/squadron/config --input mode=sync
#
# Leave `mode` blank and the first task asks you to pick, via
# builtins.human.ask with choices = push / pull / sync. The Command Center
# renders those as quick-reply buttons in the Inbox, so launching from the UI
# with an empty mode field gives you a picker. Passing --input mode=... skips
# the prompt entirely, which is what schedules and scripts should do.
#
# Drop this file in the config directory. Self-contained: it declares its own
# plugin, model, agents, and mission with gitsync_-prefixed names so nothing
# collides with blocks you already have.
#
# ------------------------------------------------------------------------------
# READ THIS FIRST — the one thing you must wire up
# ------------------------------------------------------------------------------
# Squadron has no built-in shell tool. Git has to come from a plugin (or an MCP
# server). I could not verify a published shell plugin, so the `plugin` block
# below is the only part of this file that must match your environment. Pick one:
#
#   A) You already have a shell plugin loaded → delete the plugin block and
#      change the agent's `tools` to [plugins.<your_name>.exec].
#
#   B) You have a shell plugin source on disk → point `source` at it. A local
#      path must resolve inside the project root and `version` must be "local".
#
#   C) You built one already with `squadron plugin build gitsync_shell <src>` →
#      drop the `source` attribute and keep `version = "local"`.
#
# The task objectives assume that tool runs commands through a shell, since they
# use `&&`, `$(date ...)`, and `$HOME`. If yours execs argv directly instead,
# tell the agent to send one command per invocation and pass an absolute path.
#
# Everything else in this file is straight from the Squadron docs and needs no
# changes. Run `squadron verify ~/squadron/config` before the first mission run.
#
# ------------------------------------------------------------------------------
# Conflict policy: LOCAL WINS (your choice)
# ------------------------------------------------------------------------------
#   push  — commits local changes, then `git push --force-with-lease`.
#           Overwrites the remote branch. Never plain `--force`.
#   pull  — `git reset --hard origin/<branch>`. Remote overwrites your worktree.
#   sync  — fast-forwards when the remote is simply ahead; if both sides have
#           diverged, local wins via `--force-with-lease`.
#
# Every destructive step leaves a recovery ref behind first (see the report
# task's `backup_refs` output), so nothing is unrecoverable.
#
# WARNING: `.squadron/vars.vault` holds your encrypted variables and is normally
# gitignored. The mission is instructed never to run `git clean -x`, which would
# delete it. Keep it out of the repo and keep that instruction intact.
# ==============================================================================


# ------------------------------------------------------------------------------
# Shell access — see options A/B/C above
# ------------------------------------------------------------------------------
plugin "gitsync_shell" {
  source  = "github.com/mlund01/plugin_shell"
  version = "v0.0.1"
  settings = {
    mode  = "local"
    shell = "bash" 
  }
}

# ------------------------------------------------------------------------------
# Model
# ------------------------------------------------------------------------------
# References the vault key directly, so there's no `variable` block to collide
# with yours. Anything set via `squadron vars set` is available as vars.<name>.
# If your vault key has a different name, change it here.
model "gitsync_anthropic" {
  provider = "anthropic"
  api_key  = vars.anthropic_api_key
}

# ------------------------------------------------------------------------------
# Agent — the only thing that touches the filesystem
# ------------------------------------------------------------------------------
agent "gitsync_operator" {
  model = models.gitsync_anthropic.claude_sonnet_4_6

  # `role` is required by the Squadron binary but is not in the published docs
  # (docs.squadron.sh/config/agents lists only model, personality, tools,
  # reasoning, skills). Treated here as a free-text description of the job. If
  # your build expects an enum, `squadron verify` will name the allowed values.
  role = "Git operator — runs git commands in a local worktree via the shell"

  personality = <<-EOT
    A careful release engineer who runs git from a shell and nothing else.

    Rules, without exception:
      - Run exactly the commands you are given, one at a time, in order.
      - Prefix every command with `cd "<repo_path>" &&` so it always runs in
        the target worktree. Never rely on an inherited working directory.
      - If the path starts with `~`, rewrite it as `$HOME/...` first. A tilde
        inside double quotes does not expand, so `cd "~/foo"` fails.
      - Report each command's full stdout, stderr, and exit code verbatim.
        Never summarize git output and never invent it.
      - Stop immediately on a non-zero exit code and report it. Do not
        improvise a fix, retry with different flags, or escalate to a more
        forceful command.
      - Never run `git push --force` (only `--force-with-lease`), never
        `git clean -x` or `-X`, never `git reset --hard` unless the objective
        says so explicitly, never `git config`, and never touch credentials.
        The local git config handles auth.
  EOT

  tools = [plugins.gitsync_shell.exec]
}

# ------------------------------------------------------------------------------
# Agent — asks the operator to pick a mode. Kept separate from the git operator
# on purpose, so the agent holding the shell has no reason to talk to a human
# and the agent talking to a human has no shell.
# ------------------------------------------------------------------------------
agent "gitsync_prompter" {
  model = models.gitsync_anthropic.claude_haiku_4_5

  role = "Mode picker — asks the operator which git operation to run"

  personality = <<-EOT
    Asks one question and reports the answer verbatim. Never interprets,
    expands, or corrects it. If no answer comes back, says so plainly rather
    than picking a mode on the operator's behalf.
  EOT

  tools = [builtins.human.ask]
}

# ------------------------------------------------------------------------------
# Mission
# ------------------------------------------------------------------------------
mission "git_sync" {
  directive = <<-EOT
    Push, pull, or sync a local git worktree against its already-configured
    remote. One mode per run, chosen by the `mode` input. On divergence, local
    wins. Every destructive step is preceded by a recovery ref.
  EOT

  commander {
    model     = models.gitsync_anthropic.claude_sonnet_4_6
    reasoning = "low"
  }

  agents = [agents.gitsync_operator, agents.gitsync_prompter]

  # Never let two git_sync runs touch the same worktree at once.
  max_parallel = 1

  budget {
    tokens  = 400000
    dollars = 3.00
  }

  # ---------------------------------------------------------------------------
  # Inputs — all optional; leave mode blank to get the picker
  # ---------------------------------------------------------------------------
  # repo_path uses $HOME rather than ~ on purpose: the agent quotes the path,
  # and a quoted tilde does not expand in a shell.
  inputs = {
    mode           = string("What to do: push, pull, or sync. Leave blank to be asked.", { default = "" })
    repo_path      = string("Path to the git worktree to operate on", { default = "$HOME/squadron/config" })
    branch         = string("Remote branch to push to / pull from", { default = "main" })
    commit_message = string("Commit message used when local changes need committing", { default = "chore(config): squadron git_sync" })
    dry_run        = bool("Print the git commands without running any that change state", { default = false })
  }

  # ---------------------------------------------------------------------------
  # choose_mode — resolve the mode from the input, or ask the operator
  # ---------------------------------------------------------------------------
  task "choose_mode" {
    agents = [agents.gitsync_prompter]

    objective = <<-EOT
      Establish which git operation this run should perform. Touch nothing on
      disk — this task only resolves a value.

      The `mode` input was: "${inputs.mode}"

      If that value is exactly "push", "pull", or "sync" (lowercase), it is
      already resolved. Do NOT ask the operator anything. Submit it and finish.

      If it is empty, or anything else, have the prompter agent call the human
      `ask` tool exactly once with:

        question        : Which git operation should run against
                          "${inputs.repo_path}" on branch ${inputs.branch}?
                          push overwrites the remote with local, pull discards
                          local and takes the remote, sync fast-forwards when
                          it can and lets local win when the two have diverged.
        short_summary   : Pick a git_sync mode for ${inputs.branch}
        choices         : ["push", "pull", "sync"]
        timeout_seconds : 300

      Then:
        - If the answer is exactly push, pull, or sync, that is the mode.
        - If the tool returns "[no human available]", times out, or comes back
          with anything else, set mode to "unresolved". Do not guess, do not
          default to a mode, and do not ask a second time. Preflight will route
          the run to abort.

      Report the answer verbatim in `notes`, including a non-answer.
    EOT

    output = {
      mode   = string("Resolved mode: push, pull, sync, or unresolved", true)
      source = string("Where the mode came from: \"input\" or \"operator prompt\"", true)
      notes  = string("The operator's raw answer, or why the mode is unresolved")
    }
  }

  # ---------------------------------------------------------------------------
  # preflight — read-only inspection, then pick the branch
  # ---------------------------------------------------------------------------
  task "preflight" {
    depends_on = [tasks.choose_mode]
    agents     = [agents.gitsync_operator]

    objective = <<-EOT
      Inspect the git repository at "${inputs.repo_path}". This task is
      READ-ONLY: do not commit, reset, push, stash, or clean anything here.

      The mode for this run is whatever choose_mode resolved. Read it from that
      task's structured output with query_task_output — do not re-read the
      `mode` input and do not ask the operator again.

        Target branch: "${inputs.branch}"
        Dry run:       ${inputs.dry_run}

      Have the operator agent run these, in order, each prefixed with
      `cd "${inputs.repo_path}" &&`:

        1. git rev-parse --is-inside-work-tree
        2. git remote -v
        3. git rev-parse --abbrev-ref HEAD
        4. git status --porcelain
        5. git fetch origin --prune
        6. git rev-list --left-right --count origin/${inputs.branch}...HEAD

      Reading the results:
        - Step 6 prints two numbers separated by a tab: the LEFT number is how
          many commits origin/${inputs.branch} has that HEAD does not (behind),
          the RIGHT number is how many HEAD has that origin does not (ahead).
        - If step 6 fails because origin/${inputs.branch} does not exist, that
          is not an abort. Set behind = 0, ahead = 0, say so in `notes`, and
          continue: push and sync can create the branch.
        - `resolved_mode` is choose_mode's mode, copied through unchanged.
        - `mode_valid` is true only when that mode is exactly "push", "pull",
          or "sync". A mode of "unresolved" means false.

      Then submit the structured output and choose your route.
    EOT

    output = {
      resolved_mode  = string("The mode choose_mode resolved", true)
      is_repo        = bool("Step 1 confirmed this is a git worktree", true)
      has_remote     = bool("Step 2 listed a remote named origin", true)
      current_branch = string("Branch currently checked out", true)
      is_dirty       = bool("Step 4 returned any uncommitted or untracked changes", true)
      behind         = integer("Commits on origin/<branch> that HEAD lacks", true)
      ahead          = integer("Commits on HEAD that origin/<branch> lacks", true)
      mode_valid     = bool("The resolved mode is push, pull, or sync", true)
      notes          = string("Anything unusual: missing remote branch, detached HEAD, branch mismatch, command failures")
    }

    router {
      route {
        target    = tasks.push_local
        condition = "The repo is valid, has an origin remote, and the resolved mode is exactly \"push\""
      }
      route {
        target    = tasks.pull_remote
        condition = "The repo is valid, has an origin remote, and the resolved mode is exactly \"pull\""
      }
      route {
        target    = tasks.sync_both
        condition = "The repo is valid, has an origin remote, and the resolved mode is exactly \"sync\""
      }
      route {
        target    = tasks.abort
        condition = "Anything is wrong: the mode is \"unresolved\" or not one of push/pull/sync, this is not a git worktree, there is no origin remote, HEAD is detached, or a preflight command failed unexpectedly"
      }
    }
  }

  # ---------------------------------------------------------------------------
  # push_local — local overwrites remote
  # ---------------------------------------------------------------------------
  task "push_local" {
    agents = [agents.gitsync_operator]

    objective = <<-EOT
      MODE: push. Send local state to origin/${inputs.branch}. Local wins.

      If ${inputs.dry_run} is true: print the exact commands you would run,
      run only the read-only ones (steps 1 and 3), change nothing, and stop.

      Each command prefixed with `cd "${inputs.repo_path}" &&`:

        1. git status --porcelain
        2. Only if step 1 printed anything:
             git add -A
             git commit -m "${inputs.commit_message}"
        3. git fetch origin --prune
        4. Recovery ref for whatever we are about to overwrite. Skip if
           origin/${inputs.branch} does not exist yet:
             TS=$(date -u +%Y%m%dT%H%M%SZ)
             git update-ref refs/gitsync/pre-push-$TS refs/remotes/origin/${inputs.branch}
        5. git push --force-with-lease origin HEAD:${inputs.branch}
        6. git rev-parse HEAD
        7. git rev-parse origin/${inputs.branch}

      Hard rules:
        - If step 5 is rejected because the lease is stale, STOP. Someone else
          pushed since your fetch. Do NOT retry with `--force`. Report the
          rejection and tell the operator to run mode=sync or mode=pull.
        - Steps 6 and 7 must print the same sha. If they do not, say so.

      Report the recovery ref name from step 4 so the report task can list it.
    EOT

    send_to = [tasks.report]
  }

  # ---------------------------------------------------------------------------
  # pull_remote — remote overwrites local worktree
  # ---------------------------------------------------------------------------
  task "pull_remote" {
    agents = [agents.gitsync_operator]

    objective = <<-EOT
      MODE: pull. Reset the local worktree to origin/${inputs.branch}. The
      remote wins. This DISCARDS local commits and uncommitted changes from the
      worktree, so take the snapshots in steps 3 and 4 first — they are not
      optional.

      If ${inputs.dry_run} is true: print the exact commands you would run,
      run only the read-only ones (steps 1 and 2), change nothing, and stop.

      Each command prefixed with `cd "${inputs.repo_path}" &&`:

        1. git fetch origin --prune
        2. git status --porcelain
        3. Snapshot local HEAD so discarded commits stay recoverable:
             TS=$(date -u +%Y%m%dT%H%M%SZ)
             git branch gitsync/pre-pull-$TS
        4. Only if step 2 printed anything, stash uncommitted and untracked
           work so it stays recoverable:
             git stash push --include-untracked -m "gitsync pre-pull $TS"
        5. If the current branch is not ${inputs.branch}:
             git checkout ${inputs.branch}
           and if that fails because the branch does not exist locally:
             git checkout -b ${inputs.branch} origin/${inputs.branch}
        6. git reset --hard origin/${inputs.branch}
        7. git rev-parse HEAD
        8. git rev-parse origin/${inputs.branch}

      Hard rules:
        - NEVER run `git clean -x` or `git clean -X`. Ignored files include
          .squadron/vars.vault, the encrypted variable vault. Losing it loses
          your API keys. Step 4's stash already captured untracked files, so no
          clean is needed at all — do not run one.
        - Steps 7 and 8 must print the same sha. If they do not, say so.

      Report the branch name from step 3 and the stash from step 4 (if created)
      so the report task can list them.
    EOT

    send_to = [tasks.report]
  }

  # ---------------------------------------------------------------------------
  # sync_both — fast-forward when possible, local wins when diverged
  # ---------------------------------------------------------------------------
  task "sync_both" {
    agents = [agents.gitsync_operator]

    objective = <<-EOT
      MODE: sync. Reconcile local and origin/${inputs.branch} in one pass.

      If ${inputs.dry_run} is true: print the exact commands you would run,
      run only the read-only ones (steps 1, 2, 4), change nothing, and stop.

      Each command prefixed with `cd "${inputs.repo_path}" &&`:

        1. git fetch origin --prune
        2. git status --porcelain
        3. Only if step 2 printed anything:
             git add -A
             git commit -m "${inputs.commit_message}"
        4. git rev-list --left-right --count origin/${inputs.branch}...HEAD
           LEFT = behind (commits only on origin), RIGHT = ahead (only local).

        5. Act on the two numbers, and only on the matching case:

           behind = 0, ahead = 0 → already in sync. Do nothing else.

           behind > 0, ahead = 0 → pure pull, no history rewrite needed:
             git merge --ff-only origin/${inputs.branch}

           behind = 0, ahead > 0 → pure push, no force needed:
             git push origin HEAD:${inputs.branch}

           behind > 0, ahead > 0 → DIVERGED. Local wins:
             TS=$(date -u +%Y%m%dT%H%M%SZ)
             git update-ref refs/gitsync/pre-push-$TS refs/remotes/origin/${inputs.branch}
             git push --force-with-lease origin HEAD:${inputs.branch}

        6. git rev-parse HEAD
        7. git rev-parse origin/${inputs.branch}

      Hard rules:
        - Do not run `git pull`, `git merge` without `--ff-only`, or
          `git rebase`. The four cases above are the only permitted actions.
        - If `--ff-only` fails, the branches diverged between step 4 and step 5.
          Re-run step 4 and take the diverged path instead.
        - If `--force-with-lease` is rejected, STOP. Do NOT retry with
          `--force`. Report the rejection.
        - Steps 6 and 7 must print the same sha. If they do not, say so.

      Report which of the four cases fired and any recovery ref you created.
    EOT

    send_to = [tasks.report]
  }

  # ---------------------------------------------------------------------------
  # abort — preflight found a reason not to touch the repo
  # ---------------------------------------------------------------------------
  task "abort" {
    objective = <<-EOT
      Preflight found a blocking problem, so no git state was changed. Do not
      run any git command in this task.

      Using choose_mode's and preflight's structured output, state plainly:
        - what the blocking condition was: not a worktree, no origin remote,
          detached HEAD, a failed command, or an unusable mode
        - the exact one-line fix the operator should apply

      If the mode was the problem, say which case it was. Either the operator
      never answered the picker (choose_mode reported "unresolved" — re-run and
      answer it, or pass --input mode=push|pull|sync), or a mode was passed
      that is not one of push, pull, sync. Quote what was actually received.
    EOT

    send_to = [tasks.report]
  }

  # ---------------------------------------------------------------------------
  # report — shared fan-in for whichever branch ran
  # ---------------------------------------------------------------------------
  # Reached only via send_to, so it deliberately has no depends_on: a router
  # activates exactly one branch, and depends_on would hang on the other three.
  task "report" {
    objective = <<-EOT
      Summarize the run for a human reading it later. Do not run any git
      command — report only what the previous task actually observed. If a
      command failed, say so; never present a failed run as successful.

      Cover:
        - the mode that ran and what git actually did
        - final local HEAD vs origin/${inputs.branch}, and whether they match
        - every recovery ref, backup branch, and stash left behind, with the
          exact command to restore or drop it
        - anything the operator needs to act on

      Recovery cheat sheet for the backup_refs entries:
        refs/gitsync/pre-push-*     overwritten remote tip:
                                    git reset --hard refs/gitsync/pre-push-<TS>
        gitsync/pre-pull-*          local HEAD before a pull:
                                    git reset --hard gitsync/pre-pull-<TS>
        stash "gitsync pre-pull *"  uncommitted work before a pull:
                                    git stash list
                                    git stash pop stash@{N}

      These refs accumulate. Note in `warnings` if there are more than a few.
    EOT

    output = {
      mode_run    = string("Mode that actually executed: push, pull, sync, or abort", true)
      action      = string("One line on what git did, or why nothing was done", true)
      succeeded   = bool("Every command the branch ran exited zero and the end state is as intended", true)
      local_head  = string("Local HEAD sha after the run, or empty if unchanged/aborted")
      remote_head = string("origin/<branch> sha after the run, or empty if unknown")
      in_sync     = bool("Local HEAD and origin/<branch> point at the same commit", true)
      backup_refs = list(string, "Recovery refs, backup branches, and stashes left behind")
      warnings    = list(string, "Anything the operator should act on, including accumulated recovery refs")
    }
  }
}