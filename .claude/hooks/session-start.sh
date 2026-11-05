#!/bin/bash
# Instala yt-dlp, que necesita la skill "watch" (.claude/skills/watch), en sesiones en la nube.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-.}"

# ffmpeg/ffprobe: solo si faltan
if ! command -v ffmpeg >/dev/null || ! command -v ffprobe >/dev/null; then
  apt-get update
  apt-get install -y ffmpeg
fi

# yt-dlp en el Python del sistema; se omite si nada cambió desde la última instalación
pyhashes="$(python3 -I -c 'import sysconfig; print(sysconfig.get_path("purelib"))')/.session-start.sha256"
if ! command -v yt-dlp >/dev/null || ! sha256sum --check --status "$pyhashes" 2>/dev/null; then
  rm -f "$pyhashes"
  python3 -m pip install -q --upgrade "yt-dlp[default,curl-cffi]"
  sha256sum .claude/hooks/session-start.sh > "$pyhashes" || rm -f "$pyhashes"
fi
