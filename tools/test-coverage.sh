#!/bin/bash

set -xeu

fail=false
flutter test --coverage || fail=true
echo "fail=$fail"
bash <(curl -s https://codecov.io/bash) -f coverage/lcov.info
