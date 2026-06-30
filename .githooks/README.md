# .githooks

Repository git hooks.

## Install (one-shot)

```bash
make hooks    # equivalent to: git config core.hooksPath .githooks
```

## Hook inventory

| hook | when | what it does | cost |
|---|---|---|---|
| `commit-msg` | on commit | enforce `type(scope): subject` format | milliseconds |

- The hook short-circuits in CI (`$CI` / `$GITHUB_ACTIONS`).
- Emergency bypass: `git commit --no-verify` (use sparingly).

## `commit-msg` allowed types

`feat fix doc docs test chore perf refactor ci bench build revert`

Scope is optional, character set `[A-Za-z0-9/_., -]+`. Mixed case, commas and
spaces are allowed so multi-module entries like `chore(math, figure): ...`
work.

Auto-messages that bypass the check:
`Merge ...` / `Revert ...` / `fixup! ...` / `squash! ...`.

Examples:

- ✓ `feat(math): add Hadamard product to mathlite vocabulary`
- ✓ `docs(llmdoc): bootstrap stable knowledge base`
- ✓ `chore(math, figure): align upright-d rendering between modules`
- ✗ `update README` (no type)
- ✗ `WIP` (no `: `)
