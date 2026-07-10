#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
# SPDX-License-Identifier: MIT
#
# Assemble the developer handbook into a Kartoza-branded PDF via
# pandoc + pdflatex (approach copied from kartoza/qgis-desktop-docker).
# Invoked by `nix run .#handbook-pdf -- [output.pdf]`, which provides the
# toolchain on PATH and these env vars:
#   QDE_DOCS_DIR   docs/ tree (store path in CI, worktree locally)
#   QDE_SPEC_FILE  SPECIFICATION.md (inlined into the About chapter)
#   QDE_PDF_DIR    docs/pdf (preamble.tex, cover.tex)
set -euo pipefail

DOCS_DIR="${QDE_DOCS_DIR:?QDE_DOCS_DIR not set (run via nix run .#handbook-pdf)}"
SPEC_FILE="${QDE_SPEC_FILE:?QDE_SPEC_FILE not set}"
PDF_DIR="${QDE_PDF_DIR:?QDE_PDF_DIR not set}"

OUT="${1:-qgis-dev-env-handbook.pdf}"
case "$OUT" in
/*) OUT_ABS="$OUT" ;;
*) OUT_ABS="$PWD/$OUT" ;;
esac

WORK="$(mktemp -d -t qde-handbook-pdf.XXXXXX)"
_cleanup() {
  rc=$?
  if [ "$rc" -eq 0 ]; then
    rm -rf "$WORK"
  else
    echo "handbook-pdf failed; kept work dir at: $WORK" >&2
  fi
  exit "$rc"
}
trap _cleanup EXIT

# Chapter order — keep in sync with the nav in mkdocs.yml.
PAGES=(
  "index.md"
  "getting-started/index.md"
  "getting-started/01-checkout-qgis.md"
  "getting-started/02-embed-sidecar.md"
  "getting-started/03-bootstrap.md"
  "getting-started/04-first-compile.md"
  "getting-started/05-neovim.md"
  "getting-started/06-precommit.md"
  "getting-started/07-first-patch.md"
  "reference/index.md"
  "reference/qgis-dev.md"
  "reference/keymap.md"
  "reference/profiles.md"
  "reference/worktrees.md"
  "reference/qa.md"
  "reference/troubleshooting.md"
  "about/index.md"
  "about/ai-policy.md"
  "about/specification.md"
)

# Per-page transform: mkdocs-flavoured markdown → pandoc/pdflatex-safe.
#  * inline the pymdownx snippet include of SPECIFICATION.md
#  * replace mermaid fences with a pointer to the online handbook
#  * flatten admonitions (titled and untitled) to bold labels, dedenting
#    their 4-space bodies so pandoc doesn't render them as code blocks
#  * drop grid-card / raw-HTML wrappers, ++key++ markup
#  * transliterate unicode pdflatex has no glyphs for
# shellcheck disable=SC2016  # literal backticks in a sed replacement below
transform() {
  gawk -v spec="$SPEC_FILE" '
    /^--8<-- "SPECIFICATION\.md"$/ {
      while ((getline line < spec) > 0) print line
      close(spec); next
    }
    /^```mermaid/ { inmermaid = 1; print "*(Diagram - see the online handbook.)*"; next }
    inmermaid && /^```/ { inmermaid = 0; next }
    inmermaid { next }
    /^!!! [a-z]+ ".*"$/ {
      match($0, /^!!! [a-z]+ "(.*)"$/, m)
      split($0, w, " ")
      printf "**%s%s: %s**\n", toupper(substr(w[2],1,1)), substr(w[2],2), m[1]
      inadmon = 1; next
    }
    /^!!! [a-z]+$/ {
      split($0, w, " ")
      printf "**%s%s:**\n", toupper(substr(w[2],1,1)), substr(w[2],2)
      inadmon = 1; next
    }
    inadmon && /^    / { print substr($0, 5); next }
    inadmon && /^$/ { print; next }
    { inadmon = 0; print }
  ' "$1" |
    sed \
      -e '/^<div/d' -e '/^<\/div>/d' \
      -e 's/++\([a-zA-Z-]*\)++/`\1`/g' \
      -e 's/💗/love/g' \
      -e 's/🚀 \?//g' -e 's/⌨ \?//g' -e 's/🔒 \?//g' -e 's/📐 \?//g' \
      -e 's/🔧 \?//g' -e 's/🧭 \?//g' -e 's/️ \?//g' \
      -e 's/⚠/WARNING /g' \
      -e 's/✓/OK/g' -e 's/✗/X/g' \
      -e 's/≥/>=/g' -e 's/≤/<=/g' -e 's/≈/~/g' \
      -e 's/·/-/g' \
      -e 's/—/--/g' -e 's/–/-/g' \
      -e 's/…/.../g' \
      -e 's/→/->/g' -e 's/←/<-/g' -e 's/⇒/=>/g' \
      -e 's/§/Section /g' \
      -e 's/│/|/g' -e 's/└/`/g' -e 's/├/|/g' -e 's/─/-/g' \
      -e 's/×/x/g'
}

{
  cat <<'META'
---
title: QGIS Dev Env
subtitle: Developer Handbook
lang: en
---

META
  chapter=0
  for page in "${PAGES[@]}"; do
    chapter=$((chapter + 1))
    [ "$chapter" -gt 1 ] && printf '\n\n\\newpage\n\n'
    transform "$DOCS_DIR/$page"
  done
} >"$WORK/combined.md"

cp "$PDF_DIR/preamble.tex" "$WORK/preamble.tex"
cp "$PDF_DIR/cover.tex" "$WORK/cover.tex"
cp "$DOCS_DIR/assets/brand/kartoza-logo-vertical-reversed.png" "$WORK/cover-logo.png"

mkdir -p "$WORK/texout"
cd "$WORK"
pandoc combined.md \
  --pdf-engine=pdflatex \
  --pdf-engine-opt=-interaction=nonstopmode \
  --pdf-engine-opt=-output-directory="$WORK/texout" \
  --resource-path=".:$DOCS_DIR:$DOCS_DIR/about:$DOCS_DIR/getting-started:$DOCS_DIR/reference" \
  --include-in-header=preamble.tex \
  --include-before-body=cover.tex \
  --toc --toc-depth=2 \
  -V fontfamily=lato \
  -V fontfamilyoptions=default \
  -V geometry:margin=2.5cm \
  -V colorlinks=true \
  -V linkcolor=kartozablue \
  -V urlcolor=kartozablue \
  -V toccolor=kartozablue \
  -V documentclass=article \
  -o "$OUT_ABS"

echo ""
echo "Wrote $OUT_ABS"
