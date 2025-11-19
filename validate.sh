#!/usr/bin/env bash
set -euo pipefail

# Ejecutables esperados:
#   ./gen_text      -> generador de texto aleatorio (del taller SIMD)
#   ./serial        -> versión serial (CPU)
#   ./cuda_conv     -> versión CUDA (GPU)

if [[ ! -x ./gen_text ]]; then
  echo "ERROR: ./gen_text no existe o no es ejecutable"
  exit 1
fi
if [[ ! -x ./serial ]]; then
  echo "ERROR: ./serial no existe o no es ejecutable"
  exit 1
fi
if [[ ! -x ./cuda_conv ]]; then
  echo "ERROR: ./cuda_conv no existe o no es ejecutable"
  exit 1
fi

# Algunos tamaños de prueba (puedes ajustar)
SIZES=("4K" "64K" "1M")
# Porcentajes de caracteres alfabéticos
ALPHAS=(0 50 90)
# Alineamientos / desalineamientos
ALIGN=32
MISALIGNS=(0 7)

MODES=("upper" "lower")

echo "=== Iniciando validación serial vs CUDA ==="

for size in "${SIZES[@]}"; do
  for alpha in "${ALPHAS[@]}"; do
    for misalign in "${MISALIGNS[@]}"; do
      echo
      echo ">> Caso: size=$size, alpha=$alpha, misalign=$misalign"

      # 1) Generar input.bin con gen_text
      ./gen_text \
        --size "$size" \
        --alpha "$alpha" \
        --align "$ALIGN" \
        --misalign "$misalign" \
        --out input.bin

      for mode in "${MODES[@]}"; do
        echo "   Modo: $mode"

        # 2) Serial
        ./serial --mode "$mode" --in input.bin --out out_serial.bin > /dev/null

        # 3) CUDA
        ./cuda_conv --mode "$mode" --in input.bin --out out_cuda.bin > /dev/null

        # 4) Comparar resultados
        if cmp -s out_serial.bin out_cuda.bin; then
          echo "      [OK] serial == cuda"
        else
          echo "      [FAIL] Diferencias entre serial y cuda"
          echo "      Detalle: size=$size alpha=$alpha misalign=$misalign mode=$mode"
          exit 1
        fi
      done
    done
  done
done

echo
echo "=== TODAS LAS PRUEBAS PASARON (serial y CUDA coinciden) ==="

