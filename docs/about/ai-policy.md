<!--
SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
SPDX-License-Identifier: MIT
-->

# AI Policy

## The upstream rule

The QGIS project **does not accept AI-generated contributions**. Patches,
documentation and translations submitted to
[qgis/QGIS](https://github.com/qgis/QGIS) must be authored by you, the
human contributor. Consult upstream's
[CONTRIBUTING.md](https://github.com/qgis/QGIS/blob/master/CONTRIBUTING.md)
and current project policies for the authoritative wording — if it and
this page ever disagree, upstream wins.

## The apparent contradiction — and how we resolve it

This developer environment was itself built with AI assistance. Using it
to *prepare* QGIS contributions is fine; letting any of it *into* a QGIS
contribution is not. The boundary is enforced in three mechanical layers,
plus one human one:

1. **Local excludes** — every overlay file and the embedded
   `qgis-dev-env/` repo are registered in `.git/info/exclude`; upstream
   git cannot even see them.
2. **The anti-leak pre-push hook** — refuses to push any commit that
   touches an overlay path, defeating even `git add -f` accidents.
3. **`qgis-dev doctor`** — audits every worktree for isolation breaches
   on demand.
4. **You** — tooling can keep *files* apart; only you can keep *authorship*
   apart. Editor conveniences here (LSP completion, diagnostics,
   formatting) are conventional developer tooling; generating QGIS code
   with an AI assistant and submitting it is what the upstream policy
   forbids.

## The acknowledgement

Before your first patch (and implicitly with every one after), you
acknowledge:

- [x] My QGIS contributions are my own human-authored work.
- [x] I understand this environment is AI-assisted **tooling** and I will
      not represent AI-generated code as my own in upstream submissions.
- [x] I will keep the isolation mechanisms intact (no disabling the
      pre-push guard, no force-adding overlay files).

## In this repository, by contrast

`qgis-dev-env` itself is openly AI-assisted (see `PROMPT.log` practice in
the [SRS](specification.md)). Its scope is developer tooling that never
ships to upstream QGIS — which is precisely why the two policies can
coexist.
