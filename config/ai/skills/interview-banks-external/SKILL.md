---
name: interview-banks-external
description: >-
  Researches, authors, expands, formats, and verifies technical interview
  question banks (such as Security Engineer and Network Engineer guides) in
  standalone external Git repositories using public internet sources, primary
  open specifications, and standard open-source toolchains. Use when discovering
  interview topics from public sources, authoring or auditing external Markdown
  or MkDocs interview banks, verifying CVE and IETF RFC citations, or testing
  embedded coding solutions and code-review snippets in an external environment.
  Don't use when maintaining internal monorepo interview files that rely on
  proprietary shortlinks or internal VCS linters, or for generic LeetCode-style
  puzzle grinding without domain scenarios.
---

# External Technical Interview Bank Authoring & Verification

Build, expand, and audit high-signal engineering interview question banks in any
standard Git, GitHub Flavored Markdown (GFM), or MkDocs Material environment
using exclusively public specifications and standard open-source tools (`git`,
`python3`, `pytest`, `gcc`, `g++`, `go`, `node`).

## Supported Bank Layouts

Both layouts are supported by the bundled verifier scripts:

Layout Mode                  | File Organization                                                                      | Recommended When
:--------------------------- | :------------------------------------------------------------------------------------- | :---------------
**Modular Docs / MkDocs**    | `docs/<role>/<domain>/<ID>-<slug>.md` + standalone `code/<role>/<ID>/`                 | Repositories rendered with GitHub Pages / MkDocs Material, or banks exceeding GitHub's `512 KB` single-file preview limit.
**Domain / Single-File GFM** | `<role>-interviews.md` with `## 2. Quick Question Index` and `### [ID] Title` sections | Compact portable Markdown guides under `500 KB` per file.

## Five-Stage Execution Workflow

Follow all five stages in order when adding or expanding questions. Never skip
primary-source retrieval, compiler/test execution, or the critic pass.

### Stage 1: Public Topic Discovery (Zero Verbatim Copying)

1.  Read [source-and-critique-guide.md](references/source-and-critique-guide.md)
    before running web queries.
2.  Search permissive public sources (GitHub repositories explicitly licensed
    under `MIT`, `Apache-2.0`, or `CC-BY-4.0`, public engineering postmortems,
    USENIX / Black Hat / NANOG / KubeCon talks, OWASP / NIST / CNCF matrices,
    and public job descriptions) **only to extract an abstract topic gap
    matrix**: `(domain, core_mechanism, real_world_failure_mode, level_span)`.
3.  Never scrape login-gated or anti-bot sites, never copy or paraphrase prose
    from unlicensed repositories, and never reproduce company-attributed leaked
    interview prompts.

### Stage 2: Primary-Specification Grounding (Fetch Before Writing)

1.  Fetch and read the authoritative primary specification (`rfc-editor.org`,
    `datatracker.ietf.org`, `csrc.nist.gov`, `cveawg.mitre.org`, `w3.org`,
    `man7.org`, `sqlite.org`, or official language/cloud documentation)
    **before** drafting expected answers or code.
2.  Never cite a `CVE-YYYY-NNNN` identifier, `RFC` number, bit width, sysctl
    value, or compiler flag from parametric memory alone. Every `CVE` and `RFC`
    citation must match its live official record.
3.  Use RFC 2606 reserved domains (`corp.example`, `api.example.com`), RFC 5737
    IPv4 documentation blocks (`192.0.2.0/24`, `198.51.100.0/24`,
    `203.0.113.0/24`), and RFC 3849 IPv6 prefixes (`2001:db8::/32`) in all
    prompts, logs, and tests.

### Stage 3: Scenario, Answer, Code & Rubric Authoring

Every question must include all 10 required components:

1.  **Domain / Focus Area** metadata (bullet or YAML frontmatter `domain`).
2.  **Target Levels** (`L2–L7` industry levels for SE, `L3–L7` for NE).
3.  **Difficulty Tier** (`Foundational`, `Intermediate`, `Senior`, or
    `Principal`).
4.  **Applicable Rounds** (`Phone Screen`, `Domain Depth`, `Code Review`,
    `System Design`, `DFIR`, or `Practical Coding`).
5.  **Synthesized From** (explicit public standards: `IETF RFC`, `NIST`,
    `OWASP`, `MITRE CWE/ATT&CK`, `CNCF`).
6.  **Prompt**: Realistic `>` scenario blockquote. Place any fenced code blocks
    (` ```python `, ` ```go `, ` ```cpp `, ` ```c `, ` ```text `) at top level
    **outside** `>` blockquotes so Markdown formatters never mangle blank lines.
7.  **Follow-up Questions (Tiered by Level)**: `4` numbered follow-ups prefixed
    by level brackets (`1. **[L2–L3]**` .. `4. **[L5–L6]**`) whose minimum and
    maximum levels sit strictly within `Target Levels`.
8.  **Expected Answers & Key Technical Signals**: Multi-tier technical breakdown
    (`Core / Baseline`, `Intermediate Depth`, `Senior / Staff Depth`) answering
    **every** sub-question posed in the Prompt and Follow-ups. For coding
    questions (`PC-*` / `SC-*`), include a tested Python 3 stdlib reference
    implementation (or transclude `--8<-- "code/..."` in MkDocs mode).
9.  **Rubric Calibration**: Standard single-line GFM 3-column pipe table
    (`| Level | Solid Signal | Distinguishing / Outstanding Signal |`) with at
    least `3` strictly ascending, **non-overlapping** level rows covering the
    full `Target Levels` span (never place `L4` in both `L3–L4` and `L4–L5`, and
    never place raw `|` inside inline code spans in table cells).
10. **Red Flags**: `2–3` concrete anti-patterns (e.g., regex denylists instead
    of structural parsers, ignoring base-rate precision math).

In self-study / MkDocs repos, wrap items `8–10` in a collapsible `<details>`
block (or `??? success "Expected Answers, Rubric & Red Flags"`) so readers can
work through the Prompt and Follow-ups without spoilers.

### Stage 4: Deterministic Local Verification Gate

Run both bundled Python 3 stdlib verifiers located in `scripts/` relative to
this `SKILL.md` file:

```bash
# 1. Structural, GFM table, rubric non-overlap, Python exec & C/C++/Go/JS syntax gate:
python3 <skill_dir>/scripts/verify_external_banks.py <path_to_md_file_or_dir>

# 2. Public CVE Services v2.1 & IETF Datatracker RFC citation verification:
python3 <skill_dir>/scripts/verify_public_specs.py <path_to_md_file_or_dir>
```

For every newly added or modified `PC-*` or `SC-*` coding implementation, also
execute a dedicated `unittest` or `pytest` suite exercising valid inputs,
malformed inputs, Unicode/ASCII edge cases, out-of-order timestamps, and
adversarial bypass payloads (such as two-stage symlink chains, non-ASCII HMAC
inputs, or bracket-indexed template expressions).

### Stage 5: Isolated Hostile Critic Pass

Before concluding any authoring or expansion task, spawn a fresh-context
read-only review subagent supplied **only** with the generated question/code
files, the fetched primary specs, and Part 2 of
[source-and-critique-guide.md](references/source-and-critique-guide.md). Instruct
the critic to:

1.  Construct concrete inputs that crash or bypass `PC-*` / `SC-*` reference
    implementations.
2.  Verify that every vulnerability claimed in `CR-*` code-review snippets is
    dynamically reachable on 64-bit targets and that recommended fixes do not
    introduce subtle regressions.
3.  Falsify protocol, cryptographic, cloud IAM, and kernel claims against the
    primary specification.

Fix every confirmed finding and re-run Stage 4 until both verifier scripts exit
`0`.
