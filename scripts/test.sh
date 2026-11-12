#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

extra=()
frameworks="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
if [[ -d "$frameworks/Testing.framework" ]]; then
    extra+=(
        -Xswiftc -F -Xswiftc "$frameworks"
        -Xlinker -F -Xlinker "$frameworks"
        -Xlinker -rpath -Xlinker "$frameworks"
        -Xlinker -rpath -Xlinker "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
    )
fi

swift test --disable-xctest --enable-swift-testing "${extra[@]}" "$@"
