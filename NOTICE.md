# NOTICE

This repository packages and redistributes upstream software published by the
[delta](https://dandavison.github.io/delta/) project. The Apache-2.0 license in
[`LICENSE`](LICENSE) covers the OCX pipeline files authored here. It does
**not** cover any upstream-derived asset — each package's redistributed bytes
carry their own license, recorded below.

Each package's logo is an original mark authored for this repository for
catalog identification only; upstream publishes no logo. It implies no
endorsement.

| Package | GHCR path | Upstream SPDX |
|---|---|---|
| `delta` | `ghcr.io/ocx-contrib/delta/delta` | `MIT` |

---

## `delta`

Upstream: <https://github.com/dandavison/delta>
Published to `ghcr.io/ocx-contrib/delta/delta`.

| Component | SPDX | Holder |
|---|---|---|
| delta (`delta`) | **MIT** | Dan Davison |

The MIT License grants redistribution of the compiled binary in source and
binary forms, on the single condition that the copyright notice and permission
notice accompany it. That notice ships inside the mirrored archives — every
upstream archive carries its own `LICENSE` file beside the executable,
republished unmodified — and is reproduced by reference here.

The published binaries statically link third-party Rust crates under their own
permissive licenses, including the syntax definitions and themes vendored from
`bat`/`syntect`; the crate set is enumerated in the `Cargo.lock` of the
corresponding upstream source tag.

No modifications are made to any upstream artifact in this repository; they are
republished byte-for-byte inside an OCX bundle.
