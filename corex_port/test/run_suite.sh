#!/bin/bash
# Drive the full TornadoVM unit-test suite (__TEST_THE_WORLD__, 127 classes) one
# class per fresh JVM with a per-class timeout, on the PTX backend / ivcore11.
# Rationale: the terminal PTX-rejection blocker makes every kernel test fail at
# cuModuleLoadData (rc=200); the repeated failures leave CoreX driver residue that
# hangs TornadoVM device-init on subsequent runs. Per-class timeout + JVM reaping
# keeps the run bounded and produces an honest per-class ledger.
source /home/repos/TornadoVM/corex_port/build/tenv.sh
export CUDA_VISIBLE_DEVICES=0   # single GPU (<=2, SOP compliant); simpler init
cd /home/repos/TornadoVM
LIST=corex_port/test/class_list.txt
LOG=corex_port/test/test.log
CSV=corex_port/test/results.csv
PER_CLASS_TIMEOUT=40
MAX_CONSEC_HANG=20

: > "$LOG"; : > "$CSV"
echo "class,status,ran,failed,unsupported" >> "$CSV"
{
echo "=== TornadoVM full unittest suite per-class runner (PTX backend, ivcore11 / BI-V150) ==="
echo "=== start $(date -u +%FT%TZ)  per_class_timeout=${PER_CLASS_TIMEOUT}s  device=0 ==="
tornado --devices 2>&1 | grep -avE "cuda-downloads|CUDA Toolkit|package manager|dpkg|apt|wget|Visit:|^$"
echo "=== NOTE: every kernel test is expected to FAIL at PTX JIT (cuModuleLoadData -> 200, CUDA_ERROR_INVALID_IMAGE), the terminal blocker ==="
} >> "$LOG" 2>&1

TOTAL_RUN=0; TOTAL_FAIL=0; TOTAL_UNSUP=0; NCLASS=0; NHANG=0; NEXEC=0; CONSEC_HANG=0
while IFS= read -r CLS; do
  [ -z "$CLS" ] && continue
  NCLASS=$((NCLASS+1))
  TMP=$(mktemp)
  timeout -s KILL ${PER_CLASS_TIMEOUT} tornado-test --ea -V "$CLS" > "$TMP" 2>&1
  rc=$?
  # Reap any lingering test JVM (timeout kills the python driver, not its child)
  pkill -9 -f "TornadoTestRunner" 2>/dev/null
  sleep 1
  SUMMARY=$(grep -aoE "Test ran: [0-9]+, Failed: [0-9]+(, Unsupported: [0-9]+)?" "$TMP" | tail -1)
  {
    echo ""
    echo "################ CLASS $NCLASS/127: $CLS  (rc=$rc) ################"
    # keep test markers + first 25 native driver-error lines, drop the flood + java stacktraces
    awk 'BEGIN{n=0}
         /\[TornadoVM-PTX-(NVML-)?JNI\]/{n++; if(n<=25)print; next}
         /^\s*at /{next}
         /Stacktrace: \[/{print "    [stacktrace omitted]"; next}
         {print}' "$TMP"
  } >> "$LOG"
  if [ -n "$SUMMARY" ]; then
    R=$(echo "$SUMMARY" | grep -oE "ran: [0-9]+" | grep -oE "[0-9]+")
    F=$(echo "$SUMMARY" | grep -oE "Failed: [0-9]+" | grep -oE "[0-9]+")
    U=$(echo "$SUMMARY" | grep -oE "Unsupported: [0-9]+" | grep -oE "[0-9]+"); U=${U:-0}
    TOTAL_RUN=$((TOTAL_RUN+R)); TOTAL_FAIL=$((TOTAL_FAIL+F)); TOTAL_UNSUP=$((TOTAL_UNSUP+U))
    NEXEC=$((NEXEC+1)); CONSEC_HANG=0
    echo "$CLS,executed,$R,$F,$U" >> "$CSV"
    echo ">>> $CLS : executed ran=$R failed=$F unsupported=$U" >> "$LOG"
  else
    NHANG=$((NHANG+1)); CONSEC_HANG=$((CONSEC_HANG+1))
    echo "$CLS,hung_or_no_summary,0,0,0" >> "$CSV"
    echo ">>> $CLS : HUNG/NO-SUMMARY (rc=$rc) — CoreX driver-residue init hang (counted as blocked, not as executed cases)" >> "$LOG"
  fi
  rm -f "$TMP"
  if [ $CONSEC_HANG -ge $MAX_CONSEC_HANG ]; then
    echo "=== EARLY STOP after $CONSEC_HANG consecutive init-hangs: CoreX driver is wedged (residue). Remaining classes not executed. ===" >> "$LOG"
    break
  fi
done < "$LIST"

{
echo ""
echo "==================== SUITE AGGREGATE ===================="
echo "classes_attempted=$NCLASS  classes_executed=$NEXEC  classes_hung=$NHANG"
echo "tests_run=$TOTAL_RUN  tests_failed=$TOTAL_FAIL  tests_unsupported(skipped)=$TOTAL_UNSUP  tests_passed=$((TOTAL_RUN-TOTAL_FAIL-TOTAL_UNSUP))"
echo "=== end $(date -u +%FT%TZ) ==="
} >> "$LOG"
echo "RUNNER_DONE run=$TOTAL_RUN fail=$TOTAL_FAIL unsup=$TOTAL_UNSUP exec_classes=$NEXEC hung=$NHANG"
