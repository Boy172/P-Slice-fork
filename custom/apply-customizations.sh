#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "== P-Slice: aplicando personalizaciones =="

# 1. Copiar archivos fuente personalizados conservando sus rutas.
if [[ -d "custom/source" ]]; then
  echo "Copiando custom/source/ sobre source/ ..."
  mkdir -p source
  cp -a custom/source/. source/
fi

# 2. Aplicar parches Git.
shopt -s nullglob
patches=(custom/patches/*.patch)
for patch_file in "${patches[@]}"; do
  echo "Aplicando parche: $patch_file"
  if git apply --check "$patch_file"; then
    git apply "$patch_file"
  elif git apply --reverse --check "$patch_file"; then
    echo "El parche ya estaba aplicado; se omite."
  else
    echo "::error::El parche no se puede aplicar: $patch_file"
    exit 1
  fi
done

# 3. Ejecutar scripts shell personalizados en orden alfabético.
scripts=(custom/scripts/*.sh)
for script_file in "${scripts[@]}"; do
  echo "Ejecutando script: $script_file"
  bash "$script_file"
done

echo "== Personalizaciones aplicadas correctamente =="
