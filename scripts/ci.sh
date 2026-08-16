#!/usr/bin/env bash
# Reproduz a ordem de `.github/workflows/ci.yml` no Linux.
# Uso: ./scripts/ci.sh
# Não é Play: o `rojo build` só valida a árvore. O artefato vai para /tmp
# de propósito — o place de trabalho continua sendo o gerado por
# scripts/build-studio.ps1 (docs/12 §2). A auditoria visual só confere
# hashes/vereditos; o snapshot canônico confere contagens, catálogos e docs.
# Nenhum dos dois importa PNG nem publica ID.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PATH="${HOME}/.aftman/bin:${HOME}/.local/bin:${PATH}"

stylua --check src tests plugins scripts
selene src tests plugins scripts
python3 scripts/audit_visual_assets.py --check
python3 scripts/audit_snapshot.py --check
lune run tests/run.luau
lune run tests/animation.luau
lune run tests/security_fuzz.luau
lune run tests/combat_e2e.luau
wally install
mkdir -p Packages
rojo build -o /tmp/build.rbxl

BYTES="$(wc -c < /tmp/build.rbxl | tr -d ' ')"
echo "CI local ok — /tmp/build.rbxl ${BYTES} bytes (não é o place de Play)"
