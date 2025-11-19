// gen_text.cpp
// g++ -std=c++17 -O2 -Wall -Wextra gen_text.cpp -o gen_text
#include <bits/stdc++.h>
using namespace std;

static uint64_t parse_bytes(const string& s){
    // admite sufijos K,M,G
    char suf = s.empty()? '\0' : tolower(s.back());
    double v = atof(s.c_str());
    if(suf=='k') v*=1024.0;
    else if(suf=='m') v*=1024.0*1024.0;
    else if(suf=='g') v*=1024.0*1024.0*1024.0;
    return (uint64_t)llround(v);
}

int main(int argc, char** argv){
    ios::sync_with_stdio(false);
    string out = "input.bin";
    uint64_t size = 1<<20;     // 1 MiB por defecto
    int alpha = 50;            // 0..100 %
    size_t align = 32;         // bytes
    size_t misalign = 0;       // 0..align-1
    uint64_t seed = 12345;

    for(int i=1;i<argc;i++){
        string a=argv[i];
        auto need = [&](int n){ if(i+n>=argc){ cerr<<"Falta valor para "<<a<<"\n"; exit(1);} };
        if(a=="--size"){ need(1); size = parse_bytes(argv[++i]); }
        else if(a=="--alpha"){ need(1); alpha = stoi(argv[++i]); alpha = max(0,min(100,alpha)); }
        else if(a=="--align"){ need(1); align = stoull(argv[++i]); align = max<size_t>(1,align); }
        else if(a=="--misalign"){ need(1); misalign = stoull(argv[++i]); misalign%=align; }
        else if(a=="--seed"){ need(1); seed = stoull(argv[++i]); }
        else if(a=="--out"){ need(1); out = argv[++i]; }
        else if(a=="-h"||a=="--help"){
            cerr<<"Uso: ./gen_text --size 64M --alpha 30 --align 32 --misalign 7 --seed 1 --out input.bin\n";
            return 0;
        }
    }

    // Reserva alineada y aplica desplazamiento (para simular no alineado)
    void* base=nullptr;
    if(posix_memalign(&base, align, size + align)){ cerr<<"posix_memalign fallo\n"; return 1; }
    uint8_t* buf = (uint8_t*)base + misalign;

    mt19937_64 rng(seed);
    uniform_int_distribution<int> p100(0,99);
    uniform_int_distribution<int> letter(0,51);
    uniform_int_distribution<int> other(0,31); // símbolos/números básicos ASCII

    for(uint64_t i=0;i<size;i++){
        bool is_alpha = p100(rng) < alpha;
        if(is_alpha){
            int r = letter(rng);
            buf[i] = (r<26) ? char('A'+r) : char('a'+(r-26));
        }else{
            // mezcla de espacios, dígitos y signos (siempre ASCII → UTF-8 válido)
            int r = other(rng);
            if(r<10) buf[i] = char('0'+r);
            else if(r<20) buf[i] = char(' '+(r-10)); // 32..41 aprox
            else buf[i] = char(".,;:-_!?()[ ]"[r-20]);
        }
    }

    ofstream f(out, ios::binary);
    f.write((char*)buf, size);
    f.close();
    free(base);
    return 0;
}
