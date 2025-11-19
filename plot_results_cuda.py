#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import argparse, pandas as pd, matplotlib.pyplot as plt
from pathlib import Path

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("csv", help="results.csv de bench.sh")
    ap.add_argument("--alpha", type=int, default=None, help="filtrar % alfabético (0..100)")
    ap.add_argument("--misalign", type=int, default=None, help="filtrar misalign (p.ej. 0 o 7)")
    ap.add_argument("--outdir", default="plots", help="carpeta salida")
    args = ap.parse_args()

    outdir = Path(args.outdir)
    outdir.mkdir(exist_ok=True, parents=True)

    df = pd.read_csv(args.csv)

    # Asegurar tipos numéricos
    for c in ["bytes", "proc_ms", "io_ms", "VmRSS_KiB", "alpha", "misalign"]:
        if c in df.columns:
            df[c] = pd.to_numeric(df[c], errors="coerce")

    # Filtros por alpha / misalign
    if args.alpha is not None:
        df = df[df["alpha"] == args.alpha]
    if args.misalign is not None:
        df = df[df["misalign"] == args.misalign]

    # Dejemos solo mode=upper (si existe)
    if "mode" in df.columns and "upper" in df["mode"].unique():
        df = df[df["mode"] == "upper"]

    if df.empty:
        print("No hay datos después de aplicar filtros.")
        return

    # Agregados por (impl, bytes): mediana para robustez
    agg = (
        df.groupby(["impl", "bytes"], as_index=False)
          .agg(proc_ms=("proc_ms", "median"),
               io_ms=("io_ms", "median"))
    )

    # Pivot a formato ancho
    w_proc = agg.pivot(index="bytes", columns="impl", values="proc_ms").sort_index()
    w_io   = agg.pivot(index="bytes", columns="impl", values="io_ms").sort_index()
    total  = w_proc.add(w_io, fill_value=0.0)

    # etiqueta para títulos
    tag = []
    if args.alpha is not None:
        tag.append(f"alpha={args.alpha}%")
    if args.misalign is not None:
        tag.append(f"misalign=+{args.misalign}")
    tag = " — " + ", ".join(tag) if tag else ""

    # (i) proc_ms vs bytes (serial vs CUDA)
    plt.figure()
    if "serial" in w_proc:
        plt.plot(w_proc.index, w_proc["serial"], marker="o", label="serial (proc_ms)")
    if "cuda" in w_proc:
        plt.plot(w_proc.index, w_proc["cuda"], marker="o", label="cuda (proc_ms)")
    plt.xscale("log")
    plt.xlabel("Tamaño (bytes, log)")
    plt.ylabel("Tiempo de cómputo (ms)")
    plt.title("Cómputo: serial vs CUDA" + tag)
    plt.grid(True, which="both", linestyle=":")
    plt.legend()
    plt.savefig(outdir / "proc_vs_bytes.png", dpi=160, bbox_inches="tight")

    # (ii) total = proc+io
    plt.figure()
    if "serial" in total:
        plt.plot(total.index, total["serial"], marker="o", label="serial (proc+io)")
    if "cuda" in total:
        plt.plot(total.index, total["cuda"], marker="o", label="cuda (proc+io)")
    plt.xscale("log")
    plt.xlabel("Tamaño (bytes, log)")
    plt.ylabel("Tiempo total (ms)")
    plt.title("Total (proc + io): serial vs CUDA" + tag)
    plt.grid(True, which="both", linestyle=":")
    plt.legend()
    plt.savefig(outdir / "total_vs_bytes.png", dpi=160, bbox_inches="tight")

    # (iii) speedup de cómputo (serial / CUDA)
    if {"serial", "cuda"}.issubset(w_proc.columns):
        speed = w_proc["serial"] / w_proc["cuda"]
        plt.figure()
        plt.plot(speed.index, speed.values, marker="o")
        plt.xscale("log")
        plt.xlabel("Tamaño (bytes, log)")
        plt.ylabel("Speedup × (serial/cuda)")
        plt.title("Speedup de cómputo" + tag)
        plt.grid(True, which="both", linestyle=":")
        plt.axhline(1.0, ls="--")
        plt.savefig(outdir / "speedup_proc.png", dpi=160, bbox_inches="tight")

    # guardar agregados (útil para tablas en el reporte)
    agg.sort_values(["impl", "bytes"]).to_csv(outdir / "agg_median_by_size.csv", index=False)
    print("Listo. PNGs en", outdir)

if __name__ == "__main__":
    main()
