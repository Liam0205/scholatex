# Reference: Build and CI Files

## Scope

File-by-file lookup for every file the build / test / CI / release toolchain touches at the repo root, `.github/`, `scripts/`, or `testfiles/`. Deliberately stable — each row points to the canonical source and cites `file:line` for the rule that lives there.

**Not in scope**: `scholatex.cls`, `scholatex.lua`, `scholatex-*.lua` (the class and lua modules — see `architecture/compile-pipeline.md`); `examples/*.tex` (the demo documents); `llmdoc/`, `README.md`, `CHANGELOG.md`, `LICENSE` (documentation, not toolchain).

For the *operational* flow that ties these files together, read `architecture/test-pipeline.md` and `architecture/release-pipeline.md`. This doc is for "where exactly is rule X defined?" queries.

## Files at repo root

### `build.lua`

160 lines, declarative. The single l3build config; consumed by every l3build subcommand (`check`, `save`, `ctan`, `install`, `upload`).

| Section | Field | Value / shape | Consumed by | Citation |
|---|---|---|---|---|
| Package metadata | `module` | `"scholatex"` | every l3build subcommand | `build.lua:16` |
| | `packtdszip` / `tdsroot` | `true` / `"luatex"` | `l3build ctan` | `build.lua:19-20` |
| Source layout | `unpackfiles` | `{ }` (empty — no `.dtx`) | `l3build unpack` | `build.lua:23` |
| | `sourcefiles` | `{ "scholatex.cls", "scholatex.lua", "scholatex-*.lua" }` | `l3build install`, `l3build ctan` | `build.lua:24` |
| | `installfiles` | `sourcefiles` (same set) | `l3build install` | `build.lua:25` |
| Docs | `typesetfiles` | `{ "scholatex.tex" }` | `l3build doc` | `build.lua:28` |
| | `typesetexe` | `"lualatex"` | `l3build doc` | `build.lua:29` |
| | `docfiles` | `{ "README.md", "CHANGELOG.md", "LICENSE" }` | `l3build ctan` | `build.lua:31-35` |
| Testing | `testfiledir` | `"./testfiles"` | `l3build check`, `l3build save` | `build.lua:38` |
| | `stdengine` / `checkengines` | `"luatex"` / `{ "luatex" }` | `l3build check` | `build.lua:39-41` |
| | `checkformat` | `"latex"` | `l3build check` | `build.lua:42` |
| | `checkruns` | `1` | `l3build check` | `build.lua:46` |
| | `recordstatus` | `true` (pins exit code) | `l3build check`, `l3build save` | `build.lua:51` |
| Upload | `pkg` / `author` | `"scholatex"` / `"Gérard Dubard"` | `l3build upload` | `build.lua:60-61` |
| | `uploader` / `email` / `note` | `os.getenv("CTAN_UPLOADER" / "CTAN_EMAIL" / "CTAN_NOTE")` | `l3build upload` | `build.lua:62-63, 75` |
| | `license` | `"gpl3+"` | `l3build upload` | `build.lua:64` |
| | `topic` | `{ "class", "luatex", "education", "maths-doc" }` | `l3build upload` | `build.lua:66-71` |
| | `ctanPath` | `"/macros/luatex/latex/scholatex"` | `l3build upload` | `build.lua:72` |
| | `repository` / `bugtracker` | GitHub URLs | `l3build upload` | `build.lua:73-74` |
| | `update` | `true` | `l3build upload` | `build.lua:76` |
| Version derivation | `read_version()` | greps `\ProvidesClass{scholatex}[<date> v<X.Y> ...]` from `scholatex.cls` | `uploadconfig.version` | `build.lua:83-89` |
| Baseline whitelist | `_keep_patterns` | 10 patterns (see § "_keep_patterns contract") | `_scholatex_filter` post-pass | `build.lua:125-137` |
| | `_scholatex_filter(path)` | line-by-line filter | `rewrite_log` override | `build.lua:139-153` |
| | `rewrite_log` override | wraps `_orig_rewrite_log`, then filters | l3build internal `normalize_log` pipeline | `build.lua:155-159` |

The version pattern is verbatim:

```
ProvidesClass{scholatex}%[[%d-]+%s+v([%w.+-]+)
```

For the merged `scholatex.cls:2` (`\ProvidesClass{scholatex}[2026-06-28 v2.3 ...]`), `uploadconfig.version = "v2.3"`. No date is recorded; CTAN's release-date column is filled by ctan.org itself at submission time.

### `Makefile`

113 lines. `.PHONY` targets at `Makefile:14`: `help hooks check doc ctan install clean tag`.

| Target | Args | Recipe summary | Citation |
|---|---|---|---|
| `help` (default) | — | `@echo` listing of every target with short descriptions | `Makefile:17-32` |
| `hooks` | — | `git config core.hooksPath .githooks` + echo confirmation | `Makefile:35-37` |
| `check` | `J=N` (optional) | If `J > 1`, `LUATEX_BUCKETS=$(J) ./scripts/check-parallel.sh`; else `l3build check -q` | `Makefile:47-53` |
| `doc` | — | `l3build doc` | `Makefile:55-56` |
| `ctan` | — | `l3build ctan` — emits `build/distrib/ctan/scholatex-ctan.zip` | `Makefile:58-59` |
| `install` | — | `l3build install --full --dry-run` (dry-run by default — never installs into `~/texmf` without an explicit live invocation) | `Makefile:61-62` |
| `clean` | — | `l3build clean` | `Makefile:64-65` |
| `tag` | `v<X.Y>[.<Z>][-rcN]` | Validate regex; reject empty / existing; `git tag -a`; print push hint | `Makefile:80-102` |

The shared tag regex (used by Makefile, `release.yml:32`, `release-ctan-upload.yml:61`): `^v[0-9]+\.[0-9]+(\.[0-9]+)?(-rc[0-9]+)?$`.

The `J ?= 1` declaration at `Makefile:45` chooses between serial and parallel paths. See `architecture/test-pipeline.md` § "`J ?= 1` parallel mechanism" for why `make check J=4` is used instead of `make -j 4`.

The `tag` recipe's conditional phony sub-target at `Makefile:106-112` absorbs the tag-name argument as a no-op so make does not complain "no rule to make target 'v2.4'". See `architecture/release-pipeline.md` § "`make tag` validation".

## `.github/`

### `tl_packages`

83 lines, plain-text package list. Hashed by `hashFiles('.github/tl_packages')` in `ci.yml:69` and `release.yml:54` — adding or removing a package immediately invalidates the manual TL bypass cache.

Total: **55 packages** in 4 blocks:

| Block | Lines | Count | Contents |
|---|---|---|---|
| Toolchain | `tl_packages:21-29` | 9 | `scheme-basic`, `l3build`, `latex-bin`, `luatex`, `lualatex-math`, `l3kernel`, `l3packages`, `l3experimental`, `l3backend` |
| cls `\RequirePackage` block | `tl_packages:32-58` | 27 | Direct deps — `geometry`, `unicode-math`, `tcolorbox`, `tikz`, etc. (The inline header comment says "22 entries" — stale, see `memory/doc-gaps.md`) |
| Transitive deps | `tl_packages:63-79` | 17 | Each line has an inline comment naming the parent: `collectbox            # adjustbox dep` |
| Fonts | `tl_packages:82-83` | 2 | `lm`, `lm-math` |

Inline comments on every transitive dep name the parent package — this is the only documentation of which package needs which transitive. The comments are the contract.

#### Regeneration recipe

Verbatim from `tl_packages:8-18`:

```
cd /tmp && mkdir t && cd t
for f in <path-to-repo>/examples/*.tex; do
    cp "$f" main.tex
    TEXINPUTS=<path-to-repo>: LUAINPUTS=<path-to-repo>: \
    lualatex --recorder -interaction=nonstopmode main.tex >/dev/null 2>&1
    grep -oE 'INPUT [^ ]+\.(sty|cls|def|cfg|fd|tex|lua|cmap|clo)$' main.fls
done | awk '{print $2}' | grep -oE '/tex/[^/]+/[^/]+/' \
    | sed -E 's|/tex/[^/]+/([^/]+)/|\1|' | sort -u
```

Run this after adding a new `\RequirePackage` to `scholatex.cls` or after pulling in a new external dependency. The output is a sorted list of TL package names; diff against the current file to find what to add.

### `workflows/ci.yml`

107 lines, single job `check`. Triggers, concurrency, steps, cache, artifact:

| Section | Detail | Citation |
|---|---|---|
| Triggers | `pull_request` to `main`, `push` to `main`, `workflow_dispatch` | `ci.yml:8-10, 19-21` |
| paths-ignore | `llmdoc/**`, `**/README.md`, `CHANGELOG.md`, `LICENSE`, `.gitignore`, `.githooks/**`, `.code-review/**` (both PR and push) | `ci.yml:11-18, 21-28` |
| Concurrency group | `ci-${{ github.head_ref || github.ref_name }}-${{ github.event_name }}` | `ci.yml:33-34` |
| cancel-in-progress | `${{ github.ref_name != 'main' }}` (PRs cancel older runs; main always completes) | `ci.yml:35` |
| `TL_VERSION` env | `'2026'` | `ci.yml:38` |
| Cache week step | `echo "iso=$(date -u +'%G-W%V')" >> $GITHUB_OUTPUT` | `ci.yml:60-62` |
| TL bypass cache key | `tl-bypass-${{ runner.os }}-${{ env.TL_VERSION }}-${{ steps.cache-week.outputs.iso }}-${{ hashFiles('.github/tl_packages') }}` | `ci.yml:64-69` |
| Cache path | `${{ runner.temp }}/setup-texlive-action/${{ env.TL_VERSION }}` | `ci.yml:67` |
| Cache hit step | Skip setup-texlive; export bin path to `$GITHUB_PATH`; `tlmgr version` sanity check with `continue-on-error: true` | `ci.yml:72-78` |
| Cache miss step | `setup-texlive-action@v4` with `cache: false`, `package-file: .github/tl_packages`, `update-all-packages: true` | `ci.yml:82-89` |
| Check step | `make check J=4` | `ci.yml:91-93` |
| Diff artifact step | `if: failure()`; uploads `build/test*/**/*.diff`, `build/test*/**/*.log`, `tmp/parallel-check/**/build/test*/**/*.diff`, `tmp/parallel-check/**/build/test*/**/*.log`; 14-day retention | `ci.yml:95-106` |

The artifact glob captures both the serial path (`build/test*/`) and the parallel-bucket paths (`tmp/parallel-check/N/build/test*/`). Parallel buckets place their build directories inside their own isolated worktrees under `tmp/parallel-check/N/`, so artifact globs must cover both.

### `workflows/release.yml`

150 lines, single job `release`. Triggered on tag push matching `v*`:

| Section | Detail | Citation |
|---|---|---|
| Trigger | `push: tags: ['v*']` | `release.yml:9-12` |
| Permissions | `contents: write` (to create GitHub release) | `release.yml:14-15` |
| Tag parsing step | Validates `^v[0-9]+\.[0-9]+(\.[0-9]+)?(-rc[0-9]+)?$`; outputs `tag`, `ver`, `sha8` | `release.yml:28-40` |
| TL bypass cache | Byte-identical to `ci.yml:60-89` cache block; same key | `release.yml:45-71` |
| Build step | `make ctan` → `build/distrib/ctan/scholatex-ctan.zip`; rename to `scholatex-<tag>-<sha8>.zip` | `release.yml:73-86` |
| Release notes step | `scripts/extract-changelog.sh "$ver"`; fallback A: git log range; fallback B: literal `Release scholatex <ver>`; preview via `head -40` | `release.yml:88-104` |
| CI wait loop | 30-min budget; `gh api workflow_runs?head_sha=$sha`; `select(.name != "Release")`; awk gate on status `completed` then conclusion `success` | `release.yml:106-139` |
| Release creation step | `gh release create $tag $asset --prerelease --title "scholatex $tag" --notes-file release-notes.md` | `release.yml:141-149` |

Every release is `--prerelease` until the manual CTAN upload step promotes it — see `release-ctan-upload.yml:112-121`.

### `workflows/release-ctan-upload.yml`

122 lines, single job `upload`. `workflow_dispatch` only:

| Section | Detail | Citation |
|---|---|---|
| Trigger | `workflow_dispatch` (no other triggers) | `release-ctan-upload.yml:13` |
| Inputs | `tag` (required), `uploader` (required), `email` (required), `note` (≤4096 bytes), `dry_run` (boolean, default `true`) | `release-ctan-upload.yml:14-36` |
| Permissions | `contents: write` (to promote release) | `release-ctan-upload.yml:48-49` |
| Environment gate | `environment: ${{ inputs.dry_run && '' || 'ctan-release' }}` | `release-ctan-upload.yml:52` |
| Input validation | Tag regex; note byte length via `printf '%s' "$note" \| wc -c` | `release-ctan-upload.yml:58-69` |
| TL minimal step | `setup-texlive-action@v4` with `packages: scheme-minimal / l3build / luatex`, `cache: true` (uses action's internal cache because the bypass cache is sized for the full corpus) | `release-ctan-upload.yml:71-79` |
| Download step | `gh release download $tag --pattern '*.zip' --dir build/distrib/ctan`; rename to `scholatex-ctan.zip` | `release-ctan-upload.yml:81-96` |
| Upload step | env: `CTAN_UPLOADER`, `CTAN_EMAIL`, `CTAN_NOTE` from inputs; dry-run: `echo n \| l3build upload --dry-run`; live: `echo y \| l3build upload` | `release-ctan-upload.yml:98-110` |
| Promote step | `if: ${{ inputs.dry_run == false }}`; `gh release edit $tag --prerelease=false --latest` | `release-ctan-upload.yml:112-121` |

The dry-run environment trick: empty environment string skips the gate; `'ctan-release'` engages the protected environment if configured. See `architecture/release-pipeline.md` § "The dry-run gate" for the operator-facing semantics.

## `scripts/`

### `scripts/check-parallel.sh`

143 lines, `set -euo pipefail` at line 21.

**Usage**: `LUATEX_BUCKETS=N ./scripts/check-parallel.sh` or `BUCKETS=N ./scripts/check-parallel.sh`. Invoked by `Makefile:50` when `make check J=N` (N > 1).

**Env vars**:

| Var | Effect | Default |
|---|---|---|
| `LUATEX_BUCKETS` | Preferred — bucket count | — |
| `BUCKETS` | Synonym for `LUATEX_BUCKETS` | 1 (serial fallback) |

**Algorithm**:

1. Read bucket count; sanity-check `build.lua` exists in cwd (`scripts/check-parallel.sh:24, 35-38`).
2. Short-circuit at BUCKETS ≤ 1: `exec l3build check -q "$@"` (`scripts/check-parallel.sh:42`).
3. Enumerate `testfiles/*.lvt` alphabetically (`scripts/check-parallel.sh:46`).
4. Cap buckets to test count if requested > total (`scripts/check-parallel.sh:55-58`).
5. Slice: `per=$(( (total + BUCKETS - 1) / BUCKETS ))` — ceiling division (`scripts/check-parallel.sh:61`).
6. Workdir setup: `WORK_ROOT="$REPO_ROOT/tmp/parallel-check"` wiped and re-created (`scripts/check-parallel.sh:63-65`).
7. EXIT trap: success → wipe workdir; failure → preserve and print path to stderr (`scripts/check-parallel.sh:68`).
8. Per-bucket worker: isolated tree via `git ls-files -z | tar`; `set +e` inside subshell; `l3build check --first $first --last $last -q` with output line-prefixed by `[bN]`; on failure dump `build/test/*.diff` inline (`scripts/check-parallel.sh:91-117`).

See `architecture/test-pipeline.md` § "`scripts/check-parallel.sh`" for the design rationale (the `set +e` requirement, the `git ls-files | tar` isolation, the dump-on-fail).

### `scripts/extract-changelog.sh`

57 lines, `set -euo pipefail` at line 16.

**Usage**: `scripts/extract-changelog.sh <version>`. Invoked by `release.yml:90` to produce `release-notes.md`.

**Accepted args**: exactly one positional. Forms accepted (all resolve to the same section):

- `v2.3` → section `2.3`
- `2.3` → section `2.3`
- `v2.3-rc1` → section `2.3`
- `2.3-rc1` → section `2.3`

Prefix stripping at `scripts/extract-changelog.sh:25-28`:

```bash
ver="${1#v}"       # v prefix
ver="${ver%%-*}"   # -rcN suffix
```

**Output contract**:

| Exit | Behaviour |
|---|---|
| 0 | Section found; trimmed body printed to stdout |
| 1 | `## [<ver>]` heading not found in `CHANGELOG.md`; error to stderr |
| 2 | Wrong arg count, or `CHANGELOG.md` missing |

The awk extraction at `scripts/extract-changelog.sh:41-48`:

```awk
BEGIN { emit = 0 }
/^## \[/ {
    if (emit) exit
    if ($0 ~ "^## \\[" ver "\\]") { emit = 1; next }
}
emit { print }
```

Walks `CHANGELOG.md`; when `## [<ver>]` matches, sets `emit=1` and skips the heading; subsequent lines print until the next `## [` heading or EOF. Trim trailing blanks via two `sed '/./,$!d'` invocations sandwiching `tac` (`scripts/extract-changelog.sh:56`).

**Known limitation**: matches strict `## [<ver>]` only — a future `## [unreleased]` section would never match. Tracked in `memory/doc-gaps.md`.

## `testfiles/`

### `testfiles/support/regression-test.cfg`

26 lines. Loaded by `\input{regression-test}` at line 1 of every `.lvt`. The active payload is two lines (`testfiles/support/regression-test.cfg:24-25`):

```latex
\START
\def\AUTHOR#1{}
```

- `\START` runs synchronously at cfg load time (NOT deferred to `\AtBeginDocument`). If deferred, a failing test's class-side `\AtBeginDocument` error would abort the harness's hook and l3build would drop the entire transcript as preamble noise.
- `\def\AUTHOR#1{}` swallows the `\AUTHOR{...}` macro used by some `examples/*.tex` so an `.lvt` body can be a byte-identical copy.
- No `\OMIT` / `\TIMO` bracketing — the build.lua-side whitelist already filters non-scholatex lines, and the original OMIT pair silently swallowed `PIN:` `\typeout` lines.

See `architecture/test-pipeline.md` § "`testfiles/support/regression-test.cfg`" for the full rationale.

`testfiles/support/` is the only directory whose contents l3build auto-stages into each test work-dir (l3build's default `testsuppdir`). A cfg at `testfiles/` root would be inert.

### `.lvt` / `.tlg` conventions

| Prefix | Purpose | Count |
|---|---|---|
| `example-<name>.lvt` | Smoke test (`\input{regression-test}` + byte-identical copy of `examples/<name>.tex`) | 10 |
| `regress-<id>.lvt` | Regression for a `memory/doc-gaps.md` row | 9 |
| `pin-<feature>.lvt` | Typesetting invariant (class-level dimensions, etc.) | 1 |

Total: **20 .lvt files** = 10 smoke + 9 regression + 1 PIN.

#### Full inventory

**Smoke tests** (one per image-free example; `containers.tex` deferred):

- `example-algebra.lvt`
- `example-analysis.lvt`
- `example-basics.lvt`
- `example-functions.lvt`
- `example-geometry.lvt`
- `example-math-algebra.lvt`
- `example-math-analysis.lvt`
- `example-math-language.lvt`
- `example-probability.lvt`
- `example-text-style.lvt`

**Regression tests** (one per doc-gap MWE; doc-gap IDs map 1:1):

| File | Doc-gap row | What it pins |
|---|---|---|
| `regress-A1.lvt` | A1 — `<box>` `boxsep:` ignored, falls back silently | exit 0 ("no crash" pin) |
| `regress-A2.lvt` | A2 — README missing `^` in escape list | exit 0 ("compiles clean" pin) |
| `regress-B1.lvt` | B1 — block opener `{` not at line end | exit 1, explicit error string |
| `regress-B2.lvt` | B2 — bracketed-list `for` items always strings | exit 0 (footgun, no error pin) |
| `regress-B5.lvt` | B5 — `warn_if_shadows` text in `.log` | exit 0, warning string pin |
| `regress-E1.lvt` | E1 — French `angle` error translated | exit 1, English error pin |
| `regress-E2.lvt` | E2 — French `équilatéral` error translated | exit 1, English error pin |
| `regress-E3.lvt` | E3 — French `côtés incompatibles` translated | exit 1, English error pin |
| `regress-E4.lvt` | E4 — French `somme des angles` translated | exit 1, English error pin |

Not covered: **B3** (literal `\end{document}` in body — would self-terminate the `.lvt`), **B4** (`--jobname=foo` mismatch — needs per-test `checkopts` wiring). See `architecture/test-pipeline.md` § "Deferred".

**PIN test**:

- `pin-class-defaults.lvt` — pins `\textwidth`, `\paperwidth`, `\textheight`, `\scholatextab`, `\scholatexline` via `\AddToHook{begindocument/before}` + `\typeout{PIN: ...}` lines. Whitelist row 6 (`^PIN:`) keeps them through the filter. See `architecture/test-pipeline.md` § "The `PIN:` typesetting invariant pattern".

## Cross-references

### `_keep_patterns` contract

The `_keep_patterns` table at `build.lua:125-137` is the heart of the test pipeline's signal-to-noise ratio. Every new error or warning emitted from `scholatex.cls` or `scholatex.lua` MUST start with one of the three project-namespace prefixes to survive the filter:

| Prefix | Source sites |
|---|---|
| `scholatex:` | `error("scholatex: ...")` / `io.stderr:write("scholatex: warning: ...")` in `scholatex.lua` and the `scholatex-*.lua` modules |
| `scholatex.cls:` | `tex.error("scholatex.cls: ...")` in the `scholatex.cls:135-161` `\AtBeginDocument` hook |
| `Class scholatex Warning` | `\ClassWarning{scholatex}{...}` (currently only the B3 truncation warning at `scholatex.cls:154-155`) |

Lines that don't match any of these three prefixes (or the `PIN:` / `Compilation N ...` / l3build-header escape hatches) are silently filtered out of every `.tlg` baseline. **A new error site without one of these prefixes will not be pinnable.**

See `architecture/test-pipeline.md` § "Baseline whitelist contract" for the full ten-row pattern table and the upgrade risk.

### Triple regex synchronisation

The version-tag regex `^v[0-9]+\.[0-9]+(\.[0-9]+)?(-rc[0-9]+)?$` lives in three independent sites and MUST stay synchronised across all three:

| Site | Citation |
|---|---|
| `Makefile` `tag` target | `Makefile:86` (validation inside the recipe) |
| `release.yml` tag parsing | `release.yml:32` |
| `release-ctan-upload.yml` input validation | `release-ctan-upload.yml:61` |

A change to any one of these MUST be propagated to the other two.

### `CTAN_UPLOADER` / `CTAN_EMAIL` / `CTAN_NOTE` plumbing

Three env vars connect `release-ctan-upload.yml` inputs to `build.lua`'s `uploadconfig`:

| Variable | Set by | Read by |
|---|---|---|
| `CTAN_UPLOADER` | `release-ctan-upload.yml:100` (from `inputs.uploader`) | `build.lua:62` (`uploadconfig.uploader`) |
| `CTAN_EMAIL` | `release-ctan-upload.yml:101` (from `inputs.email`) | `build.lua:63` (`uploadconfig.email`) |
| `CTAN_NOTE` | `release-ctan-upload.yml:102` (from `inputs.note`) | `build.lua:75` (`uploadconfig.note`) |

## Regeneration recipes

### Regenerate one baseline

```
l3build save -e luatex <test-name>
```

For instance: `l3build save -e luatex regress-B1`.

### Regenerate all baselines

```
rm -rf build && l3build save -e luatex \
  example-algebra example-analysis example-basics example-functions \
  example-geometry example-math-algebra example-math-analysis \
  example-math-language example-probability example-text-style \
  regress-A1 regress-A2 regress-B1 regress-B2 regress-B5 \
  regress-E1 regress-E2 regress-E3 regress-E4 \
  pin-class-defaults
```

20 names — full corpus.

### Regenerate `.github/tl_packages`

Verbatim from the file's own header at `.github/tl_packages:8-18`:

```
cd /tmp && mkdir t && cd t
for f in <path-to-repo>/examples/*.tex; do
    cp "$f" main.tex
    TEXINPUTS=<path-to-repo>: LUAINPUTS=<path-to-repo>: \
    lualatex --recorder -interaction=nonstopmode main.tex >/dev/null 2>&1
    grep -oE 'INPUT [^ ]+\.(sty|cls|def|cfg|fd|tex|lua|cmap|clo)$' main.fls
done | awk '{print $2}' | grep -oE '/tex/[^/]+/[^/]+/' \
    | sed -E 's|/tex/[^/]+/([^/]+)/|\1|' | sort -u
```

Run after a new `\RequirePackage` is added to `scholatex.cls`. Diff the output against the current `tl_packages` to find what to add.

## Known limitations

The following items are knowingly deferred or partial:

- **No `make save` target** — operators must invoke `l3build save -e luatex <name>` directly.
- **B3** (literal `\end{document}` in body) has no `.lvt` coverage — the test would self-terminate at the LaTeX parser level. The class-side warning is reachable from a real document. Status: **partial** in `memory/doc-gaps.md`.
- **B4** (`--jobname=foo` mismatch) has no `.lvt` coverage — l3build does not accept per-test `checkopts`. Class-side explicit error works on real documents. Status: **partial** in `memory/doc-gaps.md`.
- **`containers.tex` smoke test deferred** — uses `examples/IMG/` image deps; `testfiles/support/` would need to mirror or symlink the assets.
- **`ctan-release` GitHub environment not provisioned** in the GitHub UI. Operator action required before the first live CTAN upload.
- **`tl_packages:31` comment says "22 entries"** but the actual `\RequirePackage` block has 27. Minor doc drift.
- **`extract-changelog.sh` does not handle `## [unreleased]`** sections — matches strict `## [<ver>]` only.
- **`release.yml` CI wait loop has a 30-min hard budget** — a larger corpus or a slow runner could hit this without a graceful extension.
- **`_keep_patterns` design depends on l3build's `rewrite_log` remaining a global function** — an l3build major refactor would silently no-op the override and corrupt every baseline.

## See also

- `architecture/test-pipeline.md` — operational flow of the test stack.
- `architecture/release-pipeline.md` — operational flow of the release stack.
- `architecture/compile-pipeline.md` — the cls / lua model these tools test.
- `memory/reflections/l3build-ci-bootstrap.md` — the war stories behind these choices.
- `memory/doc-gaps.md` — open items and doc-vs-code drifts.
