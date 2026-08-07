# nv-ptx-text-rejected (最小复现件)

## 说明（复用自 ILGPU 规范件）
本目录的源文件与脚本**复用自 ILGPU 仓库的规范复现件**
`/home/repos/ILGPU/corex_port/defects/reproduce/nv-ptx-rejected/`，
`defect_key` 保持一致：`driver:nv-ptx-text-rejected`。跨仓去重在 `aggregate.py`
聚合层完成，本仓保留一份自包含拷贝以保证 `corex-port` 分支独立可复现。

零依赖裸驱动最小件：用 `dlopen("libcuda.so.1")` 拿到 driver API，手写一个
合法的 NVIDIA 风格空 kernel PTX（`.version 6.5` / `.target sm_70`），经
`cuModuleLoadDataEx` 做 JIT 加载。任何合法 NV 驱动都应返回 rc=0；ivcore11
驱动一律返回 rc=200（`CUDA_ERROR_INVALID_IMAGE`），JIT error log 为空。

## 本仓触发场景（TornadoVM）
TornadoVM 的 CUDA/PTX 后端由 Graal 在 JVM 内把 Java 字节码即时编译成
NVIDIA PTX 文本，再经 JNI 调 `cuModuleLoadData/cuModuleLoadDataEx` 交给驱动
JIT。在 ivcore11(BI-V150) 上，每个下发 device kernel 的用例都首错于
`cuModuleLoadDataEx -> Returned: 200` / `PTX JIT compilation failed!`，
根因与本最小件一致——驱动不接受 NV PTX 文本。见
`corex_port/build/ptx_probe_run.log`（30 组 version×target 全 rc=200）与
`corex_port/test/test.log`。

## 构建 / 运行
```
bash build.sh   # cc reproduce.c -o reproduce -ldl
bash run.sh      # 若上一进程残留导致 cuCtxCreate 挂起，先执行 'ixsmi -r' 复位再跑
```

## 期望 vs 实际
- 期望：`cuModuleLoadDataEx rc=0`，合法 NV PTX 空 kernel 应能 JIT 加载。
- 实际：`cuModuleLoadDataEx rc=200`（`CUDA_ERROR_INVALID_IMAGE`），复现驱动拒收 NV PTX 文本。
