#!/usr/bin/env node
/**
 * spec-sdlc-kit — install a tool-neutral, spec-driven SDLC into any repo and
 * wire up whichever AI coding tool(s) you use.
 *
 *   npx spec-sdlc-kit init                 # interactive (or all tools with --yes)
 *   npx spec-sdlc-kit init --tools=all
 *   npx spec-sdlc-kit init --tools=claude,codex,cursor,windsurf,antigravity
 *   npx spec-sdlc-kit detect               # just print the detected stack
 *   npx spec-sdlc-kit doctor               # check required tooling
 *
 * Zero dependencies. Runs on Node 16+ on Windows, macOS and Linux.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const readline = require('readline');
const { execSync } = require('child_process');

const PKG_ROOT = path.join(__dirname, '..');
const TARGET = process.cwd();

const C = {
  reset: '\x1b[0m', bold: '\x1b[1m', dim: '\x1b[2m',
  green: '\x1b[32m', yellow: '\x1b[33m', cyan: '\x1b[36m', red: '\x1b[31m',
};
const ok = (m) => console.log(`${C.green}✓${C.reset} ${m}`);
const info = (m) => console.log(`${C.cyan}•${C.reset} ${m}`);
const warn = (m) => console.log(`${C.yellow}!${C.reset} ${m}`);
const err = (m) => console.error(`${C.red}✗ ${m}${C.reset}`);

const ALL_TOOLS = ['claude', 'codex', 'cursor', 'windsurf', 'antigravity'];

// ---- arg parsing -----------------------------------------------------------
function parseArgs(argv) {
  const out = { _: [], flags: {} };
  for (const a of argv) {
    if (a.startsWith('--')) {
      const [k, v] = a.slice(2).split('=');
      out.flags[k] = v === undefined ? true : v;
    } else out._.push(a);
  }
  return out;
}

// ---- fs helpers ------------------------------------------------------------
function ensureDir(p) { fs.mkdirSync(p, { recursive: true }); }
function exists(p) { try { fs.accessSync(p); return true; } catch { return false; } }
function read(p) { return fs.readFileSync(p, 'utf8'); }
function write(p, s) { ensureDir(path.dirname(p)); fs.writeFileSync(p, s); }

function copyDir(src, dest, { force }) {
  ensureDir(dest);
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const s = path.join(src, entry.name);
    const d = path.join(dest, entry.name);
    if (entry.isDirectory()) copyDir(s, d, { force });
    else {
      if (exists(d) && !force) continue; // never clobber the user's files
      ensureDir(path.dirname(d));
      fs.copyFileSync(s, d);
    }
  }
}

// ---- stack detection -------------------------------------------------------
function detectStack() {
  const has = (f) => exists(path.join(TARGET, f));
  let stack = 'unknown', install = '', test = '', lint = '';

  if (has('package.json')) {
    let pkg = {};
    try { pkg = JSON.parse(read(path.join(TARGET, 'package.json'))); } catch {}
    const scripts = pkg.scripts || {};
    const pm = has('pnpm-lock.yaml') ? 'pnpm' : has('yarn.lock') ? 'yarn' : 'npm';
    stack = 'Node.js / JavaScript / TypeScript';
    install = `${pm} install`;
    test = scripts.test && !/no test specified/.test(scripts.test)
      ? `${pm === 'npm' ? 'npm test' : pm + ' test'}` : '';
    lint = scripts.lint ? `${pm === 'npm' ? 'npm run lint' : pm + ' lint'}` : '';
  } else if (has('pyproject.toml') || has('requirements.txt') || has('setup.cfg')) {
    stack = 'Python';
    install = has('pyproject.toml') ? 'pip install -e .' : 'pip install -r requirements.txt';
    test = 'pytest -q';
    lint = 'ruff check .';
  } else if (has('go.mod')) {
    stack = 'Go'; install = 'go mod download'; test = 'go test ./...'; lint = 'go vet ./...';
  } else if (has('Cargo.toml')) {
    stack = 'Rust'; install = 'cargo build'; test = 'cargo test'; lint = 'cargo clippy';
  } else if (has('pom.xml')) {
    stack = 'Java (Maven)'; install = 'mvn install'; test = 'mvn -q test'; lint = '';
  } else if (has('build.gradle') || has('build.gradle.kts')) {
    stack = 'Java/Kotlin (Gradle)'; install = './gradlew build'; test = './gradlew test'; lint = '';
  } else if (has('composer.json')) {
    stack = 'PHP'; install = 'composer install'; test = 'vendor/bin/phpunit'; lint = '';
  } else if (has('Gemfile')) {
    stack = 'Ruby'; install = 'bundle install'; test = 'bundle exec rspec'; lint = 'rubocop';
  }
  return { stack, install, test, lint };
}

function fill(tpl, s) {
  return tpl
    .replace(/\{\{STACK\}\}/g, s.stack || 'fill me in')
    .replace(/\{\{INSTALL_CMD\}\}/g, s.install || 'fill me in')
    .replace(/\{\{TEST_CMD\}\}/g, s.test || 'fill me in')
    .replace(/\{\{LINT_CMD\}\}/g, s.lint || 'fill me in');
}

// ---- settings.json merge ---------------------------------------------------
function mergeSettings(ours, existing) {
  const out = JSON.parse(JSON.stringify(existing));
  out.$schema = out.$schema || ours.$schema;
  out.env = Object.assign({}, ours.env, out.env); // keep user's values
  out.permissions = out.permissions || {};
  for (const key of ['allow', 'deny']) {
    const set = new Set([...(out.permissions[key] || []), ...((ours.permissions || {})[key] || [])]);
    out.permissions[key] = [...set];
  }
  // Merge hook groups, deduping by exact group signature so re-running init
  // never appends a group that is already present (idempotent).
  out.hooks = out.hooks || {};
  const sig = (g) => JSON.stringify(g);
  for (const event of Object.keys(ours.hooks || {})) {
    const groups = out.hooks[event] || [];
    const seen = new Set(groups.map(sig));
    for (const grp of ours.hooks[event] || []) {
      if (!seen.has(sig(grp))) { groups.push(grp); seen.add(sig(grp)); }
    }
    out.hooks[event] = groups;
  }
  return out;
}

// ---- tool selection --------------------------------------------------------
function expandTools(spec) {
  if (!spec || spec === true) return null;
  if (spec === 'all') return [...ALL_TOOLS];
  const map = { claude: 'claude', 'claude-code': 'claude', codex: 'codex', agents: 'codex',
    gemini: 'codex', cursor: 'cursor', windsurf: 'windsurf', codeium: 'windsurf',
    antigravity: 'antigravity' };
  const picked = new Set(); // neutral core always installs; .claude only if selected
  for (const t of String(spec).split(',').map((x) => x.trim().toLowerCase())) {
    if (map[t]) picked.add(map[t]);
  }
  return [...picked];
}

function prompt(question) {
  return new Promise((resolve) => {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    rl.question(question, (ans) => { rl.close(); resolve(ans.trim()); });
  });
}

async function chooseTools(flags) {
  const fromFlag = expandTools(flags.tools);
  if (fromFlag) return fromFlag;
  if (flags.yes || !process.stdin.isTTY) return [...ALL_TOOLS];
  console.log(`\nWhich tools should follow the spec-driven SDLC? (neutral core installs either way)`);
  console.log(`  1) Claude Code      (.claude/ — full, enforced via hooks)`);
  console.log(`  2) Codex/Gemini/+   (AGENTS.md — broadest coverage)`);
  console.log(`  3) Cursor           (.cursor/rules/)`);
  console.log(`  4) Windsurf         (.windsurf/rules/)`);
  console.log(`  5) Antigravity      (AGENTS.md + .antigravity/)`);
  const ans = await prompt(`Enter numbers (comma-separated) or "all" [all]: `);
  if (!ans || ans.toLowerCase() === 'all') return [...ALL_TOOLS];
  const pick = new Set();
  const byNum = { 1: 'claude', 2: 'codex', 3: 'cursor', 4: 'windsurf', 5: 'antigravity' };
  for (const n of ans.split(',').map((x) => x.trim())) if (byNum[n]) pick.add(byNum[n]);
  return [...pick];
}

// ---- the install -----------------------------------------------------------
async function init(flags) {
  const force = !!flags.force;
  const dry = !!flags['dry-run'];
  console.log(`\n${C.bold}spec-sdlc-kit${C.reset} — installing into ${C.dim}${TARGET}${C.reset}`);

  if (path.resolve(PKG_ROOT) === path.resolve(TARGET)) {
    warn('Target is the kit itself; nothing to install. Run this inside another repo.');
    return;
  }

  const stack = detectStack();
  info(`Detected stack: ${C.bold}${stack.stack}${C.reset}` +
    (stack.test ? `  (tests: ${stack.test})` : '  (no test command detected)'));

  const tools = await chooseTools(flags);
  info(`Tools: ${tools.join(', ')}`);
  if (dry) { warn('--dry-run: no files written.'); return; }

  const hasClaude = tools.includes('claude');

  // 1. Tool-neutral core (ALWAYS): sdlc/ = scripts + templates + PROCESS + SKILL.
  copyDir(path.join(PKG_ROOT, 'sdlc'), path.join(TARGET, 'sdlc'), { force: true });
  ok('sdlc/ installed (neutral core: scripts, templates, PROCESS, SKILL, patterns)');

  // 2. Claude Code adapter — ONLY when selected (SDLC-001).
  if (hasClaude) {
    // Source folder is 'claude-code/' in the repo; it deploys as '.claude/' in the
    // target so Claude Code still auto-loads it (required folder name, like .git).
    const srcClaude = path.join(PKG_ROOT, 'claude-code');
    const dstClaude = path.join(TARGET, '.claude');
    const settingsPath = path.join(dstClaude, 'settings.json');
    const hadSettings = exists(settingsPath);
    const existingSettings = hadSettings ? JSON.parse(read(settingsPath)) : null;
    copyDir(srcClaude, dstClaude, { force });
    if (hadSettings) {
      const ours = JSON.parse(read(path.join(srcClaude, 'settings.json')));
      write(settingsPath, JSON.stringify(mergeSettings(ours, existingSettings), null, 2) + '\n');
      ok('.claude/ installed (merged your existing settings.json)');
    } else {
      ok('.claude/ installed (agents, skills, enforcing hooks)');
    }
    fillClaudeSpecifics(path.join(dstClaude, 'CLAUDE.md'), stack);
  } else {
    info('.claude/ skipped — Claude Code not selected (neutral core + adapters still installed)');
  }

  // 3. Adapters per selected tool (stack filled in).
  const T = (f) => read(path.join(PKG_ROOT, 'templates', f));
  if (tools.includes('codex') || tools.includes('antigravity')) {
    writeIfOk(path.join(TARGET, 'AGENTS.md'), fill(T('AGENTS.md'), stack), force);
    ok('AGENTS.md written (Codex, Gemini, Antigravity, and most agents)');
  }
  if (tools.includes('cursor')) {
    writeIfOk(path.join(TARGET, '.cursor', 'rules', 'spec-sdlc.mdc'), fill(T('cursor.mdc'), stack), force);
    ok('.cursor/rules/spec-sdlc.mdc written');
  }
  if (tools.includes('windsurf')) {
    writeIfOk(path.join(TARGET, '.windsurf', 'rules', 'spec-sdlc.md'), fill(T('windsurf.md'), stack), force);
    ok('.windsurf/rules/spec-sdlc.md written');
  }
  if (tools.includes('antigravity')) {
    writeIfOk(path.join(TARGET, '.antigravity', 'rules', 'spec-sdlc.md'), fill(T('antigravity.md'), stack), force);
    ok('.antigravity/rules/spec-sdlc.md written');
  }

  // 3b. CI gate (GitHub Actions) — runs `sdlc ci` (verify + metrics) + dep scan on PRs.
  writeIfOk(path.join(TARGET, '.github', 'workflows', 'sdlc-gate.yml'), fill(T('ci-github.yml'), stack), force);
  ok('.github/workflows/sdlc-gate.yml written (CI enforces the spec gate)');

  // 4. make shell scripts executable (no-op on Windows).
  try {
    const sh = ['sdlc/scripts/sdlc.sh', 'sdlc/scripts/lib.sh'].map((f) => path.join(TARGET, f));
    if (hasClaude) {
      for (const f of ['scripts/sdlc.sh', 'hooks/lib.sh', 'hooks/session-start.sh', 'hooks/guard-bash.sh',
        'hooks/phase-gate.sh', 'hooks/format-lint.sh', 'hooks/quality-gate.sh', 'hooks/log-agent.sh']) {
        sh.push(path.join(TARGET, '.claude', f));
      }
    }
    for (const p of sh) if (exists(p)) fs.chmodSync(p, 0o755);
  } catch {}

  console.log(`\n${C.bold}Done.${C.reset} Next:`);
  console.log(`  1. Read ${C.cyan}sdlc/PROCESS.md${C.reset}${hasClaude ? ` and ${C.cyan}.claude/CLAUDE.md${C.reset}` : ''}.`);
  console.log(`  2. ${C.dim}bash sdlc/scripts/sdlc.sh doctor${C.reset}  (verify tooling)`);
  console.log(hasClaude
    ? `  3. In Claude Code: ${C.cyan}/sdlc <feature>${C.reset}.`
    : `  3. Your tool reads its adapter; drive state with ${C.cyan}bash sdlc/scripts/sdlc.sh${C.reset}.`);
  if (!exists(path.join(TARGET, '.git'))) warn('Not a git repo — `git init` so the review/release phases can diff.');
}

function writeIfOk(p, content, force) {
  if (exists(p) && !force) { warn(`kept existing ${path.relative(TARGET, p)} (use --force to overwrite)`); return; }
  write(p, content);
}

function fillClaudeSpecifics(claudeMd, stack) {
  if (!exists(claudeMd)) return;
  let txt = read(claudeMd);
  const block = `## Project specifics (auto-detected — edit as needed)
- Tech stack: ${stack.stack}
- How to run locally: ${stack.install || 'fill me in'}
- Test command: ${stack.test || 'fill me in'}
- Lint command: ${stack.lint || 'fill me in'}`;
  if (/## Project specifics/.test(txt)) {
    txt = txt.replace(/## Project specifics[\s\S]*$/, block + '\n');
  } else {
    txt = txt.trimEnd() + '\n\n' + block + '\n';
  }
  write(claudeMd, txt);
  // Also prime SDLC_TEST_CMD / SDLC_LINT_CMD if we detected them
  const settings = path.join(path.dirname(claudeMd), 'settings.json');
  if (exists(settings) && (stack.test || stack.lint)) {
    try {
      const s = JSON.parse(read(settings));
      s.env = s.env || {};
      if (stack.test && !s.env.SDLC_TEST_CMD) s.env.SDLC_TEST_CMD = stack.test;
      write(settings, JSON.stringify(s, null, 2) + '\n');
    } catch {}
  }
  ok('.claude/CLAUDE.md project specifics filled in');
}

function doctor() {
  console.log('spec-sdlc-kit doctor:');
  const check = (cmd, label, required) => {
    try { execSync(process.platform === 'win32' ? `where ${cmd}` : `command -v ${cmd}`,
      { stdio: 'ignore' }); ok(label); return true; }
    catch { (required ? err : warn)(`${label} not found`); return false; }
  };
  const hasBash = check('bash', 'bash', true);
  const hasJq = check('jq', 'jq (fast JSON)', false);
  const hasPy = check('python3', 'python3', false) || check('python', 'python', false);
  check('git', 'git', false);
  if (!hasJq && !hasPy) err('You need jq OR python3 for the hooks to parse state.');
  if (!hasBash) err('bash is required (on Windows it ships with Git for Windows).');
}

function usage() {
  console.log(`spec-sdlc-kit — spec-driven SDLC for any AI coding tool

Usage:
  npx spec-sdlc-kit init [--tools=all|claude,codex,cursor,windsurf,antigravity] [--yes] [--force] [--dry-run]
  npx spec-sdlc-kit detect
  npx spec-sdlc-kit doctor

Always installs the Claude Code layer (.claude/) and the tool-neutral core
(sdlc/PROCESS.md + templates). Adapters are generated for the tools you pick.`);
}

(async function main() {
  const { _, flags } = parseArgs(process.argv.slice(2));
  const cmd = _[0] || 'init';
  try {
    if (cmd === 'init') await init(flags);
    else if (cmd === 'detect') console.log(detectStack());
    else if (cmd === 'doctor') doctor();
    else if (cmd === 'help' || flags.help) usage();
    else { err(`Unknown command: ${cmd}`); usage(); process.exit(1); }
  } catch (e) {
    err(e && e.message ? e.message : String(e));
    process.exit(1);
  }
})();
