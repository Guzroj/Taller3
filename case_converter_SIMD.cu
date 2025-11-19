// case_converter_SIMD.cu
// Versión CUDA del case_converter: convierte mayúsculas/minúsculas en GPU
// Uso:
//   ./cuda_conv --mode upper --in input.bin --out output.bin
//   ./cuda_conv --mode lower --in input.bin --out output.bin

#include <cuda_runtime.h>

#include <chrono>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>   // ← agrega esto


// -----------------------------------------------------------------------------
// Manejo simple de errores CUDA
// -----------------------------------------------------------------------------
#define CUDA_CHECK(expr)                                                     \
    do {                                                                     \
        cudaError_t _err = (expr);                                           \
        if (_err != cudaSuccess) {                                           \
            std::cerr << "CUDA error: " << cudaGetErrorString(_err)          \
                      << " at " << __FILE__ << ":" << __LINE__ << "\n";      \
            std::exit(1);                                                    \
        }                                                                    \
    } while (0)

// -----------------------------------------------------------------------------
// Modo de conversión
// -----------------------------------------------------------------------------
enum Mode {
    TO_UPPER = 0,
    TO_LOWER = 1
};

// -----------------------------------------------------------------------------
// Lectura completa de archivo a memoria
// -----------------------------------------------------------------------------
std::string read_all(const std::string &path) {
    std::ifstream in(path, std::ios::binary);
    if (!in) {
        std::cerr << "Error abriendo archivo de entrada: " << path << "\n";
        std::exit(1);
    }
    std::ostringstream ss;
    ss << in.rdbuf();
    return ss.str();
}

// -----------------------------------------------------------------------------
// Escritura completa de buffer a archivo
// -----------------------------------------------------------------------------
void write_all(const std::string &path, const uint8_t *data, size_t n) {
    std::ofstream out(path, std::ios::binary | std::ios::trunc);
    if (!out) {
        std::cerr << "Error abriendo archivo de salida: " << path << "\n";
        std::exit(1);
    }
    out.write(reinterpret_cast<const char *>(data), static_cast<std::streamsize>(n));
    if (!out) {
        std::cerr << "Error escribiendo archivo de salida: " << path << "\n";
        std::exit(1);
    }
}

// -----------------------------------------------------------------------------
// (Opcional) Lectura de memoria RSS en KiB en Linux (/proc/self/status)
// Si no lo ocupás, lo podés comentar.
// -----------------------------------------------------------------------------
long rss_kib() {
    std::ifstream f("/proc/self/status");
    if (!f) return -1;

    std::string line;
    while (std::getline(f, line)) {
        if (line.rfind("VmRSS:", 0) == 0) {
            std::istringstream iss(line);
            std::string key, value, unit;
            iss >> key >> value >> unit; // VmRSS:  12345 kB
            try {
                return std::stol(value);
            } catch (...) {
                return -1;
            }
        }
    }
    return -1;
}

// -----------------------------------------------------------------------------
// Kernel CUDA: cada hilo procesa un carácter
// -----------------------------------------------------------------------------
__global__
void case_convert_kernel(unsigned char *data, size_t n, int mode_int) {
    size_t idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n) return;

    unsigned char c = data[idx];

    if (mode_int == TO_UPPER) {
        // 'a'..'z' -> restar 0x20
        if (c >= 'a' && c <= 'z') {
            c = static_cast<unsigned char>(c - 0x20);
        }
    } else {
        // 'A'..'Z' -> sumar 0x20
        if (c >= 'A' && c <= 'Z') {
            c = static_cast<unsigned char>(c + 0x20);
        }
    }

    data[idx] = c;
}

// -----------------------------------------------------------------------------
// Parseo simple de argumentos estilo --flag valor
// -----------------------------------------------------------------------------
int main(int argc, char **argv) {
    std::string mode_str;
    std::string in_path;
    std::string out_path;

    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if ((arg == "--mode" || arg == "-m") && i + 1 < argc) {
            mode_str = argv[++i];
        } else if ((arg == "--in" || arg == "-i") && i + 1 < argc) {
            in_path = argv[++i];
        } else if ((arg == "--out" || arg == "-o") && i + 1 < argc) {
            out_path = argv[++i];
        } else if (arg == "--help" || arg == "-h") {
            std::cout << "Uso:\n"
                      << "  " << argv[0]
                      << " --mode upper|lower --in input.bin --out output.bin\n";
            return 0;
        } else {
            std::cerr << "Argumento desconocido: " << arg << "\n";
            return 1;
        }
    }

    if (mode_str.empty() || in_path.empty() || out_path.empty()) {
        std::cerr << "Faltan argumentos.\n"
                  << "Uso:\n  " << argv[0]
                  << " --mode upper|lower --in input.bin --out output.bin\n";
        return 1;
    }

    Mode mode;
    if (mode_str == "upper") {
        mode = TO_UPPER;
    } else if (mode_str == "lower") {
        mode = TO_LOWER;
    } else {
        std::cerr << "Modo inválido: " << mode_str
                  << " (use 'upper' o 'lower')\n";
        return 1;
    }

    // -------------------------------------------------------------------------
    // 1) Leer archivo de entrada (E/S)
    // -------------------------------------------------------------------------
    auto t_read0 = std::chrono::steady_clock::now();
    std::string input = read_all(in_path);
    auto t_read1 = std::chrono::steady_clock::now();

    size_t n = input.size();
    if (n == 0) {
        // Nada que hacer, pero igual escribimos archivo vacío y salimos
        write_all(out_path, nullptr, 0);
        std::cout << "cuda," << mode_str << "," << n
                  << ",0.0,0.0," << rss_kib() << "\n";
        return 0;
    }

    // Convertimos el buffer a uint8_t* para usarlo en CUDA
    std::vector<uint8_t> h_data(input.begin(), input.end());

    // -------------------------------------------------------------------------
    // 2) Procesamiento en GPU: copiar H->D, lanzar kernel, copiar D->H
    // -------------------------------------------------------------------------
    auto t_proc0 = std::chrono::steady_clock::now();

    unsigned char *d_data = nullptr;
    CUDA_CHECK(cudaMalloc(&d_data, n));

    CUDA_CHECK(cudaMemcpy(d_data, h_data.data(), n, cudaMemcpyHostToDevice));

    int blockSize = 256;
    int gridSize = static_cast<int>((n + blockSize - 1) / blockSize);

    case_convert_kernel<<<gridSize, blockSize>>>(d_data, n, static_cast<int>(mode));
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());

    CUDA_CHECK(cudaMemcpy(h_data.data(), d_data, n, cudaMemcpyDeviceToHost));
    CUDA_CHECK(cudaFree(d_data));

    auto t_proc1 = std::chrono::steady_clock::now();

    // -------------------------------------------------------------------------
    // 3) Escritura de archivo de salida (E/S)
    // -------------------------------------------------------------------------
    auto t_write0 = std::chrono::steady_clock::now();
    write_all(out_path, h_data.data(), n);
    auto t_write1 = std::chrono::steady_clock::now();

    // -------------------------------------------------------------------------
    // 4) Métricas de tiempo y memoria
    // -------------------------------------------------------------------------
    using ms = std::chrono::duration<double, std::milli>;

    double read_ms  = ms(t_read1 - t_read0).count();
    double proc_ms  = ms(t_proc1 - t_proc0).count();
    double write_ms = ms(t_write1 - t_write0).count();

    double io_ms = read_ms + write_ms;
    long mem_kib = rss_kib();

    // Formato de salida tipo CSV (como en el taller anterior):
    // impl,mode,bytes,proc_ms,io_ms,VmRSS_KiB
    std::cout << "cuda," << mode_str << "," << n << ","
              << proc_ms << "," << io_ms << "," << mem_kib << "\n";

    return 0;
}
