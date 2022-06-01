#!/bin/bash
if which tusk; then
  exec $(which tusk) "$@"
  exit 1 # execfail defense
fi

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";
if [ ! -f $SCRIPT_DIR/../bin/tusk ]; then
  mkdir -p $SCRIPT_DIR/../bin
  curl -sL https://git.io/tusk | bash -s -- -b $SCRIPT_DIR/../bin latest
  chmod a+x $SCRIPT_DIR/../bin/tusk
fi
exec $SCRIPT_DIR/../bin/tusk "$@"
