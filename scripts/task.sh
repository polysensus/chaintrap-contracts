#!/bin/bash
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";
pushd $SCRIPT_DIR/.. >> /dev/null 2>&1
if [ ! -f ./bin/task ]; then
  sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d
fi
popd >> /dev/null 2>&1
$SCRIPT_DIR/../bin/task "$@"
