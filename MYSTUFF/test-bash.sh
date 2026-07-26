#!/bin/bash
set -euo pipefail
func() {
  set -x
  ls
  echo 'Everything works and compiled!'
}
if (( $# == 0 )); then
  script="$(declare -f func);func"
else
  script="$@"
fi
script+=";#$EPOCHREALTIME"
script=$(jq -R -s '.' <<<$script)
tmp=$(curl -sS 'http://localhost:10240/api/compiler/bash/compile' \
  --compressed \
  -X POST \
  -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:152.0) Gecko/20100101 Firefox/152.0' \
  -H 'Accept: application/json, text/javascript, */*; q=0.01' \
  -H 'Accept-Language: en-US,pl;q=0.9' \
  -H 'Accept-Encoding: gzip, deflate, br, zstd' \
  -H 'Content-Type: application/json' \
  -H 'X-Requested-With: XMLHttpRequest' \
  -H 'Origin: http://localhost:10240' \
  -H 'DNT: 1' \
  -H 'Connection: keep-alive' \
  -H 'Referer: http://localhost:10240/' \
  -H 'Sec-Fetch-Dest: empty' \
  -H 'Sec-Fetch-Mode: cors' \
  -H 'Sec-Fetch-Site: same-origin' \
  --data-raw '{"source":'"$script"',"compiler":"bash","options":{"userArguments":"userarg","compilerOptions":{"producePp":null,"produceGccDump":{},"produceOptInfo":false,"produceCfg":false,"produceIr":null,"produceClangir":null,"produceOptPipeline":null,"produceDevice":false,"produceLeanC":null,"produceYul":null,"overrides":[]},"filters":{"binaryObject":false,"binary":false,"execute":true,"intel":true,"demangle":true,"labels":true,"directives":true,"commentOnly":true,"trim":false,"debugCalls":false},"tools":[],"libraries":[],"executeParameters":{"args":["arg1"],"stdin":"stdin"}},"lang":"bash","files":[],"bypassCache":0,"allowStoreCodeDebug":true}')
jq <<<"$tmp"
