#!/bin/bash
set -euo pipefail
test_nsjail() {
  set -euo pipefail
  CONFIG_NAME=${1:-bash-user-execution.cfg}
  CONFIG_NAME=$(basename "$CONFIG_NAME")
  script=("${@:2}")
  if (( ${#script[@]} == 0 )); then
    script=(/opt/compiler-explorer/etc/scripts/bash-runner.sh /app/output.s )
  fi
  TMPDIR=/tmp/ce-nsjail-test-$USER
  mkdir -vp "$TMPDIR"
  cat > "$TMPDIR/output.s" << 'EOF'
#!/bin/bash
echo "hello from nsjail"
EOF
  chmod +x "$TMPDIR/output.s"
  set -x
  cat "$TMPDIR/output.s"
  echo ==========
  # strace -e write,writev,wait4,waitid,execve,execveat -s 400 -ff
  strace -e openat,open,openat2,write,writev,execve,execveat -s 400 -ff \
    nsjail \
    -v -v -v -v --seccomp_log \
    --config /opt/compiler-explorer/etc/nsjail/$CONFIG_NAME \
    --time_limit=6 \
    --cwd /app \
    --bindmount "$TMPDIR:/app" \
    -- "${script[@]}" 2>&1
}
ARGS=("$@")
./manage.sh root sudo -u ce bash -s <<<"$(declare -p ARGS);$(declare -f test_nsjail); test_nsjail \"\${ARGS[@]}\""
