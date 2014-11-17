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
import 'serialization_helpers.dart';

class Serializable extends SimpleSerializable {
  const Serializable();

  /**
   * Return a list of all the public fields of a class, including inherited
   * fields.
   */
  Iterable<DeclarationView> publicFields(ClassView mirror) {
    var mine = mirror.declarations.values.where(
        (x) => x.isVariable && !(x.isPrivate || x.isStatic)).toList();
    var mySuperclass = mirror.superclass;
    if (mySuperclass != null) {
      return append(publicFields(mySuperclass), mine);
    } else {
      return new List<DeclarationView>.from(mine);
    }
  }

  /** Return true if the class has a field named [name]. Note that this
   * includes private fields, but excludes statics. */
  bool hasField(Symbol name, mirror) {
    if (name == null) return false;
    var field = mirror.declarations[name];
    if (field != null && field.isVariable && !field.isStatic) return true;
    var superclass = mirror.superclass;
    if (superclass == null) return false;
    return hasField(name, superclass);
  }

  /**
   * Return a list of all the getters of a class, including inherited
   * getters. Note that this allows private getters, but excludes statics.
   */
  Iterable<DeclarationView> publicGetters(mirror) {
    var mine = mirror.declarations.values.where(
        (x) => x.isMethod && x.isGetter && !(x.isPrivate || x.isStatic));
    var mySuperclass = mirror.superclass;
    if (mySuperclass != null) {
      return append(publicGetters(mySuperclass), mine);
    } else {
      return new List<DeclarationView>.from(mine);
    }
  }

  /** Return true if the class has a getter named [name] */
  bool hasGetter(Symbol name, ClassView mirror) {
    if (name == null) return false;
    var getter = mirror.declarations[name];
    if (getter != null && getter.isMethod && getter.isGetter && !getter.isStatic) {
      return true;
    }
    var superclass = mirror.superclass;
    if (superclass == null) return false;
    return hasField(name, superclass);
  }

  /**
   * Return a list of all the public getters of a class which have corresponding
   * setters.
   */
  Iterable<MethodMirror> publicGettersWithMatchingSetters(ClassMirror mirror) {
    var declarations = mirror.declarations;
    return publicGetters(mirror).where((each) =>
      // TODO(alanknight): Use new Symbol here?
      declarations["${each.simpleName}="] != null);
  }


  reflectClass(thing) => new ClassView()..type = mirrors.reflectClass(thing);

}

class SimpleSerializable {
  const SimpleSerializable();

  /**
   * Given either an instance or a type, returns the type. Instances of Type
   * will be treated as types. Passing in an instance is really just backward
   * compatibility.
   */
  SimpleClassView turnInstanceIntoSomethingWeCanUse(x) {
    if (x is Type) return reflectClass(x);
    return reflectClass(x.runtimeType);
  }

  reflectClass(thing) => new SimpleClassView()..type = mirrors.reflectClass(thing);
  reflect(thing) => new InstanceView()..mirror = mirrors.reflect(thing);
}


class SimpleClassView {
  mirrors.ClassMirror type;
  matches(object) => mirrors.reflect(object).type == type;
  get simpleName => type.simpleName;
  newInstance(Symbol constructorName, List parameters) {
    return type.newInstance(constructorName, parameters);
  }
  operator ==(x) => type == x.type;
}

class ClassView extends SimpleClassView {
  Map<Symbol, DeclarationView> get declarations =>
      new Map.fromIterables(
          type.declarations.keys,
          type.declarations.values
              .map((x) => new DeclarationView()
                  ..symbol = x.simpleName
                  ..mirror = x));

  ClassView get superclass =>
      type.superclass == null ?
          null :
          (new ClassView()..type = type.superclass);
  get qualifiedName => type.qualifiedName;
}

class DeclarationView {
  String name;
  Symbol symbol;
  mirrors.DeclarationMirror mirror;
  bool get isVariable => mirror is mirrors.VariableMirror;
  bool get isStatic => mirror.isStatic;
  bool get isPrivate => mirror.isPrivate;

  bool get isMethod => mirror is mirrors.MethodMirror;
  bool get isGetter => (mirror as mirrors.MethodMirror).isGetter;
  Symbol get simpleName => mirror.simpleName;

}

class SimpleInstanceView {
  mirrors.InstanceMirror mirror;
  getField(Symbol name) => mirror.getField(name).reflectee;
  setField(Symbol name, value) => mirror.setField(name, value);
}

class InstanceView extends SimpleInstanceView {
  get reflectee => mirror.reflectee;
}

class SymbolNameView {
  const SymbolNameView();
  String name(Symbol x) => mirrors.MirrorSystem.getName(x);
}
