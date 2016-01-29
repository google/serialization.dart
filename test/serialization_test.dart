// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library serialization_test;

import 'dart:convert';
import 'package:test/test.dart';
import 'package:serialization/serialization.dart';

import 'serialization_test_common.dart';

void main() {
  newSerialization = () =>
      new Serialization()
        ..addRule(new PersonRuleMap())
        ..addRule(new AddressRuleMap());

  newSerializationList = () =>
      new Serialization()
        ..addRule(new PersonRule())
        ..addRule(new AddressRule());

  newSerializationNodes = () =>
      new Serialization()..addRule(new NodeRule());

  mirrors = false;

  commonTests();

  test('Slightly further with a simple object', () {
    var p1 = new Person()..name = 'Alice'..address = a1;
    var s = new Serialization()
        ..addRule(new PersonRule())
        ..addRule(new AddressRuleMap());
    // TODO(alanknight): Need a better API for getting to flat state without
    // actually writing.
    var w = new Writer(s, const InternalMapFormat());
    w.write(p1);
    var personRule = s.rules.firstWhere(
        (x) => x is PersonRule);
    var flatPerson = w.states[personRule.number].first;
    var primStates = w.states.first;
    expect(primStates.isEmpty, true);
    expect(flatPerson[0], "Alice");
    var ref = flatPerson[3];
    expect(ref is Reference, true);
    var addressRule = s.rules.firstWhere(
        (x) => x is AddressRuleMap);
    expect(ref.ruleNumber, addressRule.number);
    expect(ref.objectNumber, 0);
    expect(w.states[addressRule.number].first['street'], 'N 34th');
  });

  test("Verify we're not serializing lists twice if they're essential", () {
    Node n1 = new Node("1"), n2 = new Node("2"), n3 = new Node("3");
    n1.children = [n2, n3];
    n2.parent = n1;
    n3.parent = n1;
    var s = new Serialization()
      ..addRule(new NodeRuleEssentialChildren());
    var w = new Writer(s);
    w.write(n1);
    expect(w.rules[2] is ListRuleEssential, isTrue);
    expect(w.rules[1] is ListRule, isTrue);
    expect(w.states[1].length, 0);
    expect(w.states[2].length, 1);
    s = new Serialization()
      ..addRule(new NodeRule());
    w = new Writer(s);
    w.write(n1);
    expect(w.states[1].length, 1);
    expect(w.states[2].length, 0);
  });

  test('Identity of equal objects preserved', () {
    Node n1 = new NodeEqualByName("foo"),
         n2 = new NodeEqualByName("foo"),
         n3 = new NodeEqualByName("3");
    n1.children = [n2, n3];
    n2.parent = n1;
    n3.parent = n1;
    var s = new Serialization()
      ..selfDescribing = false
      ..addRule(new NodeEqualByNameRule());
    var m1 = writeAndReadBack(s, null, n1);
    var m2 = m1.children.first;
    var m3 = m1.children.last;
    expect(m1, m2);
    expect(identical(m1, m2), isFalse);
    expect(m1 == m3, isFalse);
    expect(identical(m2.parent, m3.parent), isTrue);
  });

  test("Straight JSON format, nested objects", () {
    var p1 = new Person()..name = 'Alice'..address = a1;
    var format = const SimpleJsonFormat(storeRoundTripInfo: true);
    var s = new Serialization(format: format)..selfDescribing = false;
    var addressRule = s.addRule(new AddressRuleMap());
    var personRule = s.addRule(new PersonRuleMap());
    var out = JSON.encode(s.write(p1));
    var reconstituted = JSON.decode(out);
    var expected = {
      "name" : "Alice",
      "rank" : null,
      "serialNumber" : null,
      "_rule" : personRule.number,
      "address" : {
        "street" : "N 34th",
        "city" : "Seattle",
        "state" : null,
        "zip" : null,
        "_rule" : addressRule.number
      }
    };
    expect(expected, reconstituted);
  });

  test("Simple JSON format, round-trip with named objects", () {
    // Note that we can't use the usual round-trip test because it has cycles.
    var p1 = new Person()..name = 'Alice'..address = a1;
    // Use maps for one rule, lists for the other.
    var s = new Serialization()
      ..selfDescribing = false
      ..addRule(new NamedObjectRule())
      ..addRule(new AddressRule())
      ..addRule(new PersonRuleMap())
      ..namedObjects["foo"] = a1;
    var format = const SimpleJsonFormat(storeRoundTripInfo: true);
    var out = s.write(p1, format: format);
    var p2 = s.read(out, format: format, externals: {"foo" : 12});
    expect(p2.name, "Alice");
    var a2 = p2.address;
    expect(a2, 12);
  });
}

/** A hard-coded rule for serializing Node instances where the children
 * are treated as essential state.
 */
class NodeRuleEssentialChildren extends CustomRule {
  bool appliesTo(instance, _) => instance.runtimeType == Node;
  // TODO(alanknight): The essential state usage should be simpler.
  getState(instance) => [instance.parent, instance.name,
      new DesignatedRuleForObject(instance.children,
          (rule) => rule is ListRuleEssential || rule is PrimitiveRule)];
  create(state) => new Node(state[1]);
  void setState(Node node, state) {
    node.parent = state[0];
    node.children = state[2];
  }
}

/**
 * This is a rather silly rule which stores the address data in a map,
 * but inverts the keys and values, so we look up values and find the
 * corresponding key. This will lead to maps that aren't allowed in JSON,
 * and which have keys that need to be dereferenced.
 */
class PersonRuleReturningMapWithNonStringKey extends CustomRule {
  appliesTo(instance, _) => instance is Person;
  getState(instance) {
    return new Map()
      ..[instance.name] = "name"
      ..[instance.address] = "address";
  }
  create(state) => new Person();
  void setState(Person a, state) {
    a.name = findValue("name", state);
    a.address = findValue("address", state);
  }
  findValue(String key, Map state) {
    var answer;
    for (var each in state.keys) {
      var value = state[each];
      if (value == key) return each;
    }
    return null;
  }
}
