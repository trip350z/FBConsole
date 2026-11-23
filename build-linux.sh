#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p bin
lazbuild --ws="${1:-gtk2}" --build-all FBConsole.lpi
cp assets/FBConsole-linux.ico bin/FBConsole.ico
