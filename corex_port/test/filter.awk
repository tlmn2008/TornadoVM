# Keep all test-structure lines; keep only the first N native JNI driver-error
# lines (they are a repetitive cascade) and tally the rest to a sidecar file.
BEGIN { native_cap = 300; native_seen = 0 }
{
  if ($0 ~ /\[TornadoVM-PTX-(NVML-)?JNI\] (ERROR|Calling)/) {
    native_seen++
    if (native_seen <= native_cap) print
    next
  }
  print
}
END {
  print "[filter] native JNI driver-log lines total=" native_seen " (kept first " native_cap ")" > "/home/repos/TornadoVM/corex_port/test/native_jni_error_tally.txt"
}
