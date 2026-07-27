#!/bin/bash
source /home/repos/TornadoVM/corex_port/build/tenv.sh
cd /home/repos/TornadoVM
echo "=== TornadoVM full unittest suite (PTX backend on ivcore11) ==="
echo "=== start $(date -u +%FT%TZ) ==="
tornado --devices 2>&1
echo "=================== FULL SUITE (tornado-test --ea --verbose) ==================="
tornado-test --ea --verbose
echo "=== HeapFail memory-limit case (from Makefile tests target) ==="
tornado-test --ea -V -J"-Dtornado.device.memory=1MB" uk.ac.manchester.tornado.unittests.fails.HeapFail#test03
echo "=== end $(date -u +%FT%TZ) ==="
