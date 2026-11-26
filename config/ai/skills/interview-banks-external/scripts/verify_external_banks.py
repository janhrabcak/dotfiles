#!/usr/bin/env python3
"""Portable structure, GFM, rubric, and code verifier for external banks."""

import ast
from collections.abc import Sequence
import dataclasses
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import textwrap


@dataclasses.dataclass(frozen=True)
class QuestionRecord:
  """Parsed representation of one interview question block.

  Attributes:
    qid: Question identifier such as 'WEB-01' or 'SC-03'.
    slug: Heading anchor slug (explicit `{#slug}` or standard GFM slug).
    block: Full Markdown text of the question section.
    min_level: Minimum target level integer (e.g. 2 or 3).
    max_level: Maximum target level integer (e.g. 6 or 7).
  """

  qid: str
  slug: str
  block: str
  min_level: int
  max_level: int


_REQUIRED_MARKERS: tuple[str, ...] = (
    "Prompt",
    "Follow-up Questions",
    "Expected Answers",
    "Rubric Calibration",
    "Red Flags",
)

_NON_INCLUSIVE_PATTERNS: tuple[str, ...] = (
    r"\bwhite[\s-]?box\b",
    r"\bwhitelist\w*\b",
    r"\bblacklist\w*\b",
    r"\bsanity[\s-]+check\w*\b",
)

_SEC2_BLOCK_RE = re.compile(
    r"## 2\. Quick Question Index\n(.*?)\n## 3\.", re.DOTALL
)
_SEC2_LINK_RE = re.compile(r"\[`?([A-Z]+-\d+)`?\]\(#([a-z0-9-]+)\)")
_H3_QUESTION_RE = re.compile(
    r"^### \[([A-Z]+-\d+)\] (.+?)(?: \{#([a-z0-9-]+)\})?\s*$", re.MULTILINE
)
_FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)
_BQ_FENCE_RE = re.compile(r"^\s*>\s*```")
_HR_RE = re.compile(r"^-{3,}\s*$")
_CODE_FENCE_RE = re.compile(r"```([a-zA-Z0-9_+-]*)\n(.*?)```", re.DOTALL)
_SNIPPET_INCLUDE_RE = re.compile(r'^--8<--\s+"([^"]+)"', re.MULTILINE)
_META_BULLET_RE = re.compile(r"^\*\s+\*\*([^*]+)\*\*:", re.MULTILINE)
_LEVEL_NUM_RE = re.compile(r"L(\d)")


def _gfm_slug(heading_text: str) -> str:
  """Computes a GitHub Flavored Markdown anchor slug from heading text."""
  cleaned = heading_text.strip().lower()
  cleaned = re.sub(r"[^\w\s-]", "", cleaned)
  cleaned = re.sub(r"\s+", "-", cleaned)
  return cleaned


def _extract_levels(label: str) -> list[int]:
  """Extracts sorted integer levels from a label such as 'L3-L6'."""
  return sorted({int(m) for m in _LEVEL_NUM_RE.findall(label)})


def _split_gfm_table_rows(block_text: str) -> list[list[str]]:
  """Parses pipe-table rows (supporting both single-line GFM and wrapped)."""
  rows: list[list[str]] = []
  current: list[str] | None = None
  for raw_line in block_text.splitlines():
    stripped = raw_line.strip()
    if stripped.startswith("|") and stripped.endswith("|"):
      cells = [cell.strip() for cell in stripped[1:-1].split("|")]
      if all(set(cell) <= {":", "-", " "} for cell in cells):
        continue
      if current is not None:
        rows.append(current)
      current = cells
    elif stripped.startswith(":") and stripped.endswith(":") and current:
      cont = [cell.strip() for cell in re.split(r"(?<!\\):", stripped[1:-1])]
      if len(cont) == len(current):
        for idx, extra in enumerate(cont):
          if extra:
            current[idx] = f"{current[idx]} {extra}".strip()
    else:
      if current is not None:
        rows.append(current)
        current = None
  if current is not None:
    rows.append(current)
  return rows


def _check_backticks(text: str) -> tuple[list[str], str | None]:
  """Pairs CommonMark backtick runs; returns code spans and optional error."""
  runs = list(re.finditer(r"`+", text))
  if not runs:
    return [], None
  spans: list[str] = []
  idx = 0
  while idx < len(runs):
    open_m = runs[idx]
    width = len(open_m.group(0))
    close_idx = idx + 1
    while close_idx < len(runs) and len(runs[close_idx].group(0)) != width:
      close_idx += 1
    if close_idx == len(runs):
      near = text[max(0, open_m.start() - 20) : open_m.end() + 30]
      return spans, f"unmatched {width}-backtick delimiter near {near!r}"
    spans.append(text[open_m.end() : runs[close_idx].start()])
    idx = close_idx + 1
  return spans, None


def _check_markdown_hygiene(lines: list[str], label: str) -> list[str]:
  """Checks code fences, tables, backtick runs, and duplicate rules."""
  errors: list[str] = []
  fence_count = 0
  in_fence = False
  prev_hr = False
  para_lines: list[str] = []
  para_start = 1
  table_lines: list[str] = []
  table_start = 1

  def flush_para() -> None:
    if not para_lines:
      return
    _, bt_err = _check_backticks("\n".join(para_lines))
    if bt_err:
      errors.append(f"{label}:{para_start}: {bt_err}")
    para_lines.clear()

  def flush_table() -> None:
    if not table_lines:
      return
    for row in _split_gfm_table_rows("\n".join(table_lines)):
      for cell in row:
        spans, bt_err = _check_backticks(cell)
        if bt_err:
          errors.append(f"{label}:{table_start}: table cell {bt_err}")
          continue
        for span in spans:
          if "|" in span:
            errors.append(
                f"{label}:{table_start}: raw '|' inside table code span"
            )
    table_lines.clear()

  for line_num, raw_line in enumerate(lines, 1):
    stripped = raw_line.strip()
    if _BQ_FENCE_RE.match(raw_line):
      flush_para()
      flush_table()
      if not in_fence:
        errors.append(
            f"{label}:{line_num}: fenced code block inside '>' blockquote "
            "is forbidden; place fences at top level"
        )
      in_fence = not in_fence
      fence_count += 1
      prev_hr = False
      continue
    if stripped.startswith("```"):
      flush_para()
      flush_table()
      in_fence = not in_fence
      fence_count += 1
      prev_hr = False
      continue
    if in_fence:
      continue
    if not stripped:
      flush_para()
      flush_table()
      continue
    if _HR_RE.match(stripped):
      flush_para()
      flush_table()
      if prev_hr:
        errors.append(f"{label}:{line_num}: duplicate consecutive rule")
      prev_hr = True
      continue
    prev_hr = False
    if re.match(r"^ {4,}>", raw_line):
      errors.append(
          f"{label}:{line_num}: accidental indented '>' blockquote inside list"
      )
    is_table = (stripped.startswith("|") and stripped.endswith("|")) or (
        bool(table_lines)
        and stripped.startswith(":")
        and stripped.endswith(":")
    )
    if is_table:
      flush_para()
      if not table_lines:
        table_start = line_num
      table_lines.append(raw_line)
    else:
      flush_table()
      if not para_lines:
        para_start = line_num
      para_lines.append(raw_line)

  flush_para()
  flush_table()
  if fence_count % 2 != 0:
    errors.append(f"{label}: unclosed fenced code block ({fence_count} fences)")
  return errors


def _syntax_check_snippet(lang: str, code: str, label: str) -> str | None:
  """Runs available local toolchains to syntax-check review snippets."""
  norm = lang.lower()
  if norm in ("py", "python"):
    try:
      ast.parse(code, filename=label)
    except SyntaxError as exc:
      return f"{label}: Python SyntaxError: {exc}"
    return None

  if norm == "c" and shutil.which("gcc"):
    # Ignore pseudo-ellipsis fragments explicitly marked with `...`.
    if "\n...\n" in code or code.strip().startswith("..."):
      return None
    preamble = (
        "#include <stdbool.h>\n#include <stddef.h>\n#include <stdint.h>\n"
        "#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n"
    )
    with tempfile.NamedTemporaryFile(suffix=".c", mode="w") as tmp:
      tmp.write(preamble + code)
      tmp.flush()
      proc = subprocess.run(
          ["gcc", "-std=c11", "-fsyntax-only", tmp.name],
          capture_output=True,
          text=True,
          check=False,
      )
      if proc.returncode != 0:
        first_err = proc.stderr.strip().splitlines()[0]
        return f"{label}: gcc syntax check failed: {first_err}"

  if norm in ("cpp", "c++", "cc") and shutil.which("g++"):
    with tempfile.NamedTemporaryFile(suffix=".cpp", mode="w") as tmp:
      tmp.write(code)
      tmp.flush()
      proc = subprocess.run(
          ["g++", "-std=c++20", "-fsyntax-only", tmp.name],
          capture_output=True,
          text=True,
          check=False,
      )
      if proc.returncode != 0:
        first_err = proc.stderr.strip().splitlines()[0]
        return f"{label}: g++ syntax check failed: {first_err}"

  if norm in ("go", "golang") and shutil.which("gofmt"):
    proc = subprocess.run(
        ["gofmt", "-e"],
        input=code,
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
      first_err = proc.stderr.strip().splitlines()[0]
      return f"{label}: gofmt syntax check failed: {first_err}"

  if norm in ("js", "javascript") and shutil.which("node"):
    with tempfile.NamedTemporaryFile(suffix=".js", mode="w") as tmp:
      tmp.write(code)
      tmp.flush()
      proc = subprocess.run(
          ["node", "--check", tmp.name],
          capture_output=True,
          text=True,
          check=False,
      )
      if proc.returncode != 0:
        first_err = proc.stderr.strip().splitlines()[0]
        return f"{label}: node syntax check failed: {first_err}"

  return None


def _verify_question_record(
    rec: QuestionRecord, label: str, repo_root: pathlib.Path
) -> list[str]:
  """Verifies 10-part completeness, rubric calibration, and code blocks."""
  errors: list[str] = []
  for marker in _REQUIRED_MARKERS:
    if marker not in rec.block:
      errors.append(f"{label} [{rec.qid}]: missing section {marker!r}")

  fu_m = re.search(
      r"Follow-up Questions.*?\n(.*?)Expected Answers", rec.block, re.DOTALL
  )
  fu_tags = (
      re.findall(r"\*\*\[?(L\d[^\]]*?)\]?\*\*", fu_m.group(1)) if fu_m else []
  )
  if len(fu_tags) < 4:
    errors.append(
        f"{label} [{rec.qid}]: expected >=4 tiered follow-ups, "
        f"found {len(fu_tags)}"
    )
  fu_nums: list[int] = []
  for tag in fu_tags:
    fu_nums.extend(_extract_levels(tag))
  if fu_nums and (min(fu_nums) < rec.min_level or max(fu_nums) > rec.max_level):
    errors.append(
        f"{label} [{rec.qid}]: follow-up levels {fu_tags} fall outside "
        f"Target Levels L{rec.min_level}-L{rec.max_level}"
    )

  rub_m = re.search(
      r"Rubric Calibration.*?\n(.*?)Red Flags", rec.block, re.DOTALL
  )
  rub_rows = _split_gfm_table_rows(rub_m.group(1)) if rub_m else []
  data_rows = rub_rows[1:] if len(rub_rows) > 1 else []
  if len(data_rows) < 3:
    errors.append(
        f"{label} [{rec.qid}]: expected >=3 rubric rows, found {len(data_rows)}"
    )
  else:
    seen_levels: dict[int, str] = {}
    prev_max = 0
    for row in data_rows:
      nums = _extract_levels(row[0])
      if not nums:
        errors.append(
            f"{label} [{rec.qid}]: rubric row missing level label: {row[0]!r}"
        )
        continue
      r_min, r_max = min(nums), max(nums)
      for lv in range(r_min, r_max + 1):
        if lv in seen_levels:
          errors.append(
              f"{label} [{rec.qid}]: overlapping rubric level L{lv} in "
              f"{seen_levels[lv]} and {row[0]}"
          )
        seen_levels[lv] = row[0]
      if r_min < prev_max:
        errors.append(f"{label} [{rec.qid}]: non-ascending rubric row {row[0]}")
      prev_max = r_max
    if seen_levels and (
        min(seen_levels) > rec.min_level or max(seen_levels) < rec.max_level
    ):
      errors.append(
          f"{label} [{rec.qid}]: rubric L{min(seen_levels)}-L{max(seen_levels)}"
          f" does not cover L{rec.min_level}-L{rec.max_level}"
      )

  # Check fenced snippets and execute PC-*/SC-* Python implementations.
  fenced = _CODE_FENCE_RE.findall(rec.block)
  transcluded_py: list[str] = []
  for rel_inc in _SNIPPET_INCLUDE_RE.findall(rec.block):
    inc_path = (repo_root / rel_inc).resolve()
    if not inc_path.is_file():
      errors.append(
          f"{label} [{rec.qid}]: missing transcluded file {rel_inc!r}"
      )
    elif inc_path.suffix == ".py":
      transcluded_py.append(inc_path.read_text(encoding="utf-8"))

  if rec.qid.startswith("CR-"):
    for s_idx, (lang, raw_code) in enumerate(fenced):
      dedented = textwrap.dedent(raw_code)
      err = _syntax_check_snippet(lang, dedented, f"{label}:{rec.qid}:{s_idx}")
      if err:
        errors.append(err)

  if rec.qid.startswith(("PC-", "SC-")):
    py_blocks = [
        textwrap.dedent(code)
        for lang, code in fenced
        if lang.lower() in ("py", "python")
    ] + transcluded_py
    if not py_blocks:
      errors.append(
          f"{label} [{rec.qid}]: coding question missing Python implementation"
      )
    else:
      namespace: dict[str, object] = {}
      for s_idx, py_code in enumerate(py_blocks):
        code_name = f"{label}:{rec.qid}:{s_idx}"
        try:
          compiled = compile(
              ast.parse(py_code, filename=code_name), code_name, "exec"
          )
          # Executes reference solutions to catch syntax/import/runtime typos.
          exec(compiled, namespace)  # pylint: disable=exec-used
        except Exception as exc:  # pylint: disable=broad-exception-caught
          errors.append(
              f"{label} [{rec.qid}] block {s_idx} failed execution: "
              f"{type(exc).__name__}: {exc}"
          )
  return errors


def _parse_frontmatter_question(
    text: str, file_path: pathlib.Path
) -> tuple[QuestionRecord | None, list[str]]:
  """Parses a modular per-question Markdown file with YAML frontmatter."""
  fm_m = _FRONTMATTER_RE.match(text)
  if not fm_m:
    return None, [f"{file_path.name}: missing YAML frontmatter or H3 questions"]
  fm_text = fm_m.group(1)
  qid_m = re.search(r"^id:\s*([A-Z]+-\d+)\s*$", fm_text, re.MULTILINE)
  lvl_m = re.search(
      r"^levels:\s*\[\s*(\d+)\s*,\s*(\d+)\s*\]\s*$", fm_text, re.MULTILINE
  )
  if not qid_m or not lvl_m:
    return None, [
        f"{file_path.name}: frontmatter requires 'id: XX-01' and "
        "'levels: [min, max]'"
    ]
  qid = qid_m.group(1)
  rec = QuestionRecord(
      qid=qid,
      slug=file_path.stem.lower(),
      block=text[fm_m.end() :],
      min_level=int(lvl_m.group(1)),
      max_level=int(lvl_m.group(2)),
  )
  return rec, []


def verify_markdown_file(
    file_path: pathlib.Path, repo_root: pathlib.Path
) -> tuple[int, list[str]]:
  """Verifies either a multi-question bank or a modular per-question file."""
  label = file_path.name
  text = file_path.read_text(encoding="utf-8")
  lines = text.splitlines()
  errors = _check_markdown_hygiene(lines, label)

  prose_only = _CODE_FENCE_RE.sub("", text)
  for pat in _NON_INCLUSIVE_PATTERNS:
    hits = re.findall(pat, prose_only, flags=re.IGNORECASE)
    if hits:
      errors.append(f"{label}: non-inclusive term {pat!r}: {hits[:3]}")

  h3_matches = list(_H3_QUESTION_RE.finditer(text))
  if not h3_matches:
    rec, fm_errs = _parse_frontmatter_question(text, file_path)
    errors.extend(fm_errs)
    if rec is not None:
      errors.extend(_verify_question_record(rec, label, repo_root))
      return 1, errors
    return 0, errors

  # Multi-question bank mode: check optional Section 2 index parity.
  sec2_levels: dict[str, tuple[int, int]] = {}
  sec2_m = _SEC2_BLOCK_RE.search(text)
  if sec2_m:
    sec2_links = _SEC2_LINK_RE.findall(sec2_m.group(1))
    expected_pairs: list[tuple[str, str]] = []
    for m in h3_matches:
      qid, title, explicit_slug = m.group(1), m.group(2), m.group(3)
      slug = explicit_slug or _gfm_slug(f"[{qid}] {title}")
      expected_pairs.append((qid, slug))
    if sec2_links != expected_pairs:
      errors.append(
          f"{label}: Section 2 index links ({len(sec2_links)}) do not match "
          f"H3 headings ({len(expected_pairs)}) 1:1"
      )
    for row in _split_gfm_table_rows(sec2_m.group(1))[1:]:
      if len(row) >= 4:
        qm = re.search(r"\[`?([A-Z]+-\d+)`?\]", row[0])
        lvs = _extract_levels(row[3])
        if qm and lvs:
          sec2_levels[qm.group(1)] = (min(lvs), max(lvs))

  seen_ids: set[str] = set()
  for idx, match in enumerate(h3_matches):
    qid = match.group(1)
    if qid in seen_ids:
      errors.append(f"{label}: duplicate question ID {qid}")
    seen_ids.add(qid)
    start = match.start()
    end = (
        h3_matches[idx + 1].start() if idx + 1 < len(h3_matches) else len(text)
    )
    block = text[start:end]
    header_part = block.split("**Prompt:**", 1)[0]
    bullets = _META_BULLET_RE.findall(header_part)
    if len(bullets) != 5:
      errors.append(
          f"{label} [{qid}]: expected 5 metadata bullets, found {len(bullets)}"
      )
    tl_m = re.search(r"\*\s+\*\*Target Levels\*\*:\s*([^\n]+)", block)
    tl_nums = _extract_levels(tl_m.group(1)) if tl_m else []
    if not tl_nums:
      errors.append(f"{label} [{qid}]: missing Target Levels metadata")
      continue
    tl_min, tl_max = min(tl_nums), max(tl_nums)
    if qid in sec2_levels and sec2_levels[qid] != (tl_min, tl_max):
      s2_min, s2_max = sec2_levels[qid]
      errors.append(
          f"{label} [{qid}]: Section 2 levels L{s2_min}-L{s2_max} != "
          f"Target Levels L{tl_min}-L{tl_max}"
      )
    slug = match.group(3) or _gfm_slug(f"[{qid}] {match.group(2)}")
    rec = QuestionRecord(
        qid=qid, slug=slug, block=block, min_level=tl_min, max_level=tl_max
    )
    errors.extend(_verify_question_record(rec, label, repo_root))

  return len(h3_matches), errors


def _collect_targets(target: pathlib.Path) -> list[pathlib.Path]:
  """Collects Markdown files from a file or directory target."""
  if target.is_file():
    return [target]
  skip_names = {"readme.md", "index.md", "license.md", "contributing.md"}
  return [
      p
      for p in sorted(target.rglob("*.md"))
      if p.name.lower() not in skip_names
  ]


def main(argv: Sequence[str]) -> int:
  """CLI entry point for verifying external interview question banks."""
  if len(argv) != 2:
    print(
        "Usage: verify_external_banks.py <md_file_or_directory>",
        file=sys.stderr,
    )
    return 2

  target = pathlib.Path(argv[1]).expanduser().resolve()
  if not target.exists():
    print(f"Target does not exist: {target}", file=sys.stderr)
    return 2

  repo_root = target.parent if target.is_file() else target
  md_files = _collect_targets(target)
  if not md_files:
    print(f"No interview Markdown files found under {target}", file=sys.stderr)
    return 1

  total_questions = 0
  all_errors: list[str] = []
  for md_file in md_files:
    q_count, errs = verify_markdown_file(md_file, repo_root)
    total_questions += q_count
    all_errors.extend(errs)
    if not errs:
      print(f"OK  {md_file.name:32s} | {q_count:3d} questions")

  if all_errors:
    print(f"\nFAILURES DETECTED ({len(all_errors)}):", file=sys.stderr)
    for err in all_errors:
      print(f"  - {err}", file=sys.stderr)
    return 1

  print(
      f"\nVerified {total_questions} question(s) across {len(md_files)} "
      "file(s) with 0 errors."
  )
  return 0


if __name__ == "__main__":
  raise SystemExit(main(sys.argv))
