#!/usr/bin/env bash
# verifica_ambiente.sh : confere o toolchain do MicroProj (R7).
#  1. GHDL instalado e versão;
#  2. VHDL-2008 (--std=08) funcionando: analisa, elabora e roda um teste de fumaça;
#  3. uma workdir própria por organização (build/o1, build/o2);
#  4. GTKWave instalado (apenas aviso, não é obrigatório para rodar o script).
# Uso: bash scripts/verifica_ambiente.sh   (de qualquer diretório)
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SMOKE="$RAIZ/scripts/smoke/smoke_tb.vhd"
ORGS=(o1 o2)

erro() { echo "ERRO: $*" >&2; exit 1; }

# 1. GHDL
command -v ghdl >/dev/null 2>&1 \
  || erro "ghdl não encontrado no PATH. Veja docs/ambiente.md para instalar."
echo "== ghdl --version"
ghdl --version

# 2 e 3. Smoke test VHDL-2008 em cada workdir
for org in "${ORGS[@]}"; do
  wd="$RAIZ/build/$org"
  mkdir -p "$wd"
  echo "== [$org] analisando, elaborando e rodando o smoke test em build/$org"
  # Roda dentro da workdir para que executáveis gerados (backends llvm/gcc)
  # fiquem em build/ e não sujem a raiz do repositório.
  (
    cd "$wd" &&
      ghdl -a --std=08 --workdir="$wd" "$SMOKE" &&
      ghdl -e --std=08 --workdir="$wd" smoke_tb &&
      ghdl -r --std=08 --workdir="$wd" smoke_tb
  ) || erro "falha no smoke test VHDL-2008 em build/$org"
  [[ -f "$wd/work-obj08.cf" ]] || erro "build/$org/work-obj08.cf não foi gerado"
done

# Workdirs independentes: cada uma com sua própria biblioteca work.
[[ "$(realpath "$RAIZ/build/o1/work-obj08.cf")" != "$(realpath "$RAIZ/build/o2/work-obj08.cf")" ]] \
  || erro "build/o1 e build/o2 apontam para a mesma biblioteca"

# 4. GTKWave (opcional)
if command -v gtkwave >/dev/null 2>&1; then
  echo "== gtkwave: $(gtkwave --version 2>&1 | head -n 1)"
else
  echo "AVISO: gtkwave não encontrado; as waveforms .ghw não poderão ser abertas." >&2
fi

echo "OK: ambiente pronto (GHDL + VHDL-2008, workdirs build/o1 e build/o2)."
