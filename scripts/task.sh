#!/bin/bash
if which task; then
  exec $(which task) "$@"
  exit 1 # execfail defense
fi

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";
if [ ! -f $SCRIPT_DIR/../bin/task ]; then
  pushd $SCRIPT_DIR/.. >> /dev/null 2>&1
  sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d
  popd >> /dev/null 2>&1
fi
exec $SCRIPT_DIR/../bin/task "$@"
