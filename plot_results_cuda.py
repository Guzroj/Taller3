#!/usr/bin/env python3
import argparse
import pandas as pd
import matplotlib.pyplot as plt

def main():
    parser = argparse.ArgumentParser(description="Gráficas serial vs CUDA")
    parser.add_argument("--csv", default="results.csv", help="Archivo CSV de entrada")
    parser.add_argument("--alpha", type=int, default=50, help="Porcentaje de caracteres alfabéticos")
    parser.add_argument("--misalign", type=int, default=0, help="Desalineamiento usado (0 o 7)")
    parser.add_argument("--mode", choices=["upper", "lower", "both"], default="upper",
                        help="Modo a graficar (upper, lower o both)")
    parser.add_argument("--logx", action="store_true", help="Usar escala log10 en el eje X (bytes)")
    parser.add_argument("--show", action="store_true", help="Mostrar ventanas en lugar de solo guardar PNG")
    args = parser.parse_args()

    # Leer CSV
    df = pd.read_csv(args.csv)

    # Filtrar por alpha y misalign
    f = (df["alpha"] == args.alpha) & (df["misalign"] == args.misalign)
    df = df[f].copy()

    if df.empty:
        print("No hay datos que coincidan con alpha={} y misalign={} en {}"
              .format(args.alpha, args.misalign, args.csv))
        return

    # Opcional: filtrar por modo
    modes = ["upper", "lower"] if args.mode == "both" else [args.mode]
    df = df[df["mode"].isin(modes)]

    # Para orden lógico en el eje X
    df = df.sort_values("bytes")

    # Separamos serial y cuda
    df_serial = df[df["impl"] == "serial"].copy()
    df_cuda   = df[df["impl"] == "cuda"].copy()

    # Asegurarnos de empatar por (mode, bytes)
    key_cols = ["mode", "bytes"]
    df_merged = pd.merge(
        df_serial[key_cols + ["proc_ms"]].rename(columns={"proc_ms": "proc_serial"}),
        df_cuda[key_cols + ["proc_ms"]].rename(columns={"proc_ms": "proc_cuda"}),
        on=key_cols,
        how="inner"
    )

    # Speedup
    df_merged["speedup"] = df_merged["proc_serial"] / df_merged["proc_cuda"]

    # --------- Gráfica 1: tiempo de procesamiento vs tamaño ---------
    for mode in modes:
        df_s = df_serial[df_serial["mode"] == mode]
        df_c = df_cuda[df_cuda["mode"] == mode]

        plt.figure()
        plt.plot(df_s["bytes"], df_s["proc_ms"], marker="o", label="serial")
        plt.plot(df_c["bytes"], df_c["proc_ms"], marker="s", label="cuda")
        if args.logx:
            plt.xscale("log")
        plt.xlabel("Tamaño (bytes)")
        plt.ylabel("Tiempo de cómputo (ms)")
        plt.title(f"Tiempo de procesamiento vs tamaño (mode={mode}, alpha={args.alpha}, misalign={args.misalign})")
        plt.legend()
        plt.grid(True, which="both", linestyle="--", linewidth=0.5)
        out_name = f"tiempo_{mode}_alpha{args.alpha}_mis{args.misalign}.png"
        plt.tight_layout()
        plt.savefig(out_name, dpi=150)
        print("Guardado:", out_name)
        if args.show:
            plt.show()
        else:
            plt.close()

    # --------- Gráfica 2: speedup vs tamaño ---------
    for mode in modes:
        df_m = df_merged[df_merged["mode"] == mode]

        plt.figure()
        plt.plot(df_m["bytes"], df_m["speedup"], marker="o")
        if args.logx:
            plt.xscale("log")
        plt.xlabel("Tamaño (bytes)")
        plt.ylabel("Speedup (serial / cuda)")
        plt.title(f"Speedup vs tamaño (mode={mode}, alpha={args.alpha}, misalign={args.misalign})")
        plt.grid(True, which="both", linestyle="--", linewidth=0.5)
        out_name = f"speedup_{mode}_alpha{args.alpha}_mis{args.misalign}.png"
        plt.tight_layout()
        plt.savefig(out_name, dpi=150)
        print("Guardado:", out_name)
        if args.show:
            plt.show()
        else:
            plt.close()

if __name__ == "__main__":
    main()
