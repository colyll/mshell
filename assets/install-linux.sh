#!/usr/bin/env bash
#
# Install ashell's icon + desktop entry on Linux so the GNOME/Ubuntu dock and
# the app launcher show the app icon.
#
# Why this is needed: the Windows build embeds the icon in the .exe, but on Linux
# the icon comes from a freedesktop ".desktop" entry plus an icon installed into
# the hicolor icon theme. On Wayland (Ubuntu's default) the shell matches a
# running window to its .desktop file via the window's app_id — ashell sets
# that to "ashell" (slint::set_xdg_app_id), and this script's StartupWMClass
# matches it.
#
# Usage:
#   ./install-linux.sh [/path/to/ashell-binary]
# You normally don't need an argument: when run from inside a release package
# (the `ashell` binary sits next to this script) it is picked up automatically.
# In the source tree it falls back to ./target/release/ashell.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve the binary: explicit arg > sibling (release package) > source-tree build.
if [ -n "${1:-}" ]; then
    BIN="$1"
elif [ -x "$SCRIPT_DIR/ashell" ]; then
    BIN="$SCRIPT_DIR/ashell"
else
    BIN="$SCRIPT_DIR/../target/release/ashell"
fi
BIN="$(readlink -f "$BIN" 2>/dev/null || echo "$BIN")"

# Make sure the binary is executable (a downloaded tarball may have lost +x).
[ -f "$BIN" ] && chmod +x "$BIN" 2>/dev/null || true

if [ ! -x "$BIN" ]; then
    echo "error: ashell binary not found: $BIN" >&2
    echo "Run this script from the extracted release folder (it sits next to the" >&2
    echo "'ashell' binary), or pass the binary path as an argument." >&2
    exit 1
fi

ICON_SRC="$SCRIPT_DIR/icon@512.png"
ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"
APP_DIR="$HOME/.local/share/applications"

mkdir -p "$ICON_DIR" "$APP_DIR"
if [ -f "$ICON_SRC" ]; then
    install -m644 "$ICON_SRC" "$ICON_DIR/ashell.png"
else
    echo "warning: icon not found ($ICON_SRC); the desktop entry will use a generic icon" >&2
fi

cat > "$APP_DIR/ashell.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=ashell
GenericName=SSH Client
Comment=Lightweight Rust + Slint SSH/SFTP client
Comment[zh_CN]=轻量级 Rust + Slint SSH/SFTP 客户端
Exec=$BIN
Icon=ashell
Terminal=false
Categories=Network;System;TerminalEmulator;Utility;
Keywords=ssh;sftp;terminal;shell;
StartupNotify=true
StartupWMClass=ashell
EOF
chmod 644 "$APP_DIR/ashell.desktop"

# Refresh the desktop + icon caches (best-effort; harmless if the tools are absent).
update-desktop-database "$APP_DIR" 2>/dev/null || true
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo "Installed:"
echo "  icon    -> $ICON_DIR/ashell.png"
echo "  desktop -> $APP_DIR/ashell.desktop"
echo "  exec    -> $BIN"
echo
echo "If the dock still shows the generic icon, log out/in (Wayland) or run"
echo "'killall -3 gnome-shell' (X11) to refresh the shell."
