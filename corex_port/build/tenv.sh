# Source this to get a working TornadoVM PTX runtime env on CoreX.
source /etc/profile.d/corex.sh
export JAVA_HOME=/home/repos/toolchain/jdk21
export PATH="$JAVA_HOME/bin:$PATH"
export CUDA_VISIBLE_DEVICES=0,1
export TORNADO_SDK=/home/repos/TornadoVM/dist/tornadovm-5.2.1-jdk21-dev-ptx-linux-amd64/tornadovm-5.2.1-jdk21-dev-ptx
export TORNADOVM_HOME="$TORNADO_SDK"
export PATH="$TORNADO_SDK/bin:$PATH"
export LD_LIBRARY_PATH="/usr/local/corex/lib64:$LD_LIBRARY_PATH"
