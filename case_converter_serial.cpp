// case_converter_serial.cpp
// g++ -std=c++17 -O2 -Wall -Wextra case_converter_serial.cpp -o serial
#include <bits/stdc++.h>
using namespace std;
enum Mode{TO_UPPER, TO_LOWER};

static string read_all(const string& path){
    ifstream f(path, ios::binary); if(!f) throw runtime_error("no abre input");
    string s((istreambuf_iterator<char>(f)), istreambuf_iterator<char>());
    return s;
}
static void write_all(const string& path, const string& s){
    ofstream f(path, ios::binary); if(!f) throw runtime_error("no abre output");
    f.write(s.data(), (streamsize)s.size());
}
static long rss_kib() {
    std::ifstream f("/proc/self/status");
    std::string line;
    while (std::getline(f, line)) {
        if (line.rfind("VmRSS:", 0) == 0) { // empieza con "VmRSS:"
            std::istringstream iss(line.substr(6));
            long kib = -1;
            iss >> kib; // primer número después de la etiqueta
            return kib; // KiB
        }
    }
    return -1;
}

int main(int argc, char** argv){
    ios::sync_with_stdio(false);
    string in="input.bin", out="out_serial.bin", modeStr="upper";
    bool report_csv=true;
    for(int i=1;i<argc;i++){
        string a=argv[i]; auto need=[&](int n){ if(i+n>=argc){cerr<<"falta valor para "<<a<<"\n"; exit(1);} };
        if(a=="--in"){ need(1); in=argv[++i]; }
        else if(a=="--out"){ need(1); out=argv[++i]; }
        else if(a=="--mode"){ need(1); modeStr=argv[++i]; }
        else if(a=="--report"){ need(1); report_csv = string(argv[++i])=="csv"; }
        else if(a=="-h"||a=="--help"){
            cerr<<"Uso: ./serial --in input.bin --out out.bin --mode upper|lower --report csv\n"; return 0;
        }
    }
    Mode mode = (modeStr=="lower")? TO_LOWER : TO_UPPER;

    string s = read_all(in);
    auto t0 = chrono::steady_clock::now();

    // conversión in-place ASCII segura
    for(size_t i=0;i<s.size();++i){
        unsigned char c = (unsigned char)s[i];
        if(mode==TO_UPPER){
            if(c>='a' && c<='z') s[i] = char(c - 0x20);
        }else{
            if(c>='A' && c<='Z') s[i] = char(c + 0x20);
        }
    }

    auto t1 = chrono::steady_clock::now();
    write_all(out, s);
    auto t2 = chrono::steady_clock::now();

    double t_proc_ms = chrono::duration<double, milli>(t1-t0).count();
    double t_io_ms   = chrono::duration<double, milli>(t2-t1).count();
    long   mem_kib   = rss_kib();

    if(report_csv){
        // formato: impl,mode,bytes,proc_ms,io_ms,VmRSS_KiB
        cout<<"serial,"<<modeStr<<","<<s.size()<<","
            <<fixed<<setprecision(3)<<t_proc_ms<<","<<t_io_ms<<","<<mem_kib<<"\n";
    }else{
        cout<<"[serial] mode="<<modeStr<<" bytes="<<s.size()
            <<" proc_ms="<<t_proc_ms<<" io_ms="<<t_io_ms
            <<" VmRSS_KiB="<<mem_kib<<"\n";
    }
    return 0;
}
