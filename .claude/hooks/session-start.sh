#!/bin/bash
# Prepara las sesiones de Claude Code:
# - en la nube instala lo que necesitan las skills "watch" (ffmpeg, yt-dlp) e "impeccable" (su engine);
# - en cualquier entorno ejecuta el hook de inicio de "impeccable".
set -euo pipefail

input="$(cat || true)"
cd "${CLAUDE_PROJECT_DIR:-.}"

if [ "${CLAUDE_CODE_REMOTE:-}" = "true" ]; then
  {
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

    # Engine de impeccable desde npm (la red de la nube bloquea las descargas de GitHub Releases).
    # Se verifica contra engine-checksums.txt, que viene con la skill.
    skill=.claude/skills/impeccable/scripts
    if [ -f "$skill/VERSION" ] && [ "$(uname -s)-$(uname -m)" = "Linux-x86_64" ]; then
      eng_ver="$(cat "$skill/VERSION")"
      eng="$HOME/.impeccable/bin/$eng_ver/impeccable"
      if [ ! -x "$eng" ]; then
        expected="$(awk -v v="$eng_ver" '$1==v && $2=="impeccable-linux-x64" {print $3}' "$skill/engine-checksums.txt")"
        tmp="$(mktemp -d)"
        (cd "$tmp" && npm pack -q "@impeccable/cli-linux-x64@$eng_ver" >/dev/null && tar xzf ./*.tgz)
        actual="$(sha256sum "$tmp/package/bin/impeccable" | cut -d' ' -f1)"
        if [ -z "$expected" ] || [ "$actual" != "$expected" ]; then
          echo "impeccable: la huella del engine no coincide; no se instaló" >&2
          rm -rf "$tmp"
          exit 1
        fi
        mkdir -p "$(dirname "$eng")"
        install -m 755 "$tmp/package/bin/impeccable" "$eng"
        rm -rf "$tmp"
      fi
    fi
  } 1>&2
fi

# Hook de inicio de impeccable (después de instalar su engine, para no competir con la instalación)
launcher=.claude/skills/impeccable/scripts/impeccable
if [ -f "$launcher" ]; then
  printf '%s' "$input" | "$launcher" hook || true
fi
