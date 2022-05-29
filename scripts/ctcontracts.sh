#!/bin/bash
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";
$SCRIPT_DIR/tusk.sh -qf $SCRIPT_DIR/../tusk.yml "$@"
