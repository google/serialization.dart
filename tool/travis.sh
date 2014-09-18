#!/bin/bash

# Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
# All rights reserved. Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

function echo_and_run {
  echo "$" "$@"
  eval $(printf '%q ' "$@") < /dev/tty
}

# Fast fail the script on failures.
set -e

# Get the Dart SDK.
DART_DIST=dartsdk-linux-x64-release.zip
echo_and_run "curl https://storage.googleapis.com/dart-archive/channels/$DART_CHANNEL/release/latest/sdk/$DART_DIST > $DART_DIST"
unzip $DART_DIST > /dev/null
rm $DART_DIST
export DART_SDK="$PWD/dart-sdk"
export PATH="$DART_SDK/bin:$PATH"

# Display installed versions.
dart --version

# Get our packages.
echo_and_run pub get

# Verify that the libraries are error free.
echo_and_run "dartanalyzer --fatal-warnings lib/serialization.dart test/serialization_test.dart"

# Run the tests.
echo_and_run dart test/serialization_test.dart && dart test/no_library_test.dart
