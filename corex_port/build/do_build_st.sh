#!/bin/bash
set -o pipefail
source /etc/profile.d/corex.sh
export JAVA_HOME=/home/repos/toolchain/jdk21
export PATH="$JAVA_HOME/bin:$PATH"
export CC=/usr/local/corex/bin/clang
export CXX=/usr/local/corex/bin/clang++
export CUDA_PATH=/usr/local/corex
export CUDAToolkit_ROOT=/usr/local/corex
export CUDA_VISIBLE_DEVICES=0,1
cd /home/repos/TornadoVM
echo "=== START single-threaded build $(date -u +%FT%TZ) ==="
python3 bin/compile --jdk jdk21 --backend ptx --mvn_single_threaded
echo "=== END build rc=$? $(date -u +%FT%TZ) ==="
