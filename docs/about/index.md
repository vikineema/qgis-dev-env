<!--
SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
SPDX-License-Identifier: MIT
-->

# About

`qgis-dev-env` is developer tooling from [Kartoza](https://kartoza.com)
for working on QGIS core with NixOS, Nix flakes and Neovim — built around
one hard constraint: **nothing from this environment may ever reach
upstream QGIS**, where AI contributions are not accepted.

- [FAQ](faq.md) — common questions (why Neovim not Qt Creator, the first
  download, incremental builds, and more).
- [AI policy](ai-policy.md) — the rule, the boundary, and the
  acknowledgement every contributor makes.
- [Specification](specification.md) — the complete SRS: requirements,
  design decisions, acceptance criteria and roadmap.

## Licence

MIT for everything in this repository. The tooling orchestrates local
builds of QGIS (GPL-2.0-or-later) but links nothing, so no copyleft
obligation attaches to the tooling itself. Every file carries an SPDX
header; `reuse lint` runs in CI.

## Credits

Theming and documentation approach adapted from
[kartoza/InfrastructureMapper](https://github.com/kartoza/InfrastructureMapper).
Editor by [timlinux/nix-vim](https://github.com/timlinux/nix-vim).

---

*Made with 💗 by [Kartoza](https://kartoza.com) ·
[Donate!](https://github.com/sponsors/timlinux) ·
[GitHub](https://github.com/timlinux/qgis-dev-env)*
