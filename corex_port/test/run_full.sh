#!/bin/bash
source /home/repos/TornadoVM/corex_port/build/tenv.sh
cd /home/repos/TornadoVM
{
  echo "=== TornadoVM full unittest suite (PTX backend, ivcore11 / Iluvatar BI-V150) ==="
  echo "=== start $(date -u +%FT%TZ) ==="
  tornado --devices
  echo "=================== FULL SUITE: tornado-test --ea --verbose ==================="
  timeout 5400 tornado-test --ea --verbose
  echo "SUITE_RC=$?"
  echo "=== HeapFail memory-limit case (Makefile 'tests' target) ==="
  timeout 300 tornado-test --ea -V -J"-Dtornado.device.memory=1MB" uk.ac.manchester.tornado.unittests.fails.HeapFail#test03
  echo "HEAPFAIL_RC=$?"
  echo "=== end $(date -u +%FT%TZ) ==="
} 2>&1 | stdbuf -oL awk -f /home/repos/TornadoVM/corex_port/test/filter.awk > /home/repos/TornadoVM/corex_port/test/test.log
echo "RUN_FULL_DONE"
