// Minimal probe: is an OpenCL platform/device usable on this CoreX box?
#define CL_TARGET_OPENCL_VERSION 300
#include <CL/cl.h>
#include <cstdio>
#include <vector>
#include <string>

int main() {
    cl_uint nplat = 0;
    cl_int e = clGetPlatformIDs(0, nullptr, &nplat);
    printf("[clGetPlatformIDs] rc=%d nplatforms=%u\n", e, nplat);
    if (e != CL_SUCCESS || nplat == 0) return 1;
    std::vector<cl_platform_id> plats(nplat);
    clGetPlatformIDs(nplat, plats.data(), nullptr);
    for (cl_uint i = 0; i < nplat; ++i) {
        char name[256]={0}, vend[256]={0}, ver[256]={0};
        clGetPlatformInfo(plats[i], CL_PLATFORM_NAME, sizeof(name), name, nullptr);
        clGetPlatformInfo(plats[i], CL_PLATFORM_VENDOR, sizeof(vend), vend, nullptr);
        clGetPlatformInfo(plats[i], CL_PLATFORM_VERSION, sizeof(ver), ver, nullptr);
        printf("  platform[%u] name='%s' vendor='%s' version='%s'\n", i, name, vend, ver);
        cl_uint ndev=0;
        cl_int de = clGetDeviceIDs(plats[i], CL_DEVICE_TYPE_ALL, 0, nullptr, &ndev);
        printf("    [clGetDeviceIDs] rc=%d ndevices=%u\n", de, ndev);
        std::vector<cl_device_id> devs(ndev);
        if (ndev) clGetDeviceIDs(plats[i], CL_DEVICE_TYPE_ALL, ndev, devs.data(), nullptr);
        for (cl_uint d=0; d<ndev; ++d) {
            char dn[256]={0}; cl_device_type dt=0;
            clGetDeviceInfo(devs[d], CL_DEVICE_NAME, sizeof(dn), dn, nullptr);
            clGetDeviceInfo(devs[d], CL_DEVICE_TYPE, sizeof(dt), &dt, nullptr);
            printf("      device[%u] name='%s' type=0x%lx\n", d, dn, (unsigned long)dt);
        }
    }
    return 0;
}
