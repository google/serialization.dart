// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Code that is common to testing serialization with and without mirrors.
library serialization_test;

import 'dart:convert';
import 'dart:isolate';

import 'package:serialization/serialization.dart';
import 'package:serialization/src/serialization_helpers.dart';
import 'package:unittest/unittest.dart';

part 'test_models.dart';

/// Set up a new serialization instance that can handle Address and Person.
Function newSerialization;

/// Set up a new serialization that handles Address and Person, mapping
/// them to Lists rather than Maps.
Function newSerializationList;

/// Set up a new serialization instance that can handle Node.
Function newSerializationNodes;

/// Are we testing with mirrors.
bool mirrors;

var p1 = new Person();
var a1 = new Address()..street = 'N 34th'..city = 'Seattle';

Node n1 = new Node("1"), n2 = new Node("2"), n3 = new Node("3");

initializeNodes() {
  n1.children = [n2, n3];
  n2.parent = n1;
  n3.parent = n1;
}

var formats = [const InternalMapFormat(),
               const SimpleFlatFormat(), const SimpleMapFormat(),
               const SimpleJsonFormat(storeRoundTripInfo: true)];

/// Tests in common between mirrored and non-mirrored testing. Because
/// this contains a setUp, it should be called first.
commonTests() {
  setUp(initializeNodes);

  test('Basic extraction of a simple object', () {
    var s = newSerialization();
    Map extracted = states(a1, s).first;
    expect(extracted.length, 4);
    expect(extracted['street'], 'N 34th');
    expect(extracted['city'], 'Seattle');
    expect(extracted['state'], null);
    expect(extracted['zip'], null);
    Reader reader = setUpReader(s, extracted);
    Address a2 = readBackSimple(s, a1, reader);
    expect(a2.street, 'N 34th');
    expect(a2.city, 'Seattle');
    expect(a2.state,null);
    expect(a2.zip, null);
  });

  test('list', () {
    var list = [5, 4, 3, 2, 1];
    var s = new Serialization();
    var extracted = states(list, s).first;
    expect(extracted.length, 5);
    for (var i = 0; i < 5; i++) {
      expect(extracted[i], (5 - i));
    }
    Reader reader = setUpReader(s, extracted);
    var list2 = readBackSimple(s, list, reader);
    expect(list, list2);
  });

  test('date', () {
    var date = new DateTime.now();
    var utcDate = new DateTime.utc(date.year, date.month, date.day,
        date.hour, date.minute, date.second, date.millisecond);
    var s = new Serialization();
    var out = s.write([date, utcDate]);
    expect(s.selfDescribing, isTrue);
    var input = s.read(out);
    expect(input.first, date);
    expect(input.last, utcDate);
  });

  test('Iteration helpers', () {
    var map = {"a" : 1, "b" : 2, "c" : 3};
    var list = [1, 2, 3];
    var set = new Set.from(list);
    var m = keysAndValues(map);
    var l = keysAndValues(list);
    var s = keysAndValues(set);

    m.forEach((key, value) {expect(key.codeUnits[0], value + 96);});
    l.forEach((key, value) {expect(key + 1, value);});
    var index = 0;
    var seen = new Set();
    s.forEach((key, value) {
      expect(key, index++);
      expect(seen.contains(value), isFalse);
      seen.add(value);
    });
    expect(seen.length, 3);

    var i = 0;
    m = values(map);
    l = values(list);
    s = values(set);
    m.forEach((each) {expect(each, ++i);});
    i = 0;
    l.forEach((each) {expect(each, ++i);});
    i = 0;
    s.forEach((each) {expect(each, ++i);});
    i = 0;

    seen = new Set();
    for (var each in m) {
      expect(seen.contains(each), isFalse);
      seen.add(each);
    }
    expect(seen.length, 3);
    i = 0;
    for (var each in l) {
      expect(each, ++i);
    }
  });

  test('Trace a cyclical structure', () {
    var s = newSerializationNodes();
    var trace = new Trace(new Writer(s));
    trace.writer.trace = trace;
    trace.trace(n1);
    var all = trace.writer.references.keys.toSet();
    expect(all.length, 4);
    expect(all.contains(n1), isTrue);
    expect(all.contains(n2), isTrue);
    expect(all.contains(n3), isTrue);
    expect(all.contains(n1.children), isTrue);
  });

  test('Flatten references in a cyclical structure', () {
    var s = newSerializationNodes();
    var w = new Writer(s, const InternalMapFormat());
    w.trace = new Trace(w);
    w.write(n1);
    var expectedLength = 6; // prims, lists * 2, map, date, node
    if (mirrors) expectedLength++; // Also Symbols
    expect(w.states.length, expectedLength);
    var children = 0, name = 1, parent = 2;
    var nodeRule = s.rules.firstWhere((x) => x.appliesTo(n1, null));
    List rootNode = w.states[nodeRule.number].where(
        (x) => x[name] == "1").toList();
    rootNode = rootNode.first;
    expect(rootNode[parent], isNull);
    var list = w.states[1].first;
    expect(w.stateForReference(rootNode[children]), list);
    var parentNode = w.stateForReference(list[0])[parent];
    expect(w.stateForReference(parentNode), rootNode);
  });

  test('round-trip', () {
    runRoundTripTest(nodeSerializerCustom);
  });

  test('round-trip ClosureRule', () {
    runRoundTripTest(nodeSerializerNonReflective);
  });

  test('round-trip with Node CustomRule', () {
    runRoundTripTestFlat(nodeSerializerCustom);
  });

  test('round-trip with Node CustomRule, to maps', () {
    runRoundTripTest(nodeSerializerCustom);
  });

  test("Straight JSON format", () {
    var s = newSerializationList();
    var writer = s.newWriter(const SimpleJsonFormat());
    var out = JSON.encode(writer.write(a1));
    var reconstituted = JSON.decode(out);
    expect(reconstituted.length, 4);
    expect(reconstituted[0], "Seattle");
  });

  test("Straight JSON format, round-trip", () {
    // Note that we can't use the usual round-trip test because it has cycles.
    var p1 = new Person()..name = 'Alice'..address = a1;
    var s = newSerialization();
    var p2 = writeAndReadBack(s,
        const SimpleJsonFormat(storeRoundTripInfo: true), p1);
    expect(p2.name, "Alice");
    var a2 = p2.address;
    expect(a2.street, "N 34th");
    expect(a2.city, "Seattle");
  });

  test("Root is a Map", () {
    // Note that we can't use the usual round-trip test because it has cycles.
    var p1 = new Person()..name = 'Alice'..address = a1;
    // TODO(alanknight): This test fails in non-mirrored mode
    // if we make one of these rules return
    // a Map. The original idea of CustomRules was that they always returned
    // Lists, but that doesn't work as well with a flat format. Something needs
    // to be generalized to be more the way BasicRule is handling this.
    for (var eachFormat in formats) {
      var s = newSerializationList()..defaultFormat = eachFormat;
      var output = s.write({"stuff" : p1});
      var result = s.read(output, format: eachFormat);
      var p2 = result["stuff"];
      expect(p2.name, "Alice");
      var a2 = p2.address;
      expect(a2.street, "N 34th");
      expect(a2.city, "Seattle");
    }
  });

  test("Root is a List", () {
    var s = newSerializationList();
    for (var eachFormat in formats) {
      var result = writeAndReadBack(s, eachFormat, [a1]);
    var a2 = result.first;
    expect(a2.street, "N 34th");
    expect(a2.city, "Seattle");
    }
  });

  test("Root is a simple object", () {
    var s = new Serialization();
    for (var eachFormat in formats) {
      expect(writeAndReadBack(s, eachFormat, null), null);
      expect(writeAndReadBack(s, eachFormat, [null]), [null]);
      expect(writeAndReadBack(s, eachFormat, 3), 3);
      expect(writeAndReadBack(s, eachFormat, [3]), [3]);
      expect(writeAndReadBack(s, eachFormat, "hello"), "hello");
      expect(writeAndReadBack(s, eachFormat, [3]), [3]);
      expect(writeAndReadBack(s, eachFormat, {"hello" : "world"}),
          {"hello" : "world"});
      expect(writeAndReadBack(s, eachFormat, true), true);
    }
  });

  test("More complicated Maps", () {
    // TODO(alanknight): CustomRules returning Maps do not work when we have
    // maps with non-simple keys.
    var s = newSerializationList();
    var p1 = new Person()..name = 'Alice'..address = a1;
    var data = new Map();
    data["simple data"] = 1;
    data[p1] = a1;
    data[a1] = p1;
    for (var eachFormat in formats) {
      var output = s.write(data, format: eachFormat);
      var input = s.read(output, format: eachFormat);
      expect(input["simple data"], data["simple data"]);
      var p2 = input.keys.firstWhere((x) => x is Person);
      var a2 = input.keys.firstWhere((x) => x is Address);
      if (eachFormat is SimpleJsonFormat) {
        // JSON doesn't handle cycles, so these won't be identical.
        expect(input[p2] is Address, isTrue);
        expect(input[a2] is Person, isTrue);
        var a3 = input[p2];
        expect(a3.city, a2.city);
        expect(a3.state, a2.state);
        expect(a3.state, a2.state);
        var p3 = input[a2];
        expect(p3.name, p2.name);
        expect(p3.rank, p2.rank);
        expect(p3.address.city, a2.city);
      } else {
        expect(input[p2], same(a2));
        expect(input[a2], same(p2));
      }
    }
  });

  test("Map with string keys stays that way", () {
    var s = newSerialization();
    var data = {"abc" : 1, "def" : "ghi"};
    data["person"] = new Person()..name = "Foo";
    var output = s.write(data, format: const InternalMapFormat());
    var mapRule = s.rules.firstWhere((x) => x is MapRule);
    var map = output["data"][mapRule.number][0];
    expect(map is Map, isTrue);
    expect(map["abc"], 1);
    expect(map["def"], "ghi");
    expect(map["person"] is Reference, isTrue);
  });

  test('round-trip, default format, pass to isolate', () {
      Node n1 = new Node("1"), n2 = new Node("2"), n3 = new Node("3");
      n1.children = [n2, n3];
      n2.parent = n1;
      n3.parent = n1;
      var s = nodeSerializerNonReflective(n1);
      var output = s.write(n2);
      ReceivePort port = new ReceivePort();
      var remote = Isolate.spawn(echo, [output, port.sendPort]);
      port.first.then(verify);
  });
}


/******************************************************************************
 * The end of the tests and the beginning of various helper functions to make
 * it easier to write the repetitive sections.
 ******************************************************************************/

writeAndReadBack(Serialization s, Format format, object) {
  var output = s.write(object, format: format);
  return s.read(output, format: format);
}

/**
 * Set up a basic reader with some fake data. Hard-codes the assumption
 * of how many rules there are.
 */
Reader setUpReader(aSerialization, sampleData) {
  var reader = new Reader(aSerialization);
  // We're not sure which rule needs the sample data, so put it everywhere
  // and trust that the extra will just be ignored.

  var fillValue = [sampleData];
  var data = [];
  for (int i = 0; i < 10; i++) {
    data.add(fillValue);
  }
  reader.data = data;
  return reader;
}

/**
 * Function used in an isolate to make sure that the output passes through
 * isolate serialization properly.
 */
void echo(initialMessage) {
  var msg = initialMessage[0];
  var reply = initialMessage[1];
  reply.send(msg);
}

/**
 * Verify serialized output that we have passed to an isolate and back.
 */
void verify(input) {
  var s2 = nodeSerializerNonReflective(new Node("a"));
  var m2 = s2.read(input);
  var m1 = m2.parent;
  expect(m1 is Node, isTrue);
  var children = m1.children;
  expect(m1.name,"1");
  var m3 = m1.children.last;
  expect(m2.name, "2");
  expect(m3.name, "3");
  expect(m2.parent, m1);
  expect(m3.parent, m1);
  expect(m1.parent, isNull);
}

/**
 * Run a round-trip test on a simple tree of nodes, using a serialization
 * that's returned by the [serializerSetUp] function.
 */
void runRoundTripTest(Function serializerSetUp) {
  Node n1 = new Node("1"), n2 = new Node("2"), n3 = new Node("3");
  n1.children = [n2, n3];
  n2.parent = n1;
  n3.parent = n1;
  var s = serializerSetUp(n1);
  var output = s.write(n2);
  var s2 = serializerSetUp(n1);
  var m2 = s2.read(output);
  var m1 = m2.parent;
  expect(m1 is Node, isTrue);
  var children = m1.children;
  expect(m1.name,"1");
  var m3 = m1.children.last;
  expect(m2.name, "2");
  expect(m3.name, "3");
  expect(m2.parent, m1);
  expect(m3.parent, m1);
  expect(m1.parent, isNull);
}

/**
 * Run a round-trip test on a simple of nodes, but using the flat format
 * rather than the maps.
 */
void runRoundTripTestFlat(serializerSetUp) {
  Node n1 = new Node("1"), n2 = new Node("2"), n3 = new Node("3");
  n1.children = [n2, n3];
  n2.parent = n1;
  n3.parent = n1;
  var s = serializerSetUp(n1);
  var output = s.write(n2, format: const SimpleFlatFormat());
  expect(output is List, isTrue);
  var s2 = serializerSetUp(n1);
  var m2 = s2.read(output, format: const SimpleFlatFormat());
  var m1 = m2.parent;
  expect(m1 is Node, isTrue);
  var children = m1.children;
  expect(m1.name,"1");
  var m3 = m1.children.last;
  expect(m2.name, "2");
  expect(m3.name, "3");
  expect(m2.parent, m1);
  expect(m3.parent, m1);
  expect(m1.parent, isNull);
}

/**
 * Return a serialization for Node objects using a hard-coded [CustomRule].
 */
Serialization nodeSerializerCustom(Node n) {
  return new Serialization()
    ..addRule(new NodeRule());
}

/** Return a serialization for Node objects using a ClosureToMapRule. */
Serialization nodeSerializerNonReflective(Node n) {
  var rule = new ClosureRule(
      n.runtimeType,
      (o) => {"name" : o.name, "children" : o.children, "parent" : o.parent},
      (map) => new Node(map["name"]),
      (object, map) {
        object
          ..children = map["children"]
          ..parent = map["parent"];
      });
  return new Serialization()
    ..selfDescribing = false
    ..addRule(rule);
}

/**
 * Read back a simple object, assumed to be the only one of its class in the
 * reader.
 */
readBackSimple(Serialization s, object, Reader reader) {
  var rule = s.rulesFor(object, null).first;
  reader.inflateForRule(rule);
  var list2 = reader.allObjectsForRule(rule).first;
  return list2;
}

/** Extract the state from [object] using the rules in [s] and return it. */
List states(object, Serialization s) {
  var rules = s.rulesFor(object, null);
  return rules.map((x) => x.extractState(object, doNothing, null)).toList();
}

class AddressRule extends CustomRule {
  bool appliesTo(instance, _) => instance is Address;
  getState(a) => [a.city, a.state, a.street, a.zip];
  create(data) => new Address.withData(data[2], data[0], data[1], data[3]);
  setState(a, data) {}
}

class AddressRuleMap extends CustomRule {
  bool appliesTo(instance, _) => instance is Address;
  getState(a) => {"street" : a.street, "city" : a.city,
    "state" : a.state, "zip" : a.zip};
  create(data) => new Address.withData(data['street'], data['city'],
      data['state'], data['zip']);
  setState(a, data) {}
}

class PersonRule extends CustomRule {
  bool appliesTo(instance, _) => instance is Person;
  getState(p) => [p.name, p.rank, p.serialNumber, p.address];
  create(data) => new Person();
  setState(a, data) {
    a
      ..name = data[0]
      ..rank = data[1]
      ..address = data[3]
      ..serialNumber = data[2];
  }
}

class PersonRuleMap extends CustomRule {
  bool appliesTo(instance, _) => instance is Person;
  getState(p) => {"name" : p.name, "rank" : p.rank,
    "serialNumber" : p.serialNumber, "address" : p.address};
  create(data) => new Person();
  setState(a, data) {
    a
      ..name = data["name"]
      ..rank = data["rank"]
      ..address = data["address"]
      ..serialNumber = data["serialNumber"];
  }
}

/** A hard-coded rule for serializing Node instances. */
class NodeRule extends CustomRule {
  bool appliesTo(instance, _) => instance is Node;
  getState(instance) => [instance.children, instance.name, instance.parent];
  create(state) => new Node(state[1]);
  void setState(Node node, state) {
    node.parent = state[2];
    node.children = state[0];
  }
}

class NodeEqualByNameRule extends NodeRule {
  create(state) => new NodeEqualByName(state[1]);
}

/// Give us access to the private member C.
setC(Various x, value) => x._c = value;
getC(Various x) => x._c;