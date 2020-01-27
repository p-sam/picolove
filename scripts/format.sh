#!/bin/bash

set -e

cd "$( dirname "${BASH_SOURCE[0]}" )/.."

for f in *.lua; do
	luafmt -w replace --use-tabs "$f"
done
