#!/bin/bash
set -euo pipefail

C_restart() {
  "$0" stop
  "$0" start "$@"
}

C_stop() {
  if systemctl --user is-active --quiet qemu-ubuntu; then
    echo "Sending shutdown signal to VM..."
    echo "system_powerdown" | socat - UNIX-CONNECT:"$MONITOR_SOCK"
    echo "Waiting up to 30 seconds for VM to exit..."
    count=0
    while systemctl --user is-active --quiet qemu-ubuntu && [ $count -lt 30 ]; do
      sleep 1
      count=$((count + 1))
    done

    if systemctl --user is-active --quiet qemu-ubuntu; then
      echo "Timeout reached. Force killing VM..."
      systemctl --user stop qemu-ubuntu
    else
      echo "VM stopped successfully."
    fi
  else
    echo "VM is not running."
  fi
  systemctl --user stop qemu-ubuntu || :
  systemctl --user reset-failed qemu-ubuntu || :
}

C_start() {
  mkdir -vp vm
  env USER=$USER UID=$UID "SSH_KEY=$(cat ~/.ssh/id_ed25519.pub)" envsubst <"$dir"/cloud-init.yml >vm/cloud-init.yml
  L_logrun cloud-localds vm/seed.iso vm/cloud-init.yml
  L_logrun cloud-init schema --config-file vm/cloud-init.yml
  cmd=(
    systemd-run --user --unit=qemu-ubuntu
    qemu-system-x86_64
    -enable-kvm -m 2G -smp 2
    -drive if=virtio,format=qcow2,file="$dir"/vm/overlay.qcow2
    -cdrom "$dir"/vm/seed.iso
    -netdev user,id=n1,hostfwd=tcp::40022-:22,hostfwd=tcp::10240-:10240
    -device virtio-net-pci,netdev=n1
    -nographic
    -fsdev local,id=fsdev0,path=$(readlink -f "$dir/.."),security_model=mapped-xattr,readonly=on
    -device virtio-9p-pci,fsdev=fsdev0,mount_tag=godbolt
    -monitor unix:"$MONITOR_SOCK",server,nowait
    -display none
    -serial unix:"$dir"/vm/qemu-serial.sock,server=on,wait=off
    "$@"
    # -append "console=ttyS0 systemd.journald.forward_to_console=1 noplymouth"
  )
  L_logrun "${cmd[@]}"
  timeout 1 "$0" lastlog -f --no-pager || :
  if ! systemctl --user is-active --quiet qemu-ubuntu; then
    echo "Error: VM failed to start. Checking logs..."
    C_lastlog --no-pager
    exit 1
  fi
}

log() { L_logrun journalctl --user -u qemu-ubuntu --since "1 hour ago" "$@"; }

C_log() { log "$@"; }

C_lastlog() {
  local id=$(systemctl --user show -p InvocationID --value qemu-ubuntu)
  log _SYSTEMD_INVOCATION_ID="$id" --no-pager "$@"
}

C_ssh() {
  L_logrun ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 40022 ce@localhost "$@"
}

C_distsetup_help="hello"
C_distsetup() {
  mkdir -vp vm
  if [[ ! -f vm/base.img ]]; then
    L_logrun wget https://cloud-images.ubuntu.com/releases/26.04/release/ubuntu-26.04-server-cloudimg-amd64.img -O vm/base.img
  fi
  "$0" distresetup
}

C_admin() {
  local tty=""
  if [[ -t 0 ]]; then tty=-t; fi
  trap - ERR
  L_logrun ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $tty -p 40022 admin2@localhost "$@"
}

C_root() {
  C_admin sudo -ni "$@"
}

C_distresetup() {
  L_logrun "$0" stop
  L_logrun rm -rf vm/overlay.qcow2
  L_logrun qemu-img create -f qcow2 -F qcow2 -b base.img vm/overlay.qcow2 20G
}

C_distclean() {
  L_logrun "$0" stop
  L_logrun rm -rf vm
}

C_read() {
  L_logrun socat -u unix-connect:"$dir"/vm/qemu-serial.sock -
}

C_serial() {
  L_logrun socat -,raw,echo=0 unix-connect:"$dir"/vm/qemu-serial.sock
}

wait_ssh() {
  local host="127.0.0.1"
  local port="40022"
  local timeout=120
  local start_time=$(date +%s)

  echo "Waiting for SSH on $host:$port (timeout: ${timeout}s)..."

  while true; do
    local now=$(date +%s)
    local elapsed=$(( now - start_time ))
    if (( elapsed >= timeout )); then
      echo "Timeout waiting for SSH."
      return 1
    fi

    if "$0" ssh true >/dev/null 2>&1; then
      echo "SSH is up."
      return 0
    fi
    echo "Waiting for SSH on $host:$port (${elapsed}s / ${timeout}s)..."
    sleep 2
  done
}

C_wait() {
  wait_ssh
}

C_celog() {
  if ((!$#)); then set -- -fa; fi
  C_root journalctl -u godbolt "$@"
}

C_ansible() {
  L_logrun uvx --from ansible env \
    ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_CALLBACK_RESULT_FORMAT=yaml \
    ansible-playbook \
    -i '127.0.0.1,' \
    -u admin2 \
    -e 'ansible_port=40022' \
    -e 'ansible_ssh_common_args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"' \
    --become \
    -v "$@"
}

dir=$(readlink -f "$(dirname "$0")")
cd "$dir"
MONITOR_SOCK=$dir/vm/qemu-monitor.sock
. L_lib.sh L_argparse -- call=function prefix=C_ ---- "$@"
