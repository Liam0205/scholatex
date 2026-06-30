# Makefile -- local task entry. See .githooks/README.md for hook details.
#
# Naming convention (kept open for future verbs once a build system lands):
#   make <verb>          alias of <verb>-all
#   make <verb>-all      run across the whole repo (explicit)
#   make <verb>-<target> run only on the named target
#
# Current verbs: only the git workflow (hooks). Build / check verbs will be
# added when scholatex grows a runnable test corpus.

.PHONY: help hooks

# ── default target: list available targets ─────────────────────────────────
help:                       ## show this help
	@echo "scholatex Makefile -- local task entry"
	@echo ""
	@echo "Git workflow:"
	@echo "  make hooks                # one-shot install of repository git hooks"

# ── git workflow ───────────────────────────────────────────────────────────
hooks:                       ## one-shot install of git hooks
	git config core.hooksPath .githooks
	@echo "hooks installed: $$(git config core.hooksPath)"
