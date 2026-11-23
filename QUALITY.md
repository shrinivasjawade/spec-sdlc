# Quality benchmark — spec-sdlc-kit vs. the 2026 spec-driven SDLC literature

This kit was checked against recent research on spec-driven development (SDD) and
AI-native / agentic SDLCs. The goal is honesty about what the kit does well and where
it still has gaps, using the literature's own criteria.

> Papers are 2026 arXiv preprints and vendor/analyst notes — not all peer-reviewed —
> so treat their empirical claims with caution. Sources are listed at the bottom.

## Where the kit sits on each paper's criteria

| Literature criterion | What spec-sdlc-kit does | Status |
|----------------------|-------------------------|--------|
| **Spec rigor levels** — *spec-first → spec-anchored → spec-as-source* (Practitioner guide, 2602.00180) | The spec (`01-requirements.md`) is the source of truth; design, code and tests all trace to its IDs. Code is written *from* and *verified against* the spec, not generated from it. | **Spec-anchored**, moving toward spec-as-source via the `verify` contract. |
| **Verifying requirements satisfaction & traceability** — the survey (2609.05667) names this as a *missing* evaluation capability | `trace` (table-scoped), `verify` (every AC/NFR → task **and** test, emits `trace.json`), and `metrics` **Spec Fidelity** make satisfaction measurable and machine-checkable. | **Strong** — directly implements what the survey says the field lacks. |
| **Spec ↔ code drift** — named as an open problem (2609.05667) | Change control re-opens Gate 1/2 on spec/design changes; provenance records the spec's git revision per run; `verify`/`trace` re-run after edits. | **Addressed** (process + tooling). |
| **Governance metrics** — Ambiguity Tax, Spec Fidelity, SER, TCI + repair multiplier φ (SDAD, 2608.20341) | `metrics` computes Spec Fidelity, Ambiguity Tax (open questions + vague terms), AC Test Coverage, and TCI with φ (fix-loop re-entries); a **release gate** enforces thresholds. | **Implemented.** |
| **Independent / adversarial verification** (SDAD; AI-native playbook) | A fresh-context `verifier` agent checks implementation against the spec in the review phase, separate from the author and reviewers. | **Implemented.** |
| **Auditable provenance** (AI-native playbook; SDAD "auditable provenance") | `provenance.jsonl` per feature (agent, phase, session, spec revision); each artifact traces to who/what produced it; git commit chain is the audit trail. | **Implemented.** |
| **Team-scale throughput & review capacity** — the "productivity paradox" (2609.00252) | Human attention concentrated at three gates; automated verification + metrics reduce per-line review load; provenance separates agent from human actions. | **Partial** — process addresses it; no team-level analytics yet. |
| **Human-in-the-loop upfront definition** — goals, constraints, acceptance criteria (Gartner) | EARS acceptance criteria + NFRs + out-of-scope + open questions are mandatory in the spec and gated by a human before design. | **Implemented.** |
| **When is SDD worth the overhead?** — decision framework (2602.00180) | CLAUDE.md notes small fixes skip the pipeline; `PROCESS.md` now carries a short "When to use" guide and the three rigor levels. | **Light** — guidance added, not a formal scorer. |
| **Visualization / legibility for non-experts** (not emphasized in the papers) | A dependency-free `sdlc/dashboard/` pipeline map, auto-generated per feature with a live governance scorecard. | **Beyond the literature.** |

## Honest gaps (roadmap)
1. **Not yet spec-as-source.** The kit verifies code against the spec but does not
   *generate* code from a formal spec. Full spec-as-source would need a formal,
   executable spec format — a larger step than the current markdown + `trace.json`.
2. **No CI eval harness.** The AI-native playbook recommends running 20–50 real
   tasks as an eval suite on changes to the agent config. The kit tests its own
   tooling (`npm test`) but ships no feature-level eval runner.
3. **No team-level metrics.** Per-feature governance exists; cross-feature/DORA-style
   trends (first-pass merge rate, review time, change-failure rate) are not collected.
4. **Benchmarks are relative.** There is still no shared, external benchmark for
   requirements-satisfaction (the survey's point); the kit's metrics are internally
   consistent but not validated against one.

## Summary
On the capability the requirements-engineering survey calls out as missing —
**measurable requirements satisfaction and traceability** — the kit is unusually
complete: table-scoped tracing, a machine-readable contract, a governance scorecard,
independent verification, and drift control. It sits at the **spec-anchored** rigor
level with a concrete path toward spec-as-source, and adds a visualization layer the
papers don't cover. The main open work is feature-level evals and team-scale metrics.

## Sources
- [SDAD: Spec-Driven Agentic Development for the AI-Native SDLC (arXiv 2608.20341)](https://arxiv.org/abs/2608.20341)
- [Spec-Driven Development for Agentic Software Engineering (arXiv 2609.00252)](https://arxiv.org/pdf/2609.00252)
- [Spec-Driven Development — practitioner guide / rigor levels (arXiv 2602.00180)](https://arxiv.org/abs/2602.00180)
- [The Impact of GenAI on the Future of Requirements Engineering (arXiv 2609.05667)](https://arxiv.org/pdf/2609.05667)
- [From Prompt to Process: a Process Taxonomy of AI Software Development Agents (arXiv 2606.04967)](https://arxiv.org/pdf/2606.04967)
- [An AI-led SDLC — Microsoft Tech Community](https://techcommunity.microsoft.com/t5/apps-on-azure-blog/an-ai-led-sdlc-building-an-end-to-end-agentic-software/ba-p/4491896)
- [Anthropic — The AI-native SDLC playbook](https://claude.com/resources/articles/the-ai-native-sdlc-playbook)
