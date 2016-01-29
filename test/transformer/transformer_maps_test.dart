// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library transformer_test;

import "package:serialization/serialization.dart";
import "test_models_for_maps.dart";
import "test_models_for_maps_serialization_rules.dart";
import "package:test/test.dart";

part "transformer_test_core.dart";

/// A custom rule for reading back a [DateTime] object. To write a [DateTime]
/// as a [String] it's enough if we include the [DateAsStringRule] in place of
/// (or just ahead of) the normal [DateTimeRule]. But when we read back
/// we have no information in the string itself that tells us it's to be
/// parsed as a date, so we need to handle that in the containing object.
/// We pretend that our main rule, [ThingWithDateSerializatinoRule] is generated
/// so we can't or don't want to just modify it, so instead we subclass and
/// modify the data before calling it.
class SpecialThingWithDateRule extends ThingWithDateSerializationRule {
  setState(object, state) {
    var newState = new Map()..addAll(state);
    newState["d"] = DateTime.parse(newState["d"]);
    super.setState(object, newState);
  }
}

/// A rule that serializes a [DateTime] by writing out its [toString] and
/// reads it back using [DateTime.parse]. This cannot be a [CustomRule]
/// because it relies on the more general API of [SerializationRule].
class DateAsStringRule extends SerializationRule {
  bool appliesTo(x, _) => x is DateTime;
  inflateEssential(state, reader) => DateTime.parse(state);
  inflateNonEssential(state, object, reader) {}
  extractState(obj, f, writer) => obj.toString();
  flatten(object, Writer writer) {}
  bool get storesStateAsPrimitives => true;
}

formatSpecificTests(serialization1, serialization2) {
  test("Verify that we are actually writing in map format", () {
    var written = serialization1.write(thing1);
    expect(written is Map, isTrue);
    expect(written['name'], 'thing1');
  });

  test("Test writing date as a string", () {
    var s = new Serialization.blank()
      ..addRule(new SpecialThingWithDateRule())
      ..addRule(new DateAsStringRule())
      ..addDefaultRules();
    var thing = new ThingWithDate()
      ..s = "foo"
      ..d = new DateTime(2014, 1, 2);
    var format = new SimpleJsonFormat(storeRoundTripInfo: true);
    var out = s.write(thing, format: format);
    expect(out["d"], "2014-01-02 00:00:00.000");
    var readBack = s.read(out, format: format);
    expect(readBack.d, thing.d);
  });
}