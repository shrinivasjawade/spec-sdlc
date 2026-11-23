#!/usr/bin/env node
/**
 * Zero-dependency test suite for spec-sdlc-kit.
 * Covers the installer (bin/cli.js) and the state/governance helper
 * (sdlc/scripts/sdlc.sh). Maps to the acceptance criteria in ISSUES.md.
 *
 *   node test/run.js        # or: npm test
 */
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const PKG = path.join(__dirname, '..');
const CLI = path.join(PKG, 'bin', 'cli.js');
let pass = 0, fail = 0;
const fails = [];

function ok(cond, msg) {
  if (cond) { pass++; }
  else { fail++; fails.push(msg); console.log(`  ✗ ${msg}`); }
}
function tmp() { return fs.mkdtempSync(path.join(os.tmpdir(), 'sdlc-test-')); }
function exists(p) { try { fs.accessSync(p); return true; } catch { return false; } }
function write(p, s) { fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, s); }

function cli(args, cwd) {
  const r = spawnSync(process.execPath, [CLI, ...args], { cwd, encoding: 'utf8' });
  return { code: r.status, out: (r.stdout || '') + (r.stderr || '') };
}
function sh(args, cwd) {
  const r = spawnSync('bash', ['sdlc/scripts/sdlc.sh', ...args], { cwd, encoding: 'utf8' });
  return { code: r.status, out: (r.stdout || '') + (r.stderr || '') };
}
function section(name) { console.log(`\n# ${name}`); }

// ---------------------------------------------------------------- installer
section('installer: --dry-run makes no changes (AC-002.1)');
{
  const d = tmp(); write(path.join(d, 'package.json'), '{"name":"x"}');
  cli(['init', '--tools=all', '--yes', '--dry-run'], d);
  ok(!exists(path.join(d, 'sdlc')), 'dry-run did not create sdlc/');
  ok(!exists(path.join(d, '.claude')), 'dry-run did not create .claude/');
  ok(!exists(path.join(d, 'AGENTS.md')), 'dry-run did not create AGENTS.md');
}

section('installer: codex-only skips .claude/ (AC-001.1), installs core + adapter');
{
  const d = tmp(); write(path.join(d, 'package.json'), '{"name":"x"}');
  cli(['init', '--tools=codex', '--yes'], d);
  ok(!exists(path.join(d, '.claude')), 'codex install did NOT create .claude/');
  ok(exists(path.join(d, 'sdlc', 'scripts', 'sdlc.sh')), 'neutral core installed');
  ok(exists(path.join(d, 'AGENTS.md')), 'AGENTS.md adapter installed');
  ok(exists(path.join(d, 'sdlc', 'PROCESS.md')), 'PROCESS.md installed');
  ok(exists(path.join(d, 'sdlc', 'SKILL.md')), 'neutral SKILL.md installed (SDLC-006)');
}

section('installer: claude installs .claude/ + core (AC-001.2); multi-tool (AC-001.3)');
{
  const d = tmp(); write(path.join(d, 'go.mod'), 'module x\n');
  cli(['init', '--tools=claude', '--yes'], d);
  ok(exists(path.join(d, '.claude', 'agents', 'verifier.md')), 'claude layer + verifier agent installed');
  ok(exists(path.join(d, 'sdlc', 'scripts', 'sdlc.sh')), 'neutral core installed with claude');

  const d2 = tmp(); write(path.join(d2, 'package.json'), '{"name":"x"}');
  cli(['init', '--tools=cursor,windsurf', '--yes'], d2);
  ok(exists(path.join(d2, '.cursor', 'rules', 'spec-sdlc.mdc')), 'cursor adapter present (AC-002.3)');
  ok(exists(path.join(d2, '.windsurf', 'rules', 'spec-sdlc.md')), 'windsurf adapter present (AC-002.3)');
  ok(!exists(path.join(d2, '.claude')), 'cursor+windsurf did not create .claude/');
  ok(!exists(path.join(d2, 'AGENTS.md')), 'cursor+windsurf did not create AGENTS.md');
}

section('installer: existing files preserved without --force (AC-002.2)');
{
  const d = tmp(); write(path.join(d, 'package.json'), '{"name":"x"}');
  write(path.join(d, 'AGENTS.md'), 'SENTINEL-KEEP-ME');
  cli(['init', '--tools=codex', '--yes'], d);
  ok(fs.readFileSync(path.join(d, 'AGENTS.md'), 'utf8').includes('SENTINEL'), 'existing AGENTS.md preserved');
  cli(['init', '--tools=codex', '--yes', '--force'], d);
  ok(!fs.readFileSync(path.join(d, 'AGENTS.md'), 'utf8').includes('SENTINEL'), '--force overwrote AGENTS.md');
}

section('installer: idempotent hooks on re-install');
{
  const d = tmp(); write(path.join(d, 'package.json'), '{"name":"x"}');
  cli(['init', '--tools=claude', '--yes'], d);
  cli(['init', '--tools=claude', '--yes'], d);
  const s = JSON.parse(fs.readFileSync(path.join(d, '.claude', 'settings.json'), 'utf8'));
  ok(s.hooks.PreToolUse.length === 2, `PreToolUse hooks not duplicated (got ${s.hooks.PreToolUse.length})`);
}

// ---------------------------------------------------------------- state helper
section('state helper: invalid phase + trace/verify/metrics gates (AC-002.4)');
{
  const d = tmp(); write(path.join(d, 'package.json'), '{"name":"x"}');
  cli(['init', '--tools=codex', '--yes'], d);
  sh(['start', 'demo'], d);
  ok(sh(['phase', 'nonsense'], d).code !== 0, 'invalid phase exits non-zero');

  const fd = path.join(d, 'docs', 'sdlc', 'demo');
  // gappy spec/design: NFR-1 unmapped, AC-1.2 has no test, one open question
  write(path.join(fd, '01-requirements.md'),
    '# Spec\n- **AC-1.1** WHEN x the system SHALL y.\n- **AC-1.2** IF z the system SHALL w.\n| NFR-1 | SHALL be fast |\n## Open questions\n1. which db?\n');
  write(path.join(fd, '02-design.md'),
    '## 8. Traceability\n| Req | Task | Test |\n|--|--|--|\n| AC-1.1 | T1 | `a.test` |\n| AC-1.2 | T2 | |\n');
  ok(sh(['trace', 'demo'], d).code !== 0, 'trace fails on unmapped NFR-1');
  ok(sh(['verify', 'demo'], d).code !== 0, 'verify fails on missing test/row');
  ok(exists(path.join(fd, 'trace.json')), 'verify emitted trace.json contract');
  ok(sh(['metrics', 'demo'], d).code !== 0, 'metrics release gate FAILs on open question');

  // now a complete, correct feature -> all pass
  write(path.join(fd, '01-requirements.md'),
    '# Spec\n- **AC-1.1** WHEN x the system SHALL y.\n## Open questions\n_None._\n');
  write(path.join(fd, '02-design.md'),
    '## 7. Tasks\n- [x] T1 (covers AC-1.1)\n## 8. Traceability\n| Req | Task | Test |\n|--|--|--|\n| AC-1.1 | T1 | `a.test` |\n');
  ok(sh(['trace', 'demo'], d).code === 0, 'trace passes when complete');
  ok(sh(['verify', 'demo'], d).code === 0, 'verify passes when complete');
  ok(sh(['metrics', 'demo'], d).code === 0, 'metrics gate PASSes when complete');
}

// ---------------------------------------------------------------- dashboard
section('dashboard: auto-generated on state change + live snapshot injected');
{
  const d = tmp(); write(path.join(d, 'package.json'), '{"name":"x"}');
  cli(['init', '--tools=codex', '--yes'], d);
  sh(['start', 'viz'], d);
  const dash = path.join(d, 'docs', 'sdlc', 'viz', 'dashboard.html');
  ok(exists(dash), 'dashboard.html auto-generated on start (skill use -> HTML)');
  const fd = path.join(d, 'docs', 'sdlc', 'viz');
  write(path.join(fd, '01-requirements.md'), '# Spec\n- **AC-1.1** WHEN x the system SHALL y.\n## Open questions\n_None._\n');
  write(path.join(fd, '02-design.md'), '## 8. Traceability\n| Req | Task | Test |\n|--|--|--|\n| AC-1.1 | T1 | `a.test` |\n');
  sh(['dashboard', 'viz'], d);
  const html = fs.readFileSync(dash, 'utf8');
  ok(/window\.SDLC_STATE = \{/.test(html), 'dashboard carries an injected live snapshot');
  ok(html.includes('"gate":"PASS"'), 'dashboard snapshot reflects the passing release gate');
}

// ---------------------------------------------------------------- summary
console.log(`\n${'='.repeat(50)}`);
console.log(`${pass} passed, ${fail} failed`);
if (fail) { console.log('FAILURES:\n- ' + fails.join('\n- ')); process.exit(1); }
console.log('All tests passed.');
