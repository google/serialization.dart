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
export 'package:mirror_tags/tag.dart' show MtClassMirror;

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
    var mySuperclass = const Serializable().reflectClass(raw.reflectedType);
    return mySuperclass;
  }

  /** Return true if the class has a field named [name]. Note that this
   * includes private fields, but excludes statics. */
  bool hasField(Symbol name, mirror) {
    if (name == null) return false;
    var field = mirror.getDeclaration(name);
    var field2 = mirror.declarations[name];
    if (field2 == null || (field.name != field2.name)) {
      print("Found different answers for getDeclaration($name) and declarations[$name]");
      print("$field vs. $field2");
    }
    if (field != null && field.isField && !field.isStatic) return true;
    return false;
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
      return this.reflectClass(candidate.reflectedType);
    } else {
      return null;
    }
  }

  static nameForSymbol(x) => mirrors.MirrorSystem.getName(x);
}

class SimpleSerializable extends Tag {
  const SimpleSerializable() : super(const []);

  /**
   * Given either an instance or a type, returns the type. Instances of Type
   * will be treated as types. Passing in an instance is really just backward
   * compatibility.
   */
   turnInstanceIntoSomethingWeCanUse(x) {
    if (x is Type) return reflectClass(x);
    return reflectClass(x.runtimeType);
  }
}