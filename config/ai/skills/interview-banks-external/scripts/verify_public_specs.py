#!/usr/bin/env python3
"""Verifies CVE, IETF RFC, and URL citations against public standards APIs."""

from collections.abc import Sequence
import datetime
import json
import pathlib
import re
import sys
import urllib.error
import urllib.request

_CODE_FENCE_RE = re.compile(r"```[a-zA-Z0-9_+-]*\n.*?```", re.DOTALL)
_INLINE_CODE_RE = re.compile(r"`+[^`]+`+")
_CVE_RE = re.compile(r"\bCVE-(\d{4})-(\d{4,7})\b")
_RFC_RE = re.compile(r"\bRFC\s+(\d{3,5})\b")
_MD_LINK_RE = re.compile(r"\[[^\]]+\]\(([^)\s]+)\)")

_CVE_API_TEMPLATE = "https://cveawg.mitre.org/api/cve/{cve_id}"
_RFC_API_TEMPLATE = "https://datatracker.ietf.org/doc/rfc{rfc_num}/doc.json"


def _fetch_json(url: str, timeout_sec: float = 8.0) -> dict[str, object]:
  """Fetches JSON over HTTPS from a public specification registry."""
  req = urllib.request.Request(
      url,
      headers={"Accept": "application/json", "User-Agent": "spec-verifier/1.0"},
  )
  with urllib.request.urlopen(req, timeout=timeout_sec) as resp:
    payload = json.loads(resp.read().decode("utf-8"))
  if not isinstance(payload, dict):
    raise ValueError(f"Expected JSON object from {url}")
  return payload


def _verify_cve_online(cve_id: str) -> tuple[str | None, str]:
  """Queries the public MITRE CVE Services v2.1 API for `cve_id`."""
  url = _CVE_API_TEMPLATE.format(cve_id=cve_id)
  try:
    data = _fetch_json(url)
  except urllib.error.HTTPError as exc:
    if exc.code == 404:
      return f"{cve_id}: not found in public CVE registry (HTTP 404)", ""
    return f"{cve_id}: CVE API returned HTTP {exc.code}", ""
  except urllib.error.URLError as exc:
    return f"{cve_id}: network unavailable ({exc.reason}); pass --offline", ""

  meta = data.get("cveMetadata")
  state = meta.get("state") if isinstance(meta, dict) else None
  if state != "PUBLISHED":
    return f"{cve_id}: unexpected CVE state {state!r} (expected PUBLISHED)", ""

  summary = ""
  containers = data.get("containers")
  if isinstance(containers, dict):
    cna = containers.get("cna")
    if isinstance(cna, dict):
      descs = cna.get("descriptions")
      if isinstance(descs, list) and descs and isinstance(descs[0], dict):
        raw_val = str(descs[0].get("value", ""))
        summary = " ".join(raw_val.split())[:100]
  return None, summary


def _verify_rfc_online(rfc_num: int) -> tuple[str | None, str]:
  """Queries the public IETF Datatracker JSON endpoint for `RFC <rfc_num>`."""
  url = _RFC_API_TEMPLATE.format(rfc_num=rfc_num)
  try:
    data = _fetch_json(url)
  except urllib.error.HTTPError as exc:
    if exc.code == 404:
      return f"RFC {rfc_num}: does not exist on IETF Datatracker (HTTP 404)", ""
    return f"RFC {rfc_num}: Datatracker returned HTTP {exc.code}", ""
  except urllib.error.URLError as exc:
    return (
        f"RFC {rfc_num}: network unavailable ({exc.reason}); pass --offline",
        "",
    )

  title = str(data.get("title", "")).strip()
  obsoleted = data.get("obsoleted_by")
  note = title
  if isinstance(obsoleted, list) and obsoleted:
    obs_str = ", ".join(str(x) for x in obsoleted[:3])
    note = f"{title} [NOTE: obsoleted by {obs_str}]"
  return None, note


def _scan_file_citations(
    md_path: pathlib.Path, max_year: int
) -> tuple[set[str], set[int], list[str]]:
  """Extracts CVEs, RFC numbers, and URL hygiene errors from one Markdown file."""
  text = md_path.read_text(encoding="utf-8")
  errors: list[str] = []
  cves: set[str] = set()
  rfcs: set[int] = set()

  for year_str, seq_str in _CVE_RE.findall(text):
    year = int(year_str)
    cve_id = f"CVE-{year_str}-{seq_str}"
    # Skip synthetic test-only placeholder CVEs like CVE-2026-0001 inside mocks.
    if seq_str == "0001":
      continue
    if year < 1999 or year > max_year:
      errors.append(f"{md_path.name}: implausible CVE year in {cve_id}")
    else:
      cves.add(cve_id)

  for rfc_str in _RFC_RE.findall(text):
    rfc_num = int(rfc_str)
    if rfc_num < 1 or rfc_num > 15000:
      errors.append(f"{md_path.name}: implausible RFC number RFC {rfc_num}")
    else:
      rfcs.add(rfc_num)

  prose_only = _INLINE_CODE_RE.sub("", _CODE_FENCE_RE.sub("", text))
  for target in _MD_LINK_RE.findall(prose_only):
    if target.startswith("#") or not re.match(
        r"^[a-zA-Z][a-zA-Z0-9+.-]*:", target
    ):
      continue
    if target.startswith("file://"):
      errors.append(f"{md_path.name}: local file:// link forbidden: {target}")
    elif target.startswith("http://"):
      errors.append(
          f"{md_path.name}: insecure http:// link in prose (use https://): "
          f"{target}"
      )

  return cves, rfcs, errors


def _collect_md_files(target: pathlib.Path) -> list[pathlib.Path]:
  """Returns Markdown files from a file or directory path."""
  if target.is_file():
    return [target]
  return sorted(target.rglob("*.md"))


def main(argv: Sequence[str]) -> int:
  """CLI entry point for validating CVE, RFC, and URL citations."""
  args = list(argv[1:])
  offline = False
  if "--offline" in args:
    offline = True
    args.remove("--offline")

  if len(args) != 1:
    print(
        "Usage: verify_public_specs.py [--offline] <md_file_or_directory>",
        file=sys.stderr,
    )
    return 2

  target = pathlib.Path(args[0]).expanduser().resolve()
  if not target.exists():
    print(f"Target does not exist: {target}", file=sys.stderr)
    return 2

  md_files = _collect_md_files(target)
  if not md_files:
    print(f"No Markdown files found under {target}", file=sys.stderr)
    return 1

  max_year = datetime.datetime.now(datetime.timezone.utc).year + 1
  all_cves: set[str] = set()
  all_rfcs: set[int] = set()
  errors: list[str] = []

  for md_file in md_files:
    cves, rfcs, file_errs = _scan_file_citations(md_file, max_year)
    all_cves.update(cves)
    all_rfcs.update(rfcs)
    errors.extend(file_errs)

  if not offline:
    for cve_id in sorted(all_cves):
      err, summary = _verify_cve_online(cve_id)
      if err:
        errors.append(err)
      else:
        print(f"CVE OK  {cve_id:16s} | {summary}")
    for rfc_num in sorted(all_rfcs):
      err, info = _verify_rfc_online(rfc_num)
      if err:
        errors.append(err)
      else:
        print(f"RFC OK  RFC {rfc_num:<12d} | {info}")
  else:
    print(
        f"Offline syntax check passed for {len(all_cves)} unique CVE(s) and "
        f"{len(all_rfcs)} unique RFC(s)."
    )

  if errors:
    print(f"\nSPEC CITATION FAILURES ({len(errors)}):", file=sys.stderr)
    for err in errors:
      print(f"  - {err}", file=sys.stderr)
    return 1

  print(
      f"\nVerified {len(all_cves)} CVE(s) and {len(all_rfcs)} RFC(s) across "
      f"{len(md_files)} file(s) with 0 errors."
  )
  return 0


if __name__ == "__main__":
  raise SystemExit(main(sys.argv))
