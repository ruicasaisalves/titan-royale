#!/bin/bash
# Instala o Godot 4.2 (headless) nas sessões do Claude Code on the web,
# para permitir validar/correr o projeto por linha de comandos.
# No PC local não faz nada (o editor gráfico instala-se manualmente).
set -euo pipefail

# Só corre no ambiente remoto (Claude Code on the web).
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

GODOT_VERSION="4.2.2-stable"
GODOT_FILE="Godot_v${GODOT_VERSION}_linux.x86_64"
INSTALL_DIR="$HOME/.local/godot"
BIN_DIR="$HOME/.local/bin"
GODOT_BIN="$BIN_DIR/godot"

# Deixa o comando 'godot' disponível no PATH desta sessão.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi
export PATH="$BIN_DIR:$PATH"

# Idempotente: se a versão certa já estiver instalada, não descarrega de novo.
if [ -x "$GODOT_BIN" ] && "$GODOT_BIN" --version 2>/dev/null | grep -q "4.2.2.stable"; then
  echo "Godot ${GODOT_VERSION} já instalado ($GODOT_BIN)."
  exit 0
fi

mkdir -p "$INSTALL_DIR" "$BIN_DIR"

# Descarrega do GitHub Releases (o único host acessível pela política de rede).
URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${GODOT_FILE}.zip"
echo "A descarregar Godot ${GODOT_VERSION}..." >&2
curl -fsSL --retry 3 --retry-delay 2 -o "$INSTALL_DIR/godot.zip" "$URL"
unzip -o -q "$INSTALL_DIR/godot.zip" -d "$INSTALL_DIR"
rm -f "$INSTALL_DIR/godot.zip"
chmod +x "$INSTALL_DIR/$GODOT_FILE"
ln -sf "$INSTALL_DIR/$GODOT_FILE" "$GODOT_BIN"

echo "Godot ${GODOT_VERSION} instalado em $GODOT_BIN"
