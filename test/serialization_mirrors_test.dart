// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library serialization_test;

import 'dart:convert';
import 'dart:isolate';

import 'package:unittest/unittest.dart';
import 'package:serialization/serialization_mirrors.dart';
import 'package:serialization/src/serialization_helpers.dart';
import 'package:serialization/src/mirrors_helpers.dart';
import 'serialization_test_common.dart';

void main() {
  newSerialization = () =>
      new Serialization()
        ..addRuleFor(Person).configureForMaps()
        ..addRuleFor(Address).configureForMaps();

  newSerializationList = () =>
      new Serialization()
        ..addRuleFor(Person)
        ..addRuleFor(Address);

  newSerializationNodes = () =>
      new Serialization()..addRuleFor(Node);

  mirrors = true;

  commonTests();

  test('Slightly further with a simple object', () {
    var p1 = new Person()..name = 'Alice'..address = a1;
    var s = new Serialization()
        ..addRuleFor(Person).configureForMaps()
        ..addRuleFor(Address).configureForMaps();
    // TODO(alanknight): Need a better API for getting to flat state without
    // actually writing.
    var w = new Writer(s, const InternalMapFormat());
    w.write(p1);
    var personRule = s.rules.firstWhere(
        (x) => x is BasicRule && x.type == const Serializable().reflectClass(p1.runtimeType));
    var flatPerson = w.states[personRule.number].first;
    var primStates = w.states.first;
    expect(primStates.isEmpty, true);
    expect(flatPerson["name"], "Alice");
    var ref = flatPerson["address"];
    expect(ref is Reference, true);
    var addressRule = s.rules.firstWhere(
        (x) => x is BasicRule && x.type == const Serializable().reflectClass(a1.runtimeType));
    expect(ref.ruleNumber, addressRule.number);
    expect(ref.objectNumber, 0);
    expect(w.states[addressRule.number].first['street'], 'N 34th');
  });

  test('exclude fields', () {
    var s = new Serialization()
        ..addRuleFor(Address,
            excludeFields: ['state', 'zip']).configureForMaps();
    var extracted = states(a1, s).first;
    expect(extracted.length, 2);
    expect(extracted['street'], 'N 34th');
    expect(extracted['city'], 'Seattle');
    Reader reader = setUpReader(s, extracted);
    Address a2 = readBackSimple(s, a1, reader);
    expect(a2.state, null);
    expect(a2.city, 'Seattle');
  });

  test('different kinds of fields', () {
    var x = new Various.Foo("d", "e");
    x.a = "a";
    x.b = "b";
    setC(x, "c");
    var s = new Serialization()
      ..addRuleFor(Various,
          constructor: "Foo",
          constructorFields: ["d", "e"]);
    var state = states(x, s).first;
    expect(state.length, 4);
    var expected = "abde";
    for (var i in [0,1,2,3]) {
      expect(state[i], expected[i]);
    }
    Reader reader = setUpReader(s, state);
    Various y = readBackSimple(s, x, reader);
    expect(x.a, y.a);
    expect(x.b, y.b);
    expect(x.d, y.d);
    expect(x.e, y.e);
    expect(getC(y), 'default value');
  });

  test('Stream', () {
    // This is an interesting case. The Stream doesn't expose its internal
    // collection at all, and sets it in the constructor. So to get it we
    // read a private field and then set that via the constructor. That works
    // but should we have some kind of large red flag that you're using private
    // state.
    var stream = new Stream([3,4,5]);
    expect((stream..next()).next(), 4);
    expect(stream.position, 2);
    // The Symbol class does not allow us to create symbols for private
    // variables. However, the mirror system uses them. So we get the symbol
    // we want from the mirror.
    // TODO(alanknight): Either delete this test and decide we shouldn't
    // attempt to access private variables or fix this properly.
    var _collectionSym = const Serializable().reflectClass(stream.runtimeType).declarations.keys.firstWhere(
        (x) => const SymbolNameView().name(x) == "_collection");
    var s = new Serialization()
      ..addRuleFor(Stream,
          constructorFields: [_collectionSym]);
    var state = states(stream, s).first;
    // Define names for the variable offsets to make this more readable.
    var _collection = 0, position = 1;
    expect(state[_collection],[3,4,5]);
    expect(state[position], 2);
  });

  test('round-trip', () {
    runRoundTripTest(nodeSerializerReflective);
  });

  test('round-trip with explicit self-description', () {
    // We provide a setup function which, when run the second time,
    // returns a blank serialization, to make sure it will fail
    // the second time.
    var s;
    oneShotSetup(node) {
      if (s == null) {
        s = nodeSerializerReflective(node)..selfDescribing = true;
        return s;
      } else {
        s = null;
        return new Serialization.blank()
            ..namedObjects['Node'] = const Serializable().reflectClass(Node);
      }
    }

    runRoundTripTest(oneShotSetup);
  });

  test('round-trip with essential parent', () {
    runRoundTripTest(nodeSerializerWithEssentialParent);
  });

  test('round-trip, flat format', () {
    runRoundTripTestFlat(nodeSerializerReflective);
  });

  test('round-trip using Maps', () {
    runRoundTripTest(nodeSerializerUsingMaps);
  });

  test('round-trip, flat format, using maps', () {
    runRoundTripTestFlat(nodeSerializerUsingMaps);
  });

  test('eating your own tail', () {
    // Create a meta-serializer, that serializes serializations, then
    // use it to serialize a basic serialization, then run a test on the
    // the result.
    var s = new Serialization.blank()
      // Add the rules in a deliberately unusual order.
      ..addRuleFor(Node, constructorFields: ['name'])
      ..addRule(new ListRule())
      ..addRule(new PrimitiveRule())
      ..selfDescribing = false;
    var meta = metaSerialization();
    var metaWithMaps = metaSerializationUsingMaps();
    for (var eachFormat in formats) {
      for (var eachMeta in [meta, metaWithMaps]) {
        var serialized = eachMeta.write(s, format: eachFormat);
        var newSerialization = eachMeta.read(serialized, format: eachFormat,
            externals: {"serialization_test.Node" : const Serializable().reflectClass(Node)}
        );
        runRoundTripTest((x) => newSerialization);
      }
    }
  });

  test("Verify we're not serializing lists twice if they're essential", () {
    Node n1 = new Node("1"), n2 = new Node("2"), n3 = new Node("3");
    n1.children = [n2, n3];
    n2.parent = n1;
    n3.parent = n1;
    var s = new Serialization()
      ..addRuleFor(Node, constructorFields: ["name"]).
          setFieldWith("children", (parent, child) =>
              parent.reflectee.children = child);
    var w = new Writer(s);
    w.write(n1);
    expect(w.rules[2] is ListRuleEssential, isTrue);
    expect(w.rules[1] is ListRule, isTrue);
    expect(w.states[1].length, 0);
    expect(w.states[2].length, 1);
    s = new Serialization()
      ..addRuleFor(Node, constructorFields: ["name"]);
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
      ..addRuleFor(NodeEqualByName, constructorFields: ["name"]);
    var m1 = writeAndReadBack(s, null, n1);
    var m2 = m1.children.first;
    var m3 = m1.children.last;
    expect(m1, m2);
    expect(identical(m1, m2), isFalse);
    expect(m1 == m3, isFalse);
    expect(identical(m2.parent, m3.parent), isTrue);
  });

  test("Constant values as fields", () {
    var s = new Serialization()
      ..selfDescribing = false
      ..addRuleFor(Address,
          constructor: 'withData',
          constructorFields: ["street", "Kirkland", "WA", "98103"],
          fields: []);
    var out = s.write(a1);
    var newAddress = s.read(out);
    expect(newAddress.street, a1.street);
    expect(newAddress.city, "Kirkland");
    expect(newAddress.state, "WA");
    expect(newAddress.zip, "98103");
  });

  test("Straight JSON format, nested objects", () {
    var p1 = new Person()..name = 'Alice'..address = a1;
    var s = new Serialization()..selfDescribing = false;
    var addressRule = s.addRuleFor(Address)..configureForMaps();
    var personRule = s.addRuleFor(Person)..configureForMaps();
    var writer = s.newWriter(const SimpleJsonFormat(storeRoundTripInfo: true));
    var out = JSON.encode(writer.write(p1));
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

  test("Straight JSON format, non-string key", () {
    // This tests what happens if we have a key that's not a string. That's
    // not allowed by json, so we don't actually turn it into a json string,
    // but someone might reasonably convert to a json-able structure without
    // going through the string representation.
    var p1 = new Person()..name = 'Alice'..address = a1;
    var s = new Serialization()
        ..addRule(new PersonRuleReturningMapWithNonStringKey());
    var p2 = writeAndReadBack(s,
        const SimpleJsonFormat(storeRoundTripInfo: true), p1);
    expect(p2.name, "Alice");
    expect(p2.address.street, "N 34th");
  });

  test("Simple JSON format, round-trip with named objects", () {
    // Note that we can't use the usual round-trip test because it has cycles.
    var p1 = new Person()..name = 'Alice'..address = a1;
    // Use maps for one rule, lists for the other.
    var s = new Serialization()
      ..selfDescribing = false
      ..addRule(new NamedObjectRule())
      ..addRuleFor(Address)
      ..addRuleFor(Person).configureForMaps()
      ..namedObjects["foo"] = a1;
    var format = const SimpleJsonFormat(storeRoundTripInfo: true);
    var out = s.write(p1, format: format);
    var p2 = s.read(out, format: format, externals: {"foo" : 12});
    expect(p2.name, "Alice");
    var a2 = p2.address;
    expect(a2, 12);
  });


//  test("MirrorRule with lookup by qualified name rather than named object", () {
//    var s = new Serialization()..addRule(new MirrorRule());
//    var m = reflectClass(Address);
//    var output = s.write(m);
//    var input = s.read(output);
//    expect(input is ClassMirror, isTrue);
//    expect(MirrorSystem.getName(input.simpleName), "Address");
//  });
}

/**
 * Verify serialized output that we have passed to an isolate and back.
 */
void verify(input) {
  var s2 = nodeSerializerReflective(new Node("a"));
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

/******************************************************************************
 * The end of the tests and the beginning of various helper functions to make
 * it easier to write the repetitive sections.
 ******************************************************************************/

writeAndReadBack(Serialization s, Format format, object) {
  var output = s.write(object, format: format);
  return s.read(output, format: format);
}

/** Create a Serialization for serializing Serializations. */
Serialization metaSerialization() {
  // Make some bogus rule instances so we have something to feed rule creation
  // and get their types. If only we had class literals implemented...
  var basicRule = new BasicRule(const Serializable().reflectClass(null.runtimeType), '', [], [], []);

  var meta = new Serialization()
    ..selfDescribing = false
    ..addRuleFor(ListRule)
    ..addRuleFor(PrimitiveRule)
    // TODO(alanknight): Handle CustomRule as well.
    // Note that we're passing in a constant for one of the fields.
    ..addRuleFor(BasicRule,
        constructorFields: ['type',
          'constructorName',
          'constructorFields', 'regularFields', []],
        fields: [])
     ..addRuleFor(Serialization, constructor: "blank")
         .setFieldWith('rules',
           (InstanceView s, List rules) {
             rules.forEach((x) => s.reflectee.addRule(x));
           })
    ..addRule(new NamedObjectRule())
    ..addRule(new MirrorRule())
    ..addRule(new MapRule());
  return meta;
}

Serialization metaSerializationUsingMaps() {
  var meta = metaSerialization();
  meta.rules.where((each) => each is BasicRule)
      .forEach((x) => x.configureForMaps());
  return meta;
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

/** Return a serialization for Node objects, using a reflective rule. */
Serialization nodeSerializerReflective(Node n) {
  return new Serialization()
    ..addRuleFor(Node, constructorFields: ["name"])
    ..namedObjects['Node'] = const Serializable().reflectClass(new Node('').runtimeType);
}

/**
 * Return a serialization for Node objects but using Maps for the internal
 * representation rather than lists.
 */
Serialization nodeSerializerUsingMaps(Node n) {
  return new Serialization()
    // Get the type using runtimeType to verify that works.
    ..addRuleFor(n.runtimeType, constructorFields: ["name"]).configureForMaps()
    ..namedObjects['Node'] = const Serializable().reflectClass(Node);
}

/**
 * Return a serialization for Node objects but using Maps for the internal
 * representation rather than lists.
 */
Serialization nodeSerializerCustom(Node n) {
  return new Serialization()
    ..addRule(new NodeRule());
}

/**
 * Return a serialization for Node objects where the "parent" instance
 * variable is considered essential state.
 */
Serialization nodeSerializerWithEssentialParent(Node n) {
  // Force the node rule to be first, in order to make a cycle which would
  // not cause a problem if we handled the list first, because the list
  // considers all of its state non-essential, thus breaking the cycle.
  var s = new Serialization.blank()
    ..addRuleFor(
        Node,
        constructor: "parentEssential",
        constructorFields: ["parent"])
    ..addDefaultRules()
    ..namedObjects['Node'] = const Serializable().reflect(Node)
    ..selfDescribing = false;
  return s;
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

/** Extract the state from [object] using the rules in [s] and return it. */
List states(object, Serialization s) {
  var rules = s.rulesFor(object, null);
  return rules.map((x) => x.extractState(object, doNothing, null)).toList();
}

/** A hard-coded rule for serializing Node instances. */
class NodeRule extends CustomRule {
  bool appliesTo(instance, _) => instance.runtimeType == Node;
  getState(instance) => [instance.parent, instance.name, instance.children];
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

/**
 * Function used in an isolate to make sure that the output passes through
 * isolate serialization properly.
 */
void echo(initialMessage) {
  var msg = initialMessage[0];
  var reply = initialMessage[1];
  reply.send(msg);
}
