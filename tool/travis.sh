#!/bin/bash

# Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
# All rights reserved. Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Fast fail the script on failures.
set -e

# Echo commands
set -x

# Get the Dart SDK.
DART_DIST=dartsdk-linux-x64-release.zip
#DART_DIST=dartsdk-macos-ia32-release.zip
curl https://storage.googleapis.com/dart-archive/channels/$DART_CHANNEL/release/latest/sdk/$DART_DIST -o $DART_DIST
unzip $DART_DIST > /dev/null
rm $DART_DIST
export DART_SDK="$PWD/dart-sdk"
export PATH="$DART_SDK/bin:$PATH"

# Display installed versions.
dart --version

# Get our packages.
pub get

# Verify that the libraries are error free.
dartanalyzer --fatal-warnings \
  lib/serialization.dart \
  lib/serialization_mirrors.dart \
  test/serialization_test.dart \
  test/serialization_mirrors_test.dart \
  lib/transformer.dart

# Run the tests.
dart test/serialization_test.dart && \
dart test/no_library_test.dart && \
dart test/serialization_mirrors_test.dart && \
pub run test/transformer/transformer_test && \
pub run test/transformer/transformer_maps_test && \
dart2js test/serialization_test.dart && \
cat $DART_SDK/lib/_internal/compiler/js_lib/preambles/d8.js out.js > foo.js && \
node foo.js && \
dart2js test/no_library_test.dart && \
cat $DART_SDK/lib/_internal/compiler/js_lib/preambles/d8.js out.js > foo.js && \
node foo.js && \
dart2js test/serialization_mirrors_test.dart && \
cat $DART_SDK/lib/_internal/compiler/js_lib/preambles/d8.js out.js > foo.js && \
node foo.js && \
(cd test/transformer && dart generate_standalone.dart) && \
dart2js test/transformer/transformer_test.dart && \
cat $DART_SDK/lib/_internal/compiler/js_lib/preambles/d8.js out.js > foo.js && \
node foo.js && \
dart2js test/transformer/transformer_maps_test.dart && \
cat $DART_SDK/lib/_internal/compiler/js_lib/preambles/d8.js out.js > foo.js && \
node foo.js
