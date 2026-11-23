# spec-sdlc-kit

**Spec-driven SDLC for any AI coding tool.** Drop a disciplined pipeline —
spec → design → implement → test → review → release — into any repo, and have
Claude Code, Codex, Gemini, Cursor, Windsurf or Google Antigravity all build to the
*same spec* with the *same human gates*.

```
spec ─► design ─► implement ─► test ─► review ─► release
(gate 1)  (gate 2)    ▲ quality   │        │ code+security   (gate 3)
                      └── gate ◄───┴────────┘  fix loops
```

The **spec is the source of truth**: requirements carry stable IDs (`REQ-1`,
`AC-1.1`, `NFR-1`) with acceptance criteria in **EARS** form ("WHEN … the system
SHALL …"). Every design task, test and review finding traces back to an ID — if it
isn't in the spec, it doesn't get built.

## Install (npx)

From the root of the repo you want to add it to:

```bash
npx spec-sdlc-kit init
```

Pick your tools when prompted, or:

```bash
npx spec-sdlc-kit init --tools=all
npx spec-sdlc-kit init --tools=claude,codex,cursor --yes
npx spec-sdlc-kit doctor      # check bash + jq/python3 are present
npx spec-sdlc-kit detect      # print the detected stack/test/lint
```

`init` will:
- install the **Claude Code layer** (`.claude/` — agents, skills, enforcing hooks),
- install the **tool-neutral core** (`sdlc/PROCESS.md` + `sdlc/templates/`),
- generate an **adapter per tool** you selected (see table below),
- **auto-detect** your stack and fill the test/lint commands into
  `.claude/CLAUDE.md` and each adapter,
- **merge** (never clobber) an existing `.claude/settings.json`.

Re-running `init` is safe; it won't overwrite your files unless you pass `--force`.

### Two layers

| Layer | File(s) | What it does |
|-------|---------|--------------|
| Neutral core | `sdlc/PROCESS.md`, `sdlc/templates/` | The full process + artifact templates every tool reads. |
| Claude Code | `.claude/` | Subagents per phase **and hooks that enforce** the gates. |

### Per-tool adapters

| Tool | File generated | Enforcement |
|------|----------------|-------------|
| Claude Code | `.claude/` | **Enforced** (hooks block violations) |
| Codex / Gemini / Jules / most | `AGENTS.md` | Guided |
| Google Antigravity | `AGENTS.md` + `.antigravity/rules/` | Guided |
| Cursor | `.cursor/rules/spec-sdlc.mdc` | Guided |
| Windsurf / Codeium | `.windsurf/rules/spec-sdlc.md` | Guided |

Only Claude Code can *enforce* the rules (locks source during spec/design, protects
secrets/lockfiles, blocks dangerous commands, won't finish while tests fail). Every
other tool *follows* the process because its adapter points at `sdlc/PROCESS.md` —
the three human gates still apply, so keep a human on them.

## Use

**Claude Code** (full, enforced):
```text
/sdlc Add password reset by email with a 15-minute expiring link
```
It runs each phase through a specialist subagent, stops at the three approval gates,
and keeps artifacts in `docs/sdlc/<slug>/`. Other commands: `/sdlc` (resume),
`/sdlc-phase <phase>`, `/sdlc-status`, `/quick-review`.

**Any other tool** (Codex, Cursor, Antigravity, …): just start working. The tool
reads its adapter, which tells it to write the spec first, get your approval, then
design → implement → test → review. Drive phases/state yourself with the script:

```bash
bash .claude/scripts/sdlc.sh start <slug>    # begin a feature (phase=requirements)
bash .claude/scripts/sdlc.sh phase design    # advance
bash .claude/scripts/sdlc.sh status          # feature, phase, tasks, trace summary
bash .claude/scripts/sdlc.sh trace           # verify every spec ID is covered in the design
bash .claude/scripts/sdlc.sh doctor          # check tooling
bash .claude/scripts/sdlc.sh finish          # close the feature
```

## What's inside the kit

```
.claude/
├── CLAUDE.md                 workflow memory (project specifics auto-filled on install)
├── settings.json             permissions + hook wiring + env (test/lint overrides)
├── agents/                   one specialist subagent per phase
├── skills/                   /sdlc, /sdlc-phase, /sdlc-status, /quick-review, sdlc-standards
├── hooks/                    session-start, guard-bash, phase-gate, format-lint, quality-gate, log-agent
└── scripts/sdlc.sh           state machine: start | phase | status | trace | doctor | finish
sdlc/
├── PROCESS.md                tool-neutral process (the single source of truth)
└── templates/                spec/design/test-report/review/release-notes templates
bin/cli.js                    the npx installer (zero dependencies, Node 16+)
templates/                    adapter + PROCESS sources used by the installer
```

## Customise

| Want to…                    | Edit |
|-----------------------------|------|
| Change the process/gates    | `templates/PROCESS.md` (+ `.claude/skills/sdlc/SKILL.md`) |
| Change coding rules / DoD   | `.claude/skills/sdlc-standards/SKILL.md` |
| Change artifact formats     | `.claude/skills/sdlc/templates/*.md` |
| Set test/lint command       | `.claude/settings.json` → `env.SDLC_TEST_CMD` / `SDLC_LINT_CMD` |
| Add/adjust a tool adapter   | `templates/*.md`, `templates/cursor.mdc` |
| Block more commands         | `.claude/hooks/guard-bash.sh` |

## Requirements
- `bash` plus `jq` **or** `python3` (hooks parse state). On Windows these ship with
  Git for Windows; Claude Code runs hooks through Git Bash.
- Node 16+ to run the `npx` installer.

## Docs
- Subagents: https://code.claude.com/docs/en/sub-agents
- Skills: https://code.claude.com/docs/en/skills
- Hooks: https://code.claude.com/docs/en/hooks
- AGENTS.md: https://agents.md
