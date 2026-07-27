// Minimal probe: does the ivcore11 CoreX driver accept NVIDIA PTX text via
// cuModuleLoadData (exactly what TornadoVM PTXModule.cpp does)?
// Also probes NVRTC. Build with clang++ (NO nvcc), link -lcuda -lnvrtc.
#include <cuda.h>
#include <nvrtc.h>
#include <cstdio>
#include <cstring>
#include <string>

// Trivial empty kernel PTX, parametrized by .version / .target so we can sweep.
static std::string make_ptx(const char* ver, const char* target) {
    char buf[1024];
    snprintf(buf, sizeof(buf),
        ".version %s\n"
        ".target %s\n"
        ".address_size 64\n"
        ".visible .entry empty_kernel()\n"
        "{\n"
        "    ret;\n"
        "}\n", ver, target);
    return std::string(buf);
}

static const char* errstr(CUresult r) {
    const char* s = nullptr;
    cuGetErrorString(r, &s);
    return s ? s : "(unknown)";
}

int main() {
    CUresult r = cuInit(0);
    printf("[cuInit] rc=%d %s\n", r, errstr(r));
    if (r != CUDA_SUCCESS) return 1;

    int ndev = 0;
    cuDeviceGetCount(&ndev);
    printf("[cuDeviceGetCount] %d device(s)\n", ndev);
    if (ndev < 1) return 1;

    CUdevice dev; cuDeviceGet(&dev, 0);
    char name[256]; cuDeviceGetName(name, sizeof(name), dev);
    int major=0, minor=0;
    cuDeviceGetAttribute(&major, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR, dev);
    cuDeviceGetAttribute(&minor, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR, dev);
    printf("[device0] %s  cc=%d.%d\n", name, major, minor);

    CUcontext ctx; r = cuCtxCreate(&ctx, 0, dev);
    printf("[cuCtxCreate] rc=%d %s\n", r, errstr(r));
    if (r != CUDA_SUCCESS) return 1;

    // ---- Sweep PTX ISA versions / targets and hand raw NV PTX to the driver ----
    const char* versions[] = {"6.5", "6.0", "5.0", "7.0", "7.5", "8.0"};
    const char* targets[]  = {"sm_50", "sm_60", "sm_70", "sm_75", "sm_35"};
    int accepted = 0, rejected = 0;
    for (const char* ver : versions) {
        for (const char* tgt : targets) {
            std::string ptx = make_ptx(ver, tgt);
            CUmodule mod;
            CUresult mr = cuModuleLoadData(&mod, ptx.c_str());
            printf("[cuModuleLoadData] .version %s .target %-6s -> rc=%d %s\n",
                   ver, tgt, mr, errstr(mr));
            if (mr == CUDA_SUCCESS) { accepted++; cuModuleUnload(mod); }
            else rejected++;
        }
    }
    printf("[PTX-load summary] accepted=%d rejected=%d\n", accepted, rejected);

    // ---- NVRTC: compile a trivial kernel, then try to load resulting PTX ----
    const char* ksrc = "extern \"C\" __global__ void k(float* a){ int i=threadIdx.x; a[i]=a[i]+1.0f; }\n";
    nvrtcProgram prog;
    nvrtcResult nr = nvrtcCreateProgram(&prog, ksrc, "k.cu", 0, nullptr, nullptr);
    printf("[nvrtcCreateProgram] rc=%d %s\n", nr, nvrtcGetErrorString(nr));
    if (nr == NVRTC_SUCCESS) {
        const char* opts[] = {"--gpu-architecture=compute_70"};
        nr = nvrtcCompileProgram(prog, 1, opts);
        printf("[nvrtcCompileProgram compute_70] rc=%d %s\n", nr, nvrtcGetErrorString(nr));
        if (nr != NVRTC_SUCCESS) {
            // retry with no arch flag (CoreX-native behavior per compat index)
            nvrtcDestroyProgram(&prog);
            nvrtcCreateProgram(&prog, ksrc, "k.cu", 0, nullptr, nullptr);
            nr = nvrtcCompileProgram(prog, 0, nullptr);
            printf("[nvrtcCompileProgram no-arch] rc=%d %s\n", nr, nvrtcGetErrorString(nr));
        }
        size_t logsz=0; nvrtcGetProgramLogSize(prog, &logsz);
        if (logsz > 1) { std::string log(logsz,0); nvrtcGetProgramLog(prog,&log[0]); printf("[nvrtc log] %s\n", log.c_str()); }
        if (nr == NVRTC_SUCCESS) {
            size_t ptxsz=0; nvrtcGetPTXSize(prog,&ptxsz);
            std::string ptx(ptxsz,0); nvrtcGetPTX(prog,&ptx[0]);
            printf("[nvrtc PTX head]\n%.200s\n", ptx.c_str());
            CUmodule mod; CUresult mr = cuModuleLoadData(&mod, ptx.c_str());
            printf("[cuModuleLoadData(nvrtc-PTX)] rc=%d %s\n", mr, errstr(mr));
            if (mr==CUDA_SUCCESS){ CUfunction f; CUresult fr=cuModuleGetFunction(&f,mod,"k"); printf("[cuModuleGetFunction] rc=%d %s\n", fr, errstr(fr)); cuModuleUnload(mod);}
        }
        nvrtcDestroyProgram(&prog);
    }

    cuCtxDestroy(ctx);
    return 0;
}
