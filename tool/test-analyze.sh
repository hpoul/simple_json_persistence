#!/bin/bash

set -xeu

cd "${0%/*}"/..

flutter pub get
flutter analyze
dartfmt -n -l 120 --set-exit-if-changed "$(find lib -name '*.dart' \! -name '*.g.dart')"