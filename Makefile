# Makefile -- local task entry. See .githooks/README.md for hook details.
#
# Targets:
#   make hooks               install repository git hooks
#   make check               l3build check (serial)
#   make check J=N           l3build check, N parallel buckets via
#                            scripts/check-parallel.sh
#   make doc                 l3build doc (regenerate scholatex.pdf)
#   make ctan                l3build ctan (build CTAN zip)
#   make install             l3build install --full --dry-run
#   make clean               l3build clean
#   make tag v<X.Y>[-rcN]    create a local annotated tag

.PHONY: help hooks check doc ctan install clean tag

# ── default target: list available targets ─────────────────────────────────
help:
	@echo "scholatex Makefile -- local task entry"
	@echo ""
	@echo "Build / test:"
	@echo "  make check             l3build check (serial)"
	@echo "  make check J=N         parallel; N buckets via scripts/check-parallel.sh"
	@echo "  make doc               l3build doc (regenerate scholatex.pdf)"
	@echo "  make ctan              l3build ctan (build CTAN zip)"
	@echo "  make install           l3build install --full --dry-run"
	@echo "  make clean             l3build clean"
	@echo ""
	@echo "Git workflow:"
	@echo "  make hooks             install repository git hooks"
	@echo ""
	@echo "Release:"
	@echo "  make tag v<X.Y>[-rcN]  create a local annotated tag"

# ── git workflow ───────────────────────────────────────────────────────────
hooks:
	git config core.hooksPath .githooks
	@echo "hooks installed: $$(git config core.hooksPath)"

# ── l3build wrappers ───────────────────────────────────────────────────────
#
# `make check J=N` splits the test corpus into N parallel buckets via
# scripts/check-parallel.sh. We use an explicit J variable rather than
# `-j N` because GNU make's -j is jobserver-controlled and not reliably
# visible to recipes. Default J=1 -> plain `l3build check`.
J ?= 1

check:
	@if [ "$(J)" -gt 1 ]; then \
	    echo "make check J=$(J) -> check-parallel.sh"; \
	    LUATEX_BUCKETS=$(J) ./scripts/check-parallel.sh ; \
	else \
	    l3build check -q ; \
	fi

doc:
	l3build doc

ctan:
	l3build ctan

install:
	l3build install --full --dry-run

clean:
	l3build clean

# ── tag (release) ─────────────────────────────────────────────────────────
#
# Usage: make tag v<X.Y>[.<Z>][-rcN]   e.g. make tag v2.4 / make tag v2.4-rc1
#
# Pushing the tag (`git push origin <tag>`) is intentionally manual so
# operators can sanity-check the tag is on the expected commit and the
# version metadata in scholatex.cls / CHANGELOG.md is consistent.
#
# Implementation: take the first non-`tag` MAKECMDGOAL as the tag name,
# validate it against the v<X.Y>[.<Z>][-rcN] regex, and create an annotated
# git tag locally. A phony noop rule for the tag name silences make's
# "no rule to make target" complaint.

TAG_NAME := $(firstword $(filter-out tag,$(MAKECMDGOALS)))

tag:
	@if [ -z "$(TAG_NAME)" ]; then \
	    echo "usage: make tag v<X.Y>[.<Z>][-rcN]" >&2; \
	    echo "       e.g. make tag v2.4 / make tag v2.4-rc1" >&2; \
	    exit 1; \
	fi
	@if ! printf '%s' "$(TAG_NAME)" | grep -qE '^v[0-9]+\.[0-9]+(\.[0-9]+)?(-rc[0-9]+)?$$'; then \
	    echo "tag '$(TAG_NAME)' must match v<X.Y>[.<Z>][-rcN]" >&2; \
	    echo "e.g. v2.4 / v2.4.0 / v2.4-rc1" >&2; \
	    exit 1; \
	fi
	@if git rev-parse -q --verify "refs/tags/$(TAG_NAME)" >/dev/null 2>&1; then \
	    echo "tag '$(TAG_NAME)' already exists locally" >&2; \
	    echo "to delete: git tag -d $(TAG_NAME)" >&2; \
	    exit 1; \
	fi
	git tag -a "$(TAG_NAME)" -m "$(TAG_NAME)"
	@echo ""
	@echo "tag '$(TAG_NAME)' created at $$(git rev-parse --short HEAD)"
	@echo "next: git push origin $(TAG_NAME)"
	@echo "      (release.yml then builds the CTAN zip and creates a GitHub prerelease)"

# Phony noop so make doesn't complain about an unknown target when the
# tag name appears as a second MAKECMDGOAL.
ifneq ($(filter tag,$(MAKECMDGOALS)),)
ifneq ($(TAG_NAME),)
.PHONY: $(TAG_NAME)
$(TAG_NAME):
	@:
endif
endif
