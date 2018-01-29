#!/bin/bash

echo "🤖 Assembling automation process"

root=`git rev-parse --show-toplevel`
cd "$root/Scripts"
swift build

echo "🏃 Running automation process"

output=`swift build --show-bin-path`
cd "$root"
"$output/automation"
