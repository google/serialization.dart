// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * Provides some additional convenience methods on top of the basic mirrors
 */
library mirrors_helpers;

// Import and re-export mirrors here to minimize both dependence on mirrors
// and the number of times we have to be told that mirrors aren't finished yet.
import 'dart:mirrors' as mirrors;
//export 'dart:mirrors';
import 'package:mirror_tags/tag.dart';
export 'package:mirror_tags/mirror.dart' show MtClassMirror;

import 'serialization_helpers.dart';
import 'package:serialization/serialization.dart';

class Serializable extends SimpleSerializable {
  const Serializable();

  /**
   * Return a list of all the public fields of a class, including inherited
   * fields.
   */
  publicFields(mirror) {
    var mine = mirror.declarations.values.where(
        (x) => x.isField && !(x.isPrivate || x.isStatic)).toList();
    var mySuperclass = getSuperclass(mirror);
    if (mySuperclass != null) {
      return append(publicFields(mySuperclass), mine);
    } else {
      return new List.from(mine);
    }
  }

  getSuperclass(mirror) {
    var raw = mirrors.reflectClass(mirror.type).superclass;
    if (raw == null) return null;
    var mySuperclass = const Serializable().reflectClassZZZ(raw.reflectedType);
    return mySuperclass;
  }

  /** Return true if the class has a field named [name]. Note that this
   * includes private fields, but excludes statics. */
  bool hasField(Symbol name, mirror) {
    if (name == null) return false;
    if (name == #children)
      print("children");
    var field = mirror.getDeclaration(name);
    if (field != null && field.isField && !field.isStatic) return true;
    var superclass = getSuperclass(mirror);
    if (superclass == null) return false;
    return hasField(name, superclass);
  }

  /**
   * Return a list of all the getters of a class, including inherited
   * getters. Note that this allows private getters, but excludes statics.
   */
  Iterable publicGetters(mirror) {
    var mine = mirror.declarations.values.where(
        (x) => x.isGetter && !(x.isPrivate || x.isStatic));
    var mySuperclass = getSuperclass(mirror);
    if (mySuperclass != null) {
      return append(publicGetters(mySuperclass), mine);
    } else {
      return new List.from(mine);
    }
  }

  /** Return true if the class has a getter named [name] */
  bool hasGetter(Symbol name, mirror) {
    if (name == null) return false;
    var getter = mirror.getDeclaration(name);
    if (getter != null && getter.isGetter && !getter.isStatic) {
      return true;
    }
    var superclass = getSuperclass(mirror);
    if (superclass == null) return false;
    return hasGetter(name, superclass);
  }

  lookupType(String qualifiedName) {
    var separatorIndex = qualifiedName.lastIndexOf(".");
    var type = qualifiedName.substring(separatorIndex + 1);
    var library = qualifiedName.substring(0, separatorIndex);
    var librarySymbol = new Symbol(library);
    var typeSymbol = new Symbol(type);
    var lib;
    try {
      lib = mirrors.currentMirrorSystem().findLibrary(librarySymbol);
    } on Exception catch (e) {
      throw new SerializationException("Cannot resolve $qualifiedName: $e");
    }
    var candidate = lib.declarations[typeSymbol];
    if (candidate != null) {
      return this.reflectClassZZZ(candidate.reflectedType);
    } else {
      return null;
    }
  }
}

class SimpleSerializable extends Tag {
  const SimpleSerializable() : super(const []);

  /**
   * Given either an instance or a type, returns the type. Instances of Type
   * will be treated as types. Passing in an instance is really just backward
   * compatibility.
   */
   turnInstanceIntoSomethingWeCanUse(x) {
    if (x is Type) return reflectClassZZZ(x);
    return reflectClassZZZ(x.runtimeType);
  }

  reflectClassZZZ(t) => Tag.reflectClass(t);
  reflectZZZ(t) => Tag.reflect(t);
}


//class SimpleClassView {
//  mirrors.ClassMirror _type;
//  SimpleClassView(Type type) : _type = mirrors.reflectClass(type);
//
//  matches(object) => mirrors.reflect(object).type == _type;
//  get simpleName => _type.simpleName;
//  newInstance(Symbol constructorName, List parameters) {
//    return _type.newInstance(constructorName, parameters);
//  }
//  operator ==(x) => _type == x._type;
//}


//class InstanceView {
//  mirrors.InstanceMirror _mirror;
//  InstanceView(thing) : _mirror = mirrors.reflect(thing);
//
//  getField(Symbol name) => _mirror.getField(name).reflectee;
//  setField(Symbol name, value) => _mirror.setField(name, value);
//  get reflectee => _mirror.reflectee;
//}


//class ClassView extends SimpleClassView {
//  ClassView(Type type) : super(type);
//
//  Map<Symbol, DeclarationView> get declarations =>
//      new Map.fromIterables(
//          _type.declarations.keys,
//          _type.declarations.values
//              .map((x) => new DeclarationView()
//                  ..symbol = x.simpleName
//                  ..mirror = x));
//
//  ClassView get superclass =>
//      _type.superclass == null ?
//          null :
//          (new ClassView(_type.superclass.reflectedType));
//
//  get qualifiedName => _type.qualifiedName;
//}

//class DeclarationView {
//  String name;
//  Symbol symbol;
//  mirrors.DeclarationMirror mirror;
//  bool get isVariable => mirror is mirrors.VariableMirror;
//  bool get isStatic => mirror.isStatic;
//  bool get isPrivate => mirror.isPrivate;
//
//  bool get isMethod => mirror is mirrors.MethodMirror;
//  bool get isGetter => (mirror as mirrors.MethodMirror).isGetter;
//  Symbol get simpleName => mirror.simpleName;
//}

class SymbolNameView {
  const SymbolNameView();
  String name(Symbol x) => mirrors.MirrorSystem.getName(x);
}
