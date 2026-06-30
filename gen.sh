#!/bin/sh
# Compile each themes/<name>/ folder theme into a single-file .qbtheme using
# Qt's resource compiler (rcc). The folder themes are already usable on their
# own (select themes/<name>/config.json in qBittorrent); this just produces the
# portable single-file equivalents under dist/.
#
# Requires Qt 6. If you do not have Qt installed, the release .qbtheme files are
# built automatically by GitHub Actions instead.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# Locate rcc. Qt 6 installs it under libexec (not bin), so a bare `rcc` is
# often not on PATH even when Qt is present; ask qmake where it lives.
rcc=""
for c in rcc rcc-qt6; do
    if command -v "$c" >/dev/null 2>&1; then rcc=$(command -v "$c"); break; fi
done
if [ -z "$rcc" ]; then
    for qm in qmake qmake6; do
        command -v "$qm" >/dev/null 2>&1 || continue
        for key in QT_INSTALL_LIBEXECS QT_INSTALL_BINS; do
            d=$("$qm" -query "$key" 2>/dev/null || true)
            if [ -n "$d" ] && [ -x "$d/rcc" ]; then rcc="$d/rcc"; break; fi
        done
        [ -n "$rcc" ] && break
    done
fi
if [ -z "$rcc" ] && [ -n "${QT_ROOT_DIR:-}" ]; then
    for d in "$QT_ROOT_DIR/libexec" "$QT_ROOT_DIR/bin"; do
        if [ -x "$d/rcc" ]; then rcc="$d/rcc"; break; fi
    done
fi
[ -n "$rcc" ] || { echo "error: rcc (Qt resource compiler) not found; install Qt 6 or add rcc to PATH" >&2; exit 1; }

out="$root/dist"
mkdir -p "$out"

for src in "$root"/themes/*/; do
    name=$(basename -- "$src")
    qrc="$src/theme.qrc"
    {
        printf '<!DOCTYPE RCC><RCC version="1.0">\n<qresource prefix="/">\n'
        ( cd "$src" && find . -type f ! -name '*.qrc' | sed 's#^\./##' | sort \
            | while IFS= read -r f; do printf '  <file>%s</file>\n' "$f"; done )
        printf '</qresource>\n</RCC>\n'
    } > "$qrc"
    "$rcc" --no-compress -binary "$qrc" -o "$out/qbittorrent-fusion-$name.qbtheme"
    rm -f "$qrc"
    printf 'built  %s\n' "$out/qbittorrent-fusion-$name.qbtheme"
done
