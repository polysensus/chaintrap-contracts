#!/bin/bash
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";
if [ ! -f $SCRIPT_DIR/../bin/tusk ]; then
  mkdir -p $SCRIPT_DIR/../bin
  curl -sL https://git.io/tusk | bash -s -- -b $SCRIPT_DIR/../bin latest
  chmod a+x $SCRIPT_DIR/../bin/tusk
fi
$SCRIPT_DIR/../bin/tusk "$@"
