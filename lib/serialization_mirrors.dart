// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * Serialization support including using mirrors to serialize and deserialize
 * objects. This is kept in a separate library because using mirrors may
 * make it harder to minify code.
 */
library serialization_mirrors;

import 'package:serialization/serialization.dart' as s show Serialization;
import 'package:serialization/serialization.dart' hide Serialization;
export 'package:serialization/serialization.dart';
import 'src/serialization_helpers.dart';
import 'src/mirrors_helpers.dart';
import 'dart:collection';
//import 'dart:mirrors';

part 'src/basic_rule.dart';

class Serialization extends s.Serialization {
  /**
   * Creates a new serialization with a default set of rules for primitives
   * and lists.
   */
  factory Serialization() => new Serialization.blank()..addDefaultRules();

  /**
   * Creates a new serialization with no default rules at all. The most common
   * use for this is if we are reading self-describing serialized data and
   * will populate the rules from that data.
   */
  factory Serialization.blank()
    => new Serialization.forRules(new List<SerializationRule>());

  /** Internal constructor. */
  Serialization.forRules(List<SerializationRule> rules) : super.forRules(rules);

  /**
   * Create a [BasicRule] rule for [instanceOrType]. Normally this will be
   * a type, but for backward compatibilty we also allow you to pass an
   * instance (except an instance of Type), and the rule will be created
   * for its runtimeType. Optionally
   * allows specifying a [constructor] name, the list of [constructorFields],
   * and the list of [fields] not used in the constructor. Returns the new
   * rule. Note that [BasicRule] uses reflection, and so will not work with the
   * current state of dartj2s. If you need to run there, consider using
   * [CustomRule] instead.
   *
   * If the optional parameters aren't specified, the default constructor will
   * be used, and the list of fields will be computed. Alternatively, you can
   * omit [fields] and provide [excludeFields], which will then compute the
   * list of fields specifically excluding those listed.
   *
   * The fields can be actual public fields, but can also be getter/setter
   * pairs or getters whose value is provided in the constructor. For the
   * [constructorFields] they can also be arbitrary objects. Anything that is
   * not a String will be treated as a constant value to be used in any
   * construction of these objects.
   *
   * If the list of fields is computed, fields from the superclass will be
   * included. However, each subclass needs its own rule, since the constructors
   * are not inherited, and so may need to be specified separately for each
   * subclass.
   */
  BasicRule addRuleFor(
      instanceOrType,
      {String constructor,
        List constructorFields,
        List<String> fields,
        List<String> excludeFields}) {

    var rule = new BasicRule(
        const Serializable().turnInstanceIntoSomethingWeCanUse(instanceOrType),
        constructor, constructorFields, fields, excludeFields);
    addRule(rule);
    return rule;
  }

  /**
   * Create a new instance of Serialization.
   */
  // We need to do this to create a new instance of the appropriate subclass.
  Serialization newSerialization() => new Serialization();

  /**
   * Create a Serialization for serializing SerializationRules. This is used
   * to save the rules in a self-describing format along with the data.
   * If there are new rule classes created, they will need to be described
   * here.
   */
  Serialization ruleSerialization() {
    // TODO(alanknight): There's an extensibility issue here with new rules.
    // TODO(alanknight): How to handle rules with closures? They have to
    // exist on the other side, but we might be able to hook them up by name,
    // or we might just be able to validate that they're correctly set up
    // on the other side.

    Serialization meta = super.ruleSerialization();
    meta
      ..addRuleFor(BasicRule,
          constructorFields: ['type',
            'constructorName',
            'constructorFields', 'regularFields', []],
          fields: [])
      ..addRule(new MirrorRule())
      ..addRuleFor(MirrorRule)
      ..addRuleFor(SymbolRule);
    meta.namedObjects = namedObjects;
    return meta;
  }

  /** Set up the default rules, for lists and primitives. */
  void addDefaultRules() {
    super.addDefaultRules();
    addRule(new SymbolRule());
  }
}

/**
 * This rule handles the special case of Mirrors. It stores the mirror by its
 * qualifiedName and attempts to look it up in both the namedObjects
 * collection, or if it's not found there, by looking it up in the mirror
 * system. When reading, the user is responsible for supplying the appropriate
 * values in [Serialization.namedObjects] or in the [externals] paramter to
 * [Serialization.read].
 */
class MirrorRule extends NamedObjectRule {
  bool appliesTo(object, Writer writer) => object is ClassView;

  String nameFor(object, Writer writer) =>
      const SymbolNameView().name(object.qualifiedName);

  inflateEssential(state, Reader r) {
    var qualifiedName = r.resolveReference(state.first);
    var lookupFull = r.objectNamed(qualifiedName, (x) => null);
    if (lookupFull != null) return lookupFull;
    var separatorIndex = qualifiedName.lastIndexOf(".");
    var type = qualifiedName.substring(separatorIndex + 1);
    var lookup = r.objectNamed(type, (x) => null);
    if (lookup != null) return lookup;
    var name = qualifiedName.substring(0, separatorIndex);
    // This is very ugly. The library name for an unnamed library is its URI.
    // That can't be constructed as a Symbol, so we can't use findLibrary.
    // So follow one or the other path depending if it has a colon, which we
    // assume is in any URI and can't be in a Symbol.
    if (name.contains(":")) {
//      var uri = Uri.parse(name);
//      var libMirror = currentMirrorSystem().libraries[uri];
//      var candidate = libMirror.declarations[new Symbol(type)];
//      return candidate is ClassMirror ? const Serializable().reflectClass(candidate.reflectedType) : null;
    } else {
      return const Serializable().lookupType(qualifiedName);
//      var symbol = new Symbol(name);
//      var typeSymbol = new Symbol(type);
//      var lib = currentMirrorSystem().findLibrary(symbol);
//      for (var libMirror in currentMirrorSystem().libraries.values) {
//        if (libMirror.simpleName != symbol) continue;
//        var candidate = libMirror.declarations[typeSymbol];
//        if (candidate != null && candidate is ClassMirror) return const Serializable().reflectClass(candidate.reflectedType);
//      }
//      return null;
    }
  }
}

/** A hard-coded rule for serializing Symbols. */
class SymbolRule extends CustomRule {
  bool appliesTo(instance, _) => instance is Symbol;
  getState(instance) => [const SymbolNameView().name(instance)];
  create(state) => new Symbol(state[0]);
  void setState(symbol, state) {}
  int get dataLength => 1;
  bool get hasVariableLengthEntries => false;
}
