#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p .build
swiftc -O TrailRadio/SoundGenerator.swift Tests/main.swift -o .build/audio-tests
.build/audio-tests
