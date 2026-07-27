#!/bin/bash
# CoreX PTX-backend build driver for TornadoVM.
set -o pipefail
source /etc/profile.d/corex.sh
source /root/.config/corex-migration/secrets.env 2>/dev/null
export JAVA_HOME=/home/repos/toolchain/jdk21
export PATH="$JAVA_HOME/bin:$PATH"
# Host JNI compiled with CoreX clang/clang++ (no nvcc; red-line compliant).
export CC=/usr/local/corex/bin/clang
export CXX=/usr/local/corex/bin/clang++
export CUDA_PATH=/usr/local/corex
export CUDAToolkit_ROOT=/usr/local/corex
export CUDA_VISIBLE_DEVICES=0,1
cd /home/repos/TornadoVM
echo "=== java ==="; java -version 2>&1
echo "=== JAVA_HOME=$JAVA_HOME CC=$CC ==="
echo "=== START build ptx backend $(date -u +%FT%TZ) ==="
python3 bin/compile --jdk jdk21 --backend ptx
echo "=== END build rc=$? $(date -u +%FT%TZ) ==="
