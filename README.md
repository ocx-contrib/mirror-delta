# mirror-delta

OCX mirror for [delta](https://dandavison.github.io/delta/), a
syntax-highlighting pager for git, diff, grep and blame output. One repository,
one spec directory per package.

| Package | Spec | Publishes to | Announced as | Upstream SPDX |
|---|---|---|---|---|
| [delta](https://github.com/dandavison/delta) | [`delta/mirror.yml`](delta/mirror.yml) | `ghcr.io/ocx-contrib/delta/delta` | [`ocx.sh/delta/delta`](https://index.ocx.sh/delta/delta) | `MIT` |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

`dandavison` is a personal handle rather than a vendor, so the tool names
itself: the package is `delta/delta`. The Rust **crate** is published as
`git-delta` (the name `delta` was taken on crates.io) and upstream's `.deb`
assets are named for the crate — but the project, the release archives and the
executable are all `delta`.

## Layout

```
mirror-base.yml         repo-wide policy every spec inherits via `extends:`
delta/
├── mirror.yml          the spec — never at the repo root
├── metadata.json       bundle interface
├── CATALOG.md          → ocx package describe
├── logo.svg / logo.png describe assets, 512px PNG
└── tests/smoke.star    Starlark smoke test
```

`LICENSE` and `NOTICE.md` are shared at the root. Logos are **not** — each
package carries its own, because a repo-root `logo.*` sits in no workflow's
`paths:` filter, so replacing it would publish nothing until some unrelated
edit happened to fire.

⚠️ `extends:` is a **shallow** merge of top-level keys. A spec that restates
`platforms:` to change one runner drops every `containers:` entry with it, and
nothing reds — the legs simply stop existing, and every `os.features` claim
goes back to being asserted rather than verified. This repo sidesteps the trap
structurally: it is single-package, `platforms:` lives only in
`mirror-base.yml`, and `delta/mirror.yml` never restates it.

## Platforms

OCX has exactly six platform keys. This mirror declares **four**, and the two
it omits are omitted because upstream ships nothing to put there — verified
against every in-range release, not assumed:

| Key | Asset carried | Why |
|---|---|---|
| `linux/amd64` — **bare** | `delta-<V>-x86_64-unknown-linux-musl.tar.gz` | static-pie: `readelf -l` reports **0** `INTERP` segments and `readelf -d` **no** `NEEDED`. It requires nothing of the host |
| `linux/arm64+libc.glibc` | `delta-<V>-aarch64-unknown-linux-gnu.tar.gz` | upstream ships **no** aarch64 musl asset. The gnu build carries `PT_INTERP /lib/ld-linux-aarch64.so.1` and `NEEDED libc.so.6` (max symbol `GLIBC_2.18`) |
| `darwin/arm64` | `delta-<V>-aarch64-apple-darwin.tar.gz` | the only macOS asset upstream ships on this train |
| `windows/amd64` | `delta-<V>-x86_64-pc-windows-msvc.zip` | the only Windows asset upstream has ever shipped |

**`darwin/amd64` is deliberately excluded**: upstream publishes no
`x86_64-apple-darwin` asset at 0.19.1 or 0.19.2. The Intel build *did* exist
through 0.18.2 (`delta-0.18.2-x86_64-apple-darwin.tar.gz`) and was dropped at
the 0.19 train. Declaring the key would resolve zero assets — silently skipped,
not an error — while still booting a macos-14 runner that greens having tested
nothing.

**`windows/arm64` is deliberately excluded**: `x86_64-pc-windows-msvc.zip` is
the only Windows asset in the release, at every version checked.

Upstream's remaining Linux assets — `arm-unknown-linux-gnueabihf` (armv7) and
`i686-unknown-linux-gnu` — have no OCX platform key at all: the ocx
`Architecture` enum is `amd64` and `arm64` only. The five `.deb` sidecars
(`git-delta_<V>_<arch>.deb`, plus `git-delta-musl_<V>_amd64.deb`) are named for
the crate, and every asset pattern in the spec anchors `^delta-` so a
`git-delta…` name can never match one.

`os.features` states what an artifact requires *of the host*, so a musl target
*triple* is not a musl *requirement*: tagging the static amd64 build
`+libc.musl` would be a false claim that hid it from every glibc host it in
fact runs on. The `alpine:3.20` container leg on the bare key is what turns its
universality claim into evidence; the `+libc.glibc` key gets **no** alpine leg,
because the binary genuinely cannot load under musl and the renderer rejects
that leg at spec load (exit 65). The measurements themselves are recorded above
the `assets:` block in `delta/mirror.yml`.

The amd64 `-gnu` build exists and is deliberately not carried. Publishing it
beside the static one under `+libc.glibc` is legal and resolves correctly by
specificity scoring, but it only buys something where musl's libc changes
behaviour a user can reach — canonically DNS/NSS resolution. delta renders a
diff read from stdin and opens no socket. (It also needs `GLIBC_2.34`, against
`GLIBC_2.18` for the aarch64 build — which is exactly why the two arches are
measured separately rather than assumed symmetric.)

## The version floor skips a broken release

`versions.min` is **0.19.1**, not the third-newest tag. **0.19.0 published four
assets** where every healthy release of this repo publishes twelve or thirteen
— only `aarch64-apple-darwin`, `x86_64-pc-windows-msvc`,
`x86_64-unknown-linux-musl` and one `.deb`. It is a CI failure on that tag that
was never backfilled, and the repo has form: 0.16.4 shipped five assets against
the same baseline. Three of the four declared keys would resolve **zero**
assets at 0.19.0, and a zero-match is silently skipped rather than an error —
so including it would ship a version with a missing `linux/arm64` and nothing
would red.

## The binaries claim

Every archive — tarball and zip alike — carries one wrapper directory named
after the asset (`delta-0.19.2-x86_64-unknown-linux-musl/`) holding exactly
three entries: `delta` (`delta.exe` in the zip) mode 0755, `LICENSE` and
`README.md`. There is no `bin/` subdirectory.

`strip_components: 1` is forced rather than chosen: the wrapper directory's
name embeds both the version and the target triple, so keeping it would need a
`PATH` value that changes with every release and differs per platform. After
the strip, `delta` sits at the content root and the bundle's only `PATH` entry
is a bare `${installPath}`.

`bin_scan` only looks *below* an `${installPath}/<dir>` entry, so with nothing
to inspect it would pass green whatever the archive contained, and `auto` /
`verify` are rejected at spec load with exit 65. `delta/mirror.yml` therefore
sets `bin_scan: "off"` and `delta/metadata.json` hand-lists `["delta"]` — the
blessed shape for this layout, and exactly what the error message directs.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `mirror-base.yml`, `delta/mirror.yml` | hand | yes — see below |
| `delta/{metadata.json,CATALOG.md,logo.*}` | hand | — |
| `delta/tests/smoke.star` | hand | — |
| `.github/workflows/*.yml` | **generated — never hand-edit** | re-run when a spec changes |

```bash
ocx-mirror package pipeline generate ci --spec delta/mirror.yml
```

**Name every spec.** `--spec` *appends* rather than replaces, so a command
naming a subset silently stops rendering the rest while staying green — and the
drift guard reds on a generated workflow the current spec set no longer
produces.

`verify-generated.yml` exits 65 on drift. If a generated workflow is wrong, the
spec or the renderer template is wrong — fix it there and regenerate.

Run `direnv allow` once to put the pinned toolchain on `PATH`, and invoke
`ocx-mirror` directly — never `ocx run -- ocx-mirror`, which pins
`OCX_BINARY_PIN` to the bootstrap `ocx` and false-reds the nested push.

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index pull request from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

(Inherited from the `ocx-contrib` org with visibility ALL. GHCR pushes use the
run's own `GITHUB_TOKEN` — no registry secret needed.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of scope; each
package's redistribution license is recorded in [`NOTICE.md`](NOTICE.md).
