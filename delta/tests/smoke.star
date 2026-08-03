# delta/tests/smoke.star — stable across upstream releases.
#
# delta is a VIEWER for a unified diff, not a differ: it reads `git diff`
# output on stdin, re-renders it and writes the result. That is the contract
# these assertions check — never help/version prose.
#
# Three properties this file is written around, all measured on 0.19.2:
#
#   1. Output is HEAVILY colorized and the SGR lands PER TOKEN — one plus line
#      renders as `ESC[48;…m    ESC[38;…mreturn ESC[38;…m"ESC[48;…mquasar…`.
#      A multi-word plain substring is therefore never contiguous, so every
#      content assertion below is a SINGLE token, and the two tokens on each
#      side of a change share no substring (`xylophone`→`quasar`,
#      `flugelhorn`→`zeppelin`) so delta's intra-line word highlighter cannot
#      split one across an escape either.
#   2. delta ALWAYS colorizes. NO_COLOR=1, TERM=dumb and a non-tty stdout were
#      all measured to change nothing (68 escapes in every case), so asserting
#      that SGR is present is stable rather than environment-dependent.
#   3. Every knob these assertions depend on is PINNED BY A FLAG, never left to
#      a delta default: `--no-gitconfig` (a developer's ~/.gitconfig can define
#      delta features that rewrite the output), `--paging never`, `--width`,
#      `--true-color`, and the two `omit` styles. `DELTA_FEATURES` is the one
#      remaining ambient input and is cleared through the env overlay.
#
# delta needs neither `git` on PATH nor a HOME to render a diff from stdin —
# verified with `env -i PATH=/nonexistent HOME=/nonexistent` — which is what
# makes it testable inside a stock ubuntu/alpine/fedora container leg.

DELTA = "delta.exe" if ocx.target_platform.os == ocx.os.Windows else "delta"

# Cleared, not inherited: DELTA_FEATURES names delta features from the
# environment and would otherwise reshape everything asserted below. `env=` is
# an overlay on the composed bundle env, so PATH survives it.
ENV = {"DELTA_FEATURES": ""}

# Hermetic input: a two-file unified diff, fed on stdin. Two changed lines per
# side, four content tokens, and the four-line `diff --git`/`index`/`---`/`+++`
# header block per file that Tier 3a below proves delta CONSUMES.
DIFF = """diff --git a/hello.py b/hello.py
index 1111111..2222222 100644
--- a/hello.py
+++ b/hello.py
@@ -1,3 +1,3 @@
 def greet(name):
-    return "xylophone"
+    return "quasar"

diff --git a/notes.txt b/notes.txt
index 3333333..4444444 100644
--- a/notes.txt
+++ b/notes.txt
@@ -1,2 +1,2 @@
 first line
-flugelhorn
+zeppelin
"""

# Tier 1 + 2: liveness on the composed PATH + version SHAPE (not the vendor
# banner, not the exact version — the digits are the contract).
r_version = ocx.run(DELTA, "--version")
expect.ok(r_version)
expect.matches(r_version.stdout, r"\d+\.\d+\.\d+")

# ── Tier 3a: delta REWRITES the diff ────────────────────────────────────────
#
# `--file-style omit --hunk-header-style omit` strips every decoration whose
# format is a delta default, leaving only content lines — so what remains is
# fully determined by the flags set here.
#
# Each filename appears FOUR times in DIFF (the `diff --git` line twice, then
# `---` and `+++`). After rendering it appears ZERO times: delta parsed that
# header block and emitted its own file section, which `omit` then removed. A
# tool that merely echoed stdin would score 4. Measured on 0.19.2: 4 → 0.
r_render = ocx.run(
    DELTA, "--no-gitconfig", "--paging", "never", "--width", "120",
    "--true-color", "always", "--file-style", "omit",
    "--hunk-header-style", "omit",
    stdin = DIFF, env = ENV,
)
expect.ok(r_render)
expect.eq(r_render.stdout.count("hello.py"), 0)
expect.eq(r_render.stdout.count("notes.txt"), 0)

# …and the hunk content survived that rewrite intact: every changed line is
# present EXACTLY once, both sides of both changes. This is the changed-line
# count — two removed, two added, no line dropped and none duplicated.
expect.eq(r_render.stdout.count("xylophone"), 1)
expect.eq(r_render.stdout.count("quasar"), 1)
expect.eq(r_render.stdout.count("flugelhorn"), 1)
expect.eq(r_render.stdout.count("zeppelin"), 1)

# Colorization ran. Asserting the escape INTRODUCER only — the specific SGR
# parameters are theme data, not a contract.
expect.matches(r_render.stdout, r"\x1b\[")

# ── Tier 3b: `--color-only` is structure-preserving, and provably so ────────
#
# Documented as "do not alter the input structurally in any way, but color and
# highlight hunk lines". That gives an exact invariant with no format string
# behind it: the render has the SAME line count as the input, and the header
# lines Tier 3a saw consumed are here still present, all four per file.
r_color_only = ocx.run(
    DELTA, "--no-gitconfig", "--paging", "never", "--width", "120",
    "--true-color", "always", "--color-only",
    stdin = DIFF, env = ENV,
)
expect.ok(r_color_only)
expect.eq(r_color_only.stdout.count("\n"), DIFF.count("\n"))
expect.eq(r_color_only.stdout.count("hello.py"), 4)
expect.eq(r_color_only.stdout.count("notes.txt"), 4)
expect.eq(r_color_only.stdout.count("xylophone"), 1)
expect.eq(r_color_only.stdout.count("zeppelin"), 1)
expect.matches(r_color_only.stdout, r"\x1b\[")

# The two modes must genuinely differ — equal renders would mean the rendering
# mode did no structural work, and would also mean one of the two blocks above
# is asserting nothing. Neither may equal the input, which carries no SGR at
# all: that is the other half of the colorization proof.
expect.ne(r_render.stdout, r_color_only.stdout)
expect.ne(r_render.stdout, DIFF)
expect.ne(r_color_only.stdout, DIFF)

# No Tier 4: metadata.json declares PATH only (proven by Tier 1 liveness).
