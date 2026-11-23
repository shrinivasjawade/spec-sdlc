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
- always install the **tool-neutral core** (`sdlc/` — scripts, templates, `PROCESS.md`,
  a vendor-neutral `SKILL.md`, and `patterns.md`),
- install the **Claude Code layer** (`.claude/` — agents, skills, enforcing hooks)
  **only if you select Claude** (so a Codex-only repo stays free of `.claude/`),
- generate an **adapter per tool** you selected (see table below),
- **auto-detect** your stack and fill the test/lint commands into
  `.claude/CLAUDE.md` and each adapter,
- **merge** (never clobber) an existing `.claude/settings.json`.

Re-running `init` is safe; it won't overwrite your files unless you pass `--force`.

### Two layers

| Layer | File(s) | What it does |
|-------|---------|--------------|
| Neutral core (always) | `sdlc/` — `PROCESS.md`, `SKILL.md`, `patterns.md`, `scripts/`, `templates/` | The canonical process, governance scripts, and artifact templates every tool reads. |
| Claude Code (if selected) | `claude-code/` in this repo → installs as `.claude/` | Subagents per phase **and hooks that enforce** the gates. Thin shims point back at the neutral core (one source of truth). |

> Note: the Claude Code adapter is stored as `claude-code/` in this repository (a plain, visible folder), and the installer deploys it as `.claude/` in your project — the name Claude Code requires to auto-load it, like `.git`.

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
bash sdlc/scripts/sdlc.sh start <slug>    # begin a feature (phase=requirements)
bash sdlc/scripts/sdlc.sh phase design    # advance
bash sdlc/scripts/sdlc.sh status          # feature, phase, tasks, trace summary
bash sdlc/scripts/sdlc.sh trace           # every spec ID mapped in the Traceability table
bash sdlc/scripts/sdlc.sh verify          # every ID maps to a task AND a test; emits trace.json
bash sdlc/scripts/sdlc.sh metrics         # governance scorecard + release gate
bash sdlc/scripts/sdlc.sh doctor          # check tooling
bash sdlc/scripts/sdlc.sh finish          # close the feature
```

## Governance (AI-native)

Quality is measured, not asserted:

- **`verify`** turns the design's traceability table into a machine-readable
  contract (`trace.json`): every `AC-*`/`NFR-*` must map to a task **and** a test.
- **`metrics`** prints a scorecard — **Spec Fidelity**, **AC Test Coverage**,
  **Ambiguity Tax** (open questions + vague terms), **Task Completion Index** with a
  **repair multiplier φ** — and a **release gate** that blocks release until Spec
  Fidelity is 100% and open questions are resolved.
- **Independent verification:** a fresh-context `verifier` agent checks the
  implementation against the spec during review (it didn't write the code).
- **Provenance:** every subagent run is appended to `docs/sdlc/<slug>/provenance.jsonl`
  (agent, phase, session, spec version) — an audit trail beside the git history.
- **Change control:** a material spec change re-opens Gate 1; a design change re-opens
  Gate 2. **Patterns:** `sdlc/patterns.md` is checked for adherence in review.

Run the kit's own test suite with `npm test`.

## Visualize (anyone can read it)

`sdlc/dashboard/index.html` is a dependency-free, **n8n-style pipeline map** — six
steps, three human gates, fix loops, and a live governance scorecard — that opens in
any browser (double-click, no build). It's written for non-coders: plain language,
colour-coded status, click a step for details.

Every time the pipeline advances, the kit regenerates a live view for the current
feature at `docs/sdlc/<slug>/dashboard.html` with that feature's real status and
metrics baked in. Rebuild it anytime with:

```bash
bash sdlc/scripts/sdlc.sh dashboard <slug>
```

Edit `sdlc/dashboard/index.html` to change the look — it ships with the kit. See
[QUALITY.md](QUALITY.md) for how the kit measures up against the 2026 spec-driven
SDLC research.

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
| Change artifact formats     | `sdlc/templates/*.md` (canonical, tool-neutral) |
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
