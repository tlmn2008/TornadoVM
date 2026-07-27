# TornadoVM → Iluvatar CoreX (ivcore11) 迁移会话记录

## 1. 来源 (Source)
- 上游仓库: https://github.com/beehive-lab/TornadoVM.git
- 默认分支: `master`
- 起点 commit: `06616ddd4a543b07f785982bfcf4ffea7f6bc9c6`
- commit 日期: 2026-07-24T18:50:50+03:00
- 克隆位置: `/home/repos/TornadoVM`

## 2. CUDA 使用性质 (Nature of CUDA usage)
TornadoVM 是一个 JDK 21+ 的异构 GPU 框架，把 Java 字节码经 Graal JIT 编译成设备代码。其
`tornado-drivers/ptx`（CUDA 后端）的执行链路为：

```
Java bytecode → Graal IR → NVIDIA PTX 文本 → (JNI) cuModuleLoadData/cuModuleLoadDataEx → 驱动 JIT 成 cubin → cuLaunchKernel
```

关键点：TornadoVM **在 JVM 内直接生成 NVIDIA PTX 汇编文本**，然后交给 CUDA Driver API
（`cuModuleLoadData`）在运行期做 PTX→cubin 的 JIT。它并不产出 clang/ivcore11 的本地镜像。
本仓库还包含 OpenCL / SPIR-V / Metal 等其它后端；本次迁移目标是 CUDA/PTX 后端在 ivcore11 上跑通。

## 3. 环境 (Environment)
- 目标平台: Iluvatar CoreX ivcore11 (BI-V150)，通过 `ixsmi` 确认 2 张 GPU 可见。
- SDK: `/usr/local/corex`（零改动，未触碰）。
- 编译器: `clang` / `clang++`（CoreX 自带），**未使用 nvcc**。
- JDK: 用户态安装 Amazon Corretto 21（上游要求 JDK 21+）。
- 构建: Maven（经 `bin/compile` 包装），选择 PTX/CUDA 后端 `BACKEND=ptx`。
- GPU 用量: 测试统一 `CUDA_VISIBLE_DEVICES=0`，满足 ≤2 GPU 的红线。

## 4. 适配内容 (Adaptations)
1. **链接库路径**: `tornado-drivers/ptx-jni/src/main/cpp/CMakeLists.txt` 原先链接
   `/usr/local/cuda/lib64/stubs -lcuda -lnvidia-ml`。ivcore11 没有 `libnvidia-ml`，改为在
   `COREX_PATH` 存在时链接 `$COREX_PATH/lib64 -lcuda`（去掉 `-lnvidia-ml`），保留原分支作回退。
2. **clang++ 兼容**: 同一 CMake 里 `-export-dynamic` 为 GNU ld 用法，clang++ 不识别，改为
   `-rdynamic`。
3. **单线程构建**: Maven 并行构建（`-T1.5C`）在本沙箱触发 `Could not acquire lock(s)`，改用
   `--mvn_single_threaded` 单线程构建通过。
4. **PTX/NVRTC 兼容性探针**: 在改任何业务代码前，先用裸 CUDA Driver API 探针
   (`corex_port/build/ptx_probe.cpp`) 直接验证 ivcore11 是否消费 NV PTX 文本。
5. **精度 (FP64)**: ivcore11 无真正的 double/FP64。因 CUDA/PTX 后端在 kernel 加载阶段即被
   驱动整体拒绝（见下），未进入到需要按用例降精度的运行阶段；FP64 相关用例与其它用例一样
   全部阻塞在 `cuModuleLoadData`，已在测试台账中如实计入。

## 5. 结果 (Result)
- **编译 (compile_status = success)**: JDK 21 + Maven（clang/clang++、CoreX libcuda）成功构建出
  TornadoVM 与 PTX-JNI 本地库。编译面记录在 `corex_port/build/`。
- **运行时测试 (test_status = failed)**: 以 PTX 后端在 ivcore11 上跑 `tornado-unittests`
  全量套件（每类独立 JVM + 每类超时）。**所有真正下发 kernel 的用例在 `cuModuleLoadData`
  返回 `CUDA_ERROR_INVALID_IMAGE (200)`（"PTX JIT compilation failed!"）而失败**；一部分用例被
  框架标为 `UNSUPPORTED`（PTX CONFIGURATION UNSUPPORTED，多为 cuBLAS/cuSPARSE/FP8 等）计入 skipped；
  逐用例明细见 `corex_port/test/test.log` 与 `results.csv`，汇总见 `test/test_summary.json`。
- **次生现象**: 反复的 INVALID_IMAGE 失败使 CoreX 驱动进入残留状态，后续部分测试类在双设备
  初始化时挂起（40s 超时按 hung/blocked 计入，不计为已执行用例）。

## 6. Failure Gate（逐一复现 + 分类 + 已尝试的绕过）
- **PTX 文本被驱动拒绝 —— terminal**：用独立最小探针跨 6 个 PTX ISA 版本 × 5 个 sm target 共 30
  组逐一 `cuModuleLoadData`，**全部 rc=200**；作为反证，nvrtc 不带 arch 编译产出的本地 ELF 镜像
  `cuModuleLoadData` rc=0 成功——证明 ivcore11 只消费 clang/IXRTC 产出的本地镜像，不消费 NV PTX
  文本。与 `iluvatar-cuda-base` 索引 "cuModuleLoad(NV PTX) 拒绝" 条目及 ILGPU 先例一致。要在
  ivcore11 上跑通 CUDA 后端需为 TornadoVM 重写 codegen（新增产出 ivcore11 本地镜像的后端），
  在不改 `/usr/local/corex`、不引入新后端的前提下无法本地解决 → **判定 terminal**。
- **OpenCL 备选后端不可用 —— terminal**：作为 PTX 终局阻塞的备选尝试 OpenCL。系统仅有通用
  ocl-icd loader，`/etc/OpenCL/vendors` 不存在，`clGetPlatformIDs` 返回 -1001（0 平台）；全盘搜索无任何
  Iluvatar OpenCL ICD 供应商文件与实现库。平台缺失、不在仓库可修范围 → **判定 terminal**，
  OpenCL 基线无法运行。
- **驱动残留导致 init 挂起 —— workaround-able**：杀残留 JVM + 冷却 3-5 分钟可恢复。已用
  "每类独立 JVM + 每类 40s 超时 + 结束回收残留 JVM + 单 GPU" 的跑法隔离并如实计数，挂起类计为
  hung/blocked。此为次生现象，根因仍是上面的 PTX 终局阻塞。

**结论**：TornadoVM 的 CUDA/PTX 路径在 ivcore11 上为 **terminal**（NV PTX 文本被驱动整体拒绝），
OpenCL 备选后端因无 ICD 亦不可用。编译面（clang/clang++/CoreX libcuda）已打通，构建成功；
运行时全量套件已诚实执行并如实记录 kernel 加载失败与驱动残留挂起。
