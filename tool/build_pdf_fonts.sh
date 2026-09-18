#!/usr/bin/env bash
#
# Regenerate the three static Onest instances the PDF exporter uses.
#
# The app itself ships ONE font file — assets/fonts/Onest-Variable.ttf — and
# Flutter maps FontWeight onto its wght axis. `package:pdf` cannot: it parses a
# TTF's `glyf` outlines and ignores `gvar`, so handing it the variable file
# three times renders medium and bold at regular and silently flattens every
# report's hierarchy. So the exporter gets three instanced, subset faces.
#
# Subset to Latin + Latin-Ext (the app ships `en` and `af`) plus the general
# punctuation, currency and dash/quote range the formatters actually emit —
# a true minus (U+2212), an em dash for a null figure, curly quotes, the rand
# sign. ~50 KB each instead of ~190 KB.
#
# Run it after changing the Onest version, and commit the three .ttf files.
#
#   tool/build_pdf_fonts.sh
#
set -euo pipefail

cd "$(dirname "$0")/.."
src="app/assets/fonts/Onest-Variable.ttf"
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
unicodes='U+0000-00FF,U+0100-017F,U+0180-024F,U+2000-206F,U+20A0-20BF,U+2122,U+2212,U+2013,U+2014,U+2018-201F,U+2026'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for weight in 400 500 700; do
  fonttools varLib.instancer -q "$src" "wght=$weight" -o "$tmp/onest-$weight.ttf"
  pyftsubset "$tmp/onest-$weight.ttf" \
    --unicodes="$unicodes" \
    --layout-features='*' \
    --name-IDs='*' \
    --output-file="$out/Onest-Pdf-$weight.ttf"
  printf '%s  %s\n' "$(du -h "$out/Onest-Pdf-$weight.ttf" | cut -f1)" "Onest-Pdf-$weight.ttf"
done

echo "Done. app/test/core/theme/onest_font_test.dart asserts these ship."
