#!/usr/bin/env bash
set -euo pipefail

# Ejecutables esperados:
#   ./gen_text
#   ./serial
#   ./cuda_conv

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

# Tamaños de prueba (ajusta o agrega más si el profe pide 50 tamaños)
SIZES=(\
  "1K" "2K" "4K" "8K" "16K" "32K" "64K" "128K" "256K" \
  "512K" "1M" "2M" "4M" "8M" "16M" "32M" "64M" \
)

# Porcentajes de caracteres alfabéticos
ALPHAS=(0 10 20 30 40 50 60 70 80 90)

ALIGN=32
MISALIGNS=(0 7)
MODES=("upper" "lower")

OUT_CSV="results.csv"

echo "impl,mode,bytes,proc_ms,io_ms,VmRSS_KiB,alpha,align,misalign" > "$OUT_CSV"

for size in "${SIZES[@]}"; do
  for alpha in "${ALPHAS[@]}"; do
    for misalign in "${MISALIGNS[@]}"; do
      echo
      echo ">> size=$size alpha=$alpha misalign=$misalign"

      # 1) Generar input
      ./gen_text \
        --size "$size" \
        --alpha "$alpha" \
        --align "$ALIGN" \
        --misalign "$misalign" \
        --out input.bin

      for mode in "${MODES[@]}"; do
        echo "   Modo: $mode"

        # 2) Serial
        line_serial=$(
          ./serial --mode "$mode" --in input.bin --out out_serial.bin \
          | tail -n 1
        )

        # 3) CUDA
        line_cuda=$(
          ./cuda_conv --mode "$mode" --in input.bin --out out_cuda.bin \
          | tail -n 1
        )

        # 4) Guardar ambas líneas en el CSV con alpha/align/misalign
        #    Esperamos formato: impl,mode,bytes,proc_ms,io_ms,VmRSS_KiB
        echo "${line_serial},${alpha},${ALIGN},${misalign}" >> "$OUT_CSV"
        echo "${line_cuda},${alpha},${ALIGN},${misalign}" >> "$OUT_CSV"
      done
    done
  done
done

echo
echo "Benchmarks terminados. Resultados en: $OUT_CSV"

