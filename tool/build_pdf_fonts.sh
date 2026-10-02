#!/usr/bin/env bash
#
# Regenerate the three static Schibsted Grotesk instances the PDF exporter
# uses.
#
# The app itself ships ONE font file —
# assets/fonts/SchibstedGrotesk-Variable.ttf — and Flutter maps FontWeight onto
# its wght axis. `package:pdf` cannot: it parses a TTF's `glyf` outlines and
# ignores `gvar`, so handing it the variable file three times renders medium and
# bold at regular and silently flattens every report's hierarchy. So the
# exporter gets three instanced, subset faces.
#
# Subset to Latin + Latin-Ext (the app ships `en` and `af`) plus the general
# punctuation, currency and dash/quote range the formatters actually emit —
# a true minus (U+2212), an em dash for a null figure, curly quotes, the rand
# sign. ~50 KB each instead of ~176 KB.
#
# Schibsted Grotesk's wght axis is **400–900**, not Onest's 100–900, so 400 is
# the axis minimum rather than a point inside it. Nothing in the app asks for a
# weight under 400 (the scale uses 400/500/600/700 only), so the narrower axis
# costs nothing — but an instancer call for `wght=300` would silently clamp.
#
# Run it after changing the Schibsted Grotesk version, and commit the three
# .ttf files.
#
#   tool/build_pdf_fonts.sh
#
set -euo pipefail

cd "$(dirname "$0")/.."
src="app/assets/fonts/SchibstedGrotesk-Variable.ttf"
out="app/assets/fonts"

[ -f "$src" ] || { echo "Missing $src" >&2; exit 1; }

command -v fonttools >/dev/null 2>&1 || {
  echo "fonttools is not on PATH. Install it into a virtualenv:" >&2
  echo "  python3 -m venv .venv && .venv/bin/pip install fonttools brotli" >&2
  echo "  PATH=\$PWD/.venv/bin:\$PATH tool/build_pdf_fonts.sh" >&2
  exit 1
}

# Latin, Latin-1 Supplement, Latin Extended-A/B, General Punctuation,
# Currency Symbols, the trademark sign, the true minus, dashes and quotes.
#
# Latin Extended-B is SPARSER here than it was in Onest (22 codepoints against
# 61). The range stays declared because every character the
# `en` and `af` translations actually use is present and
# `torchlight_glyph_coverage_test.dart` checks that against the committed
# binaries; a sparse range is normal and the guard only fails on a range that
# comes back wholly empty.
unicodes='U+0000-00FF,U+0100-017F,U+0180-024F,U+2000-206F,U+20A0-20BF,U+2122,U+2212,U+2013,U+2014,U+2018-201F,U+2026'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for weight in 400 500 700; do
  fonttools varLib.instancer -q "$src" "wght=$weight" -o "$tmp/sg-$weight.ttf"
  pyftsubset "$tmp/sg-$weight.ttf" \
    --unicodes="$unicodes" \
    --layout-features='*' \
    --name-IDs='*' \
    --output-file="$out/SchibstedGrotesk-Pdf-$weight.ttf"
  printf '%s  %s\n' \
    "$(du -h "$out/SchibstedGrotesk-Pdf-$weight.ttf" | cut -f1)" \
    "SchibstedGrotesk-Pdf-$weight.ttf"
done

echo "Done. app/test/core/theme/schibsted_font_test.dart asserts these ship."
