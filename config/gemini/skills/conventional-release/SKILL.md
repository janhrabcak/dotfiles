---
name: conventional-release
description: Use when the user wants to prepare a new release, calculate semantic version bumps (SemVer), generate or update CHANGELOG.md from conventional commits, or draft a release tag.
---

# Conventional Release Playbook

This skill guides the preparation of software releases following Semantic Versioning (SemVer 2.0.0) and the Conventional Commits specification.

---

## Step 1: Discover Current State & History

1. Identify the most recent tag:
   ```bash
   git describe --tags --abbrev=0 2>/dev/null || git tag -l --sort=-v:refname | head -n 1
   ```
   If no previous tag exists, treat the entire history up to `HEAD` as the initial release scope.

2. Collect all commits since the last tag:
   ```bash
   git log <last-tag>..HEAD --pretty=format:"%h %s"
   ```

3. Ensure working directory is clean:
   ```bash
   git status --porcelain
   ```

---

## Step 2: Determine Semantic Version Bump

Analyze commit subjects and bodies since the last tag:

1. **MAJOR (`X.0.0`)**:
   - Any commit with `BREAKING CHANGE:` in the body/footer, or `!:` after the type (e.g., `feat!:`, `fix!:`).
2. **MINOR (`0.X.0`)**:
   - Any `feat:` or `feat(<scope>):` commit without breaking changes.
3. **PATCH (`0.0.X`)**:
   - Only `fix:`, `perf:`, `refactor:`, `chore:`, `docs:`, `test:` commits without breaking changes.

---

## Step 3: Update `CHANGELOG.md`

Group changes into standard Conventional Commit sections:

```markdown
## [<version>] - YYYY-MM-DD

### 🚀 Features
- **<scope>**: <description> ([<hash>](commit-link))

### 🐛 Bug Fixes
- **<scope>**: <description> ([<hash>](commit-link))

### ⚡ Performance Improvements
- **<scope>**: <description> ([<hash>](commit-link))

### ♻️ Code Refactoring & Maintenance
- **<scope>**: <description> ([<hash>](commit-link))
```

* Prepend the new release section directly below the header in `CHANGELOG.md`.
* Preserve all existing historical release entries verbatim.

---

## Step 4: Bump Version Files (If Present)

Check and update repository-specific metadata:
- **Node.js**: `package.json` and `package-lock.json` (`npm version <version> --no-git-tag-version`)
- **Python**: `pyproject.toml` or `setup.py`
- **Go**: Version constants in `version.go` or README badges
- **Rust**: `Cargo.toml`

---

## Step 5: Verify & Confirm Before Tagging

1. Run the test suite and linters to ensure build correctness before committing:
   ```bash
   # Execute relevant project tests (e.g., npm test, cargo test, ./dot.sh --test)
   ```
2. Present a clean summary of:
   - Calculated version bump.
   - Diff of `CHANGELOG.md` and version files.
3. Obtain explicit user confirmation before creating the commit or tag.
4. Once confirmed, commit and tag:
   ```bash
   git add CHANGELOG.md <version-files>
   git commit -m "chore(release): <version>"
   git tag -a "<version>" -m "Release <version>"
   ```
5. **Never push tags automatically.** Prompt the user if they wish to push (`git push origin <version>` or `git push --follow-tags`).
