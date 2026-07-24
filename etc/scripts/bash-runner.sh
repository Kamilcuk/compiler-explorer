#!/usr/bin/env bash
set -euo pipefail

L_assert() {
    if ! "${@:2}"; then
        echo "Error: assertion failed (${@:2}): $1" >&2
        exit 1
    fi
}

L_regex_match() { [[ "$1" == $2 ]]; }

compile() {
  L_assert "expected at least 4 arguments, got $#" [ "$#" -ge 4 ]
  L_assert "argument 1 must be -g" [ "$1" = "-g" ]
  L_assert "argument 2 must be -o" [ "$2" = "-o" ]
  L_assert "argument 3 must be output.s" L_regex_match "$3" "*output.s"
  L_assert "argument 4 must be -S" [ "$4" = "-S" ]
  output="$3"
  shift 4
  args=("$@")
  input="${args[-1]}"
  L_assert "input file '$input' does not exist" [ -f "$input" ]
  bash --norc --noprofile -n "$input" || exit
  exec cp "$input" "$output"
}

execute() {
  file=$1
  L_assert "file must end with .s" L_regex_match "$file" '*output.s'
  L_assert "file '$file' does not exist or is not a regular file" [ -f "$file" ]
  compgen -V vars -e
  export -n "${vars[@]}"
  export PATH=/usr/bin/:/mnt/compiler-explorer/MYSTUFF/libs/L_lib/bin/
  cd /mnt/compiler-explorer/MYSTUFF/libs/L_lib
  exec bash --norc --noprofile "$@"
}

L_assert "missing first argument" [ -n "${1:-}" ]
if [[ "$1" == -g ]]; then
  compile "$@"
else
  execute "$@"
fi
