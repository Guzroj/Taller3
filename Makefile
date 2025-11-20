CXX      := g++
NVCC     := nvcc
CXXFLAGS := -std=c++17 -O3 -Wall -Wextra
NVCCFLAGS:= -std=c++17 -O3

# Ejecutables
GEN      := gen_text
SERIAL   := serial
CUDA     := cuda_conv
VALIDATE := validate.sh
BENCH    := bench.sh

# Fuentes
GEN_SRC      := gen_text.cpp
SERIAL_SRC   := case_converter_serial.cpp
CUDA_SRC     := case_converter_SIMD.cu

all: $(GEN) $(SERIAL) $(CUDA)

$(GEN): $(GEN_SRC)
	$(CXX) $(CXXFLAGS) $< -o $@

$(SERIAL): $(SERIAL_SRC)
	$(CXX) $(CXXFLAGS) $< -o $@

$(CUDA): $(CUDA_SRC)
	$(NVCC) $(NVCCFLAGS) $< -o $@


clean:
	rm -f $(GEN) $(SERIAL) $(CUDA) *.o *.bin out_*.bin results.csv


validate: all
	chmod +x $(VALIDATE)
	./$(VALIDATE)

bench: all
	chmod +x $(BENCH)
	./$(BENCH)

.PHONY: all clean validate bench
