# Taller 3 – Conversión de Mayúsculas/Minúsculas con CUDA  
Curso: CE4302 – Arquitectura de Computadores II

Este proyecto implementa:

- Un **generador de texto** (`gen_text`) totalmente configurable.  
- Una **versión serial** (`serial`) que ejecuta en CPU.  
- Una **versión CUDA** (`cuda_conv`) que ejecuta en GPU.  
- Scripts para **validación**, **benchmarks masivos** y **generación de gráficas**.

El objetivo es comparar rendimiento, validar correctitud y analizar el impacto de tamaños, alineamientos y porcentajes de caracteres alfabéticos.

# 1. Requisitos

### Software necesario
- Linux
- `g++` con soporte C++17
- CUDA Toolkit instalado (incluye `nvcc`)
- Python 3 con:
  - `pandas`
  - `matplotlib`

### 2.Instalación rápida para lo necesario de python en Linux
sudo apt update
sudo apt install python3-pandas python3-matplotlib

### 3.Para compilar hay que ejecutar el Makefile
make

### Para borrar los binarios 
make clean

### 4.Si se quiere correr los archivos individuales 
./gen_text --size 8M --alpha 50 --align 32 --misalign 7 --out input.bin

*Version serial:
./serial --mode upper --in input.bin --out out_serial.bin
./serial --mode lower --in input.bin --out out_serial.bin

*Solo cuda:
./cuda_conv --mode upper --in input.bin --out out_cuda.bin
./cuda_conv --mode lower --in input.bin --out out_cuda.bin

### 5.Para hacer la validacion de que dan lo mismo hacer 
make validate


### 6.Correr la prueba de los resultados (Benchmark)
make bench

### 7.Generar Graficas
python3 plot_results_cuda.py results.csv --alpha 50 --misalign 0
o 
python3 plot_results_cuda.py results.csv --alpha 30 --misalign 7


### Flujo cumpliendo todo lo del taller 
make                
make validate      
make bench        
python3 plot_results_cuda.py results.csv --alpha 50 --misalign 0


