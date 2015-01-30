// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Generate [CustomRule]s for simple model classes.
library custom_rule_generator;

import "package:analyzer/analyzer.dart";
import "package:serialization/serialization.dart" show Serializable;
import "package:path/path.dart" as path;
import "package:barback/barback.dart";
import "dart:io";


/// Template file which will be copied and where the generated rules will be
/// written.
const String GENERATED_RULES_TEMPLATE_PATH =
    "packages/serialization/src/generated_serialization_rules.dart";

/// This string can be found in the generated file. It indicates the location
/// where the imports required for the generated code must be appended.
const String GENERATED_IMPORTS_MARKER = "//{{GENERATED_IMPORTS_MARKER}}";

/// This string can be found in the generated file. It indicates the location
/// where the generated rules must be appended.
const String GENERATED_RULES_MARKER = "//{{GENERATED_RULES_MARKER}}";

/// This string can be found in the generated file. It indicates the location
/// where the [Map] of generated rules must be appended.
const String GENERATED_RULES_MAP_MARKER =  "//{{GENERATED_RULES_MAP_MARKER}}";

/// This string can be found in the generated rules and imports. It is used as
/// the name of an `as` in the import statement to avoid import conflicts.
const String AS_PLACEHOLDER = "{{AS_PLACEHOLDER}}";

/// Given the [contents] of a Dart source library, generate
/// [CustomRule]s hard-coded and other information for those classes and return.
///
/// If [listFormat] is true, then the output of the rule will be a list
/// of field values. If it is false, then the output is a map keyed by
/// field name. See the comment for transformer.dart.
AssetSerializationAnalysisResults analyzeAsset(String contents,
    {bool listFormat: true, processAnnotatedClasses: false,
    processAllClasses: false}) {

  var lib = parseCompilationUnit(contents);

  // Check if the file is a part of another or is the main library file and find
  // the library name.
  String libraryName;
  PartOfDirective partOf = lib.directives.firstWhere(
          (x) => x is PartOfDirective, orElse: () => null);
  if(partOf != null) {
    libraryName = partOf.libraryName.name;
  } else {
    LibraryDirective library = lib.directives.firstWhere(
            (x) => x is LibraryDirective, orElse: () => null);
    libraryName = library == null ? "__default" : library.name.name;
  }

  // Find out if the file has a "package:serialization/serialization.dart" or a
  // "package:serialization/serialization_mirrors.dart" import statement.
  bool importsSerialization = lib.directives.firstWhere(
      (x) => (x is ImportDirective) &&
             "${x.uri}".contains("package:serialization/serialization.dart"),
      orElse: () => null) != null;

  bool importsSerializationMirror = lib.directives.firstWhere(
      (x) => (x is ImportDirective) &&
             "${x.uri}".contains("package:serialization/"
                                 "serialization_mirrors.dart"),
      orElse: () => null) != null;

  // Check if the classes are annotated with @Serializable
  var classes = lib.declarations.where((x) {
    if (x is ClassDeclaration) {
      if (processAllClasses) return true;
      else return processAnnotatedClasses
          && x.metadata.any((m) => "${m.name}" == "$Serializable"
                                   || "${m.name}" == "serializable");
    }
    return false;
  });

  // There was no class declaration in this file or they were not annotated with
  // @Serializable when required.
  if (classes.length == 0) {
    return new AssetSerializationAnalysisResults(null, null, libraryName,
        partOf != null, importsSerialization, importsSerializationMirror);
  }

  // Generate a Rule for each Class declarations.
  var rules = classes.map(
      (each) => new CustomRuleGenerator(each, listFormat)).toList();
  var mapOfRuleNamesToRules = "\n" + rules
      .map((x) => "      {{AS_PLACEHOLDER}}.${x._declaration.name}: () => new "
          "$AS_PLACEHOLDER${x.ruleName}(),")
      .join("\n");
  var ruleDeclarations = rules.map((x) => x.rule).join("\n\n") + "\n\n";

  return new AssetSerializationAnalysisResults(ruleDeclarations,
      mapOfRuleNamesToRules, libraryName, partOf != null, importsSerialization,
      importsSerializationMirror);
}

/// Contains the result of the file analysis by the Serialization transformer.
class AssetSerializationAnalysisResults {

  /// Code of all the generated serialization rules for this file.
  final String generatedRule;

  /// Code to add to the [Map] of all the serialization rules for each [Type]s.
  final String ruleMapEntry;

  /// Library name of the file.
  final String library;

  /// Import statement to use to for the serialization Rule. This can only be
  /// known later in the case of "part of" files.
  String importStatement;

  /// True if the file is "part of" a library. False if it is the main library
  /// file.
  final bool isPartOf;

  /// True if the file imports the Serialization package. aka it has the
  /// following statement:
  ///
  ///     import "package:serialization/serialization.dart"...
  final bool importsSerialization;

  /// True if the file imports the Serialization with mirrors package. aka it
  /// has the following statement:
  ///
  ///     import "package:serialization/serialization_mirrors.dart"...
  final bool importsSerializationMirror;

  AssetSerializationAnalysisResults(this.generatedRule,
      this.ruleMapEntry, this.library, this.isPartOf, this.importsSerialization,
      this.importsSerializationMirror);

  /// Generates the import statement so that it imports this asset.
  void setImportStatementFromAsset(AssetId id) {
    List<String> splitPath = path.split(id.path);
    String topDir = splitPath.removeAt(0);
    if (topDir == "lib") {
      importStatement =
          "import 'package:${id.package}/${path.joinAll(splitPath)}' "
          "as $AS_PLACEHOLDER;\n";
    } else {
      importStatement = "import '${path.joinAll(splitPath)}'"
          " as $AS_PLACEHOLDER;\n";
    }
  }

  /// Generates the import statement so that it imports the file at the given
  /// [path].
  void setImportStatementFromPath(String path) {
    importStatement = "import '${path}' as $AS_PLACEHOLDER;\n";
  }
}

/// Given a list of File results returns the code for the generated rules file.
String generateSerializationRulesFileCode(
    List<AssetSerializationAnalysisResults> results) {

  File templateFile = new File(GENERATED_RULES_TEMPLATE_PATH);
  String template = templateFile.readAsStringSync();

  String asStatementPrefix = "_";
  int asStatementCounter = 0;

  for (AssetSerializationAnalysisResults result in results) {
    // Add the import statement.
    if (result.importStatement != null) {
      template = template.replaceFirst(GENERATED_IMPORTS_MARKER,
          // Sets the "as" import statement.
          result.importStatement.replaceAll(AS_PLACEHOLDER,
              "$asStatementPrefix$asStatementCounter")
              + GENERATED_IMPORTS_MARKER);
    }
    // Add the generated rules.
    template = template.replaceFirst(GENERATED_RULES_MARKER,
        result.generatedRule + GENERATED_RULES_MARKER);
    template = template.replaceFirst(GENERATED_RULES_MAP_MARKER,
        GENERATED_RULES_MAP_MARKER + result.ruleMapEntry);
    template = template.replaceAll(AS_PLACEHOLDER,
        "$asStatementPrefix$asStatementCounter");
    asStatementCounter++;
  }

  return template;
}

/// Generates serialization rules for simple classes.
///
/// Can handle fields,
/// getter/setter pairs, getters or fields matched with constructor
/// parameters that are direct assignments. It will always choose the
/// constructor with the fewest arguments. It cannot handle inheritance
/// or constructor arguments that are not of the form "this.field".
class CustomRuleGenerator {
  final ClassDeclaration _declaration;
  final bool isListFormat;

  CustomRuleGenerator(this._declaration, this.isListFormat);

  String get collectionStart => isListFormat ? '[' : '{';
  String get collectionEnd => isListFormat ? ']' : '}';
  nameInQuotes(field) => isListFormat ? '' : "'${field.publicName}' : ";

  /// Return something we can use to get the value for the field named
  /// [field] out of the state.
  ///
  /// If we are in listFormat, then that's a numeric
  /// index, and if we're in map format it's the name of the field. There's
  /// also a special allowance that if the name of the field is private and
  /// not found, we check for a corresponding public getter.
  deref(Field field) {
    if (!isListFormat) {
      return "'${field.publicName}'";
    } else {
      return allFields.indexOf(field);
    }
  }

  /// The name of the model class.
  String get targetName => _declaration.name.name;

  /// The name of the generated SerializationRule subclass.
  String get ruleName => targetName + 'SerializationRule';

  /// The header for a generated SerializationRule.
  String get header => '''
class $AS_PLACEHOLDER$ruleName extends CustomRule {
  bool appliesTo(instance, _) => instance.runtimeType == $AS_PLACEHOLDER.$targetName;
  create(state) => new $AS_PLACEHOLDER.$targetName$constructorName($constructorArgumentString);
  getState(instance) => $collectionStart
''';

  /// String with the arguments to pass to the constructor. We pass
  /// either some value from the state argument or null for things that
  /// are not direct field assignments.
  String get constructorArgumentString {
    if (shortestConstructor == null) return '';
    var constructorArgs = [];
    for (var arg in constructorParameters) {
      if (constructorParametersThatAreSetters.contains(arg)) {
        constructorArgs.add('state[${deref(arg)}]');
      } else {
        constructorArgs.add('null');
      }
    }
    return constructorArgs.join(", ");
  }

  /// String for the internals of the [getState()] method.
  String get getFields => allFields.map((field) =>
       "    ${nameInQuotes(field)}instance.${field.publicName}").join(",\n");

  /// String for the internals of the [setState()] method.
  String get setFields => individuallySetFields
      .map((field) =>
          "    instance.${field.publicName} = " "state[${deref(field)}]")
      .join(";\n");

  /// The bottom part of the SerializationRule class definition.
  get footer =>
      '$collectionEnd;\n' '  void setState($AS_PLACEHOLDER.$targetName instance, state) {\n'
      '$setFields${hasFields ? ";\n" : ""}' '  }\n' '}';

  /// The class definition of the generated SerializationRule.
  String get rule => "$header$getFields$footer";

  /// Helper function for filtering public members and getting their name.
  List<String> publicNamesWhere(Function f) =>
      f(_declaration.members)
          .where((each) => !each.name.name.startsWith("_"))
          .map((each) => each.name.name)
          .toList();

  /// All the public fields for the target class.
  List<Field> get publicFields => publicNamesWhere(
      (members) => members
          .where((each) => each is FieldDeclaration)
          .expand((x) => x.fields.variables))
          .map((x) => new Field(x, false))
          .toList();

  /// All getters from the target class.
  List<String> get getters =>
      publicNamesWhere((members) =>
          members.where((each) => each is MethodDeclaration && each.isGetter));

  /// All setters from the target class, without the trailing = in the name.
  List<String> get setters =>
      publicNamesWhere((members) =>
          members.where((each) => each is MethodDeclaration && each.isSetter));

  /// Are there any fields that aren't set by the constructor.
  bool get hasFields => individuallySetFields.isNotEmpty;

  /// Getters that have corresponding setters.
  List<Field> get gettersWithSetters => getters
      .where((getterName) => setters
          .any((setterName) => getterName == setterName))
      .map((name) => new Field(name, false))
      .toList();

  /// Getters that are set by constructor arguments.
  get gettersWithConstructorArgs =>
      getters
        .map((getterName) => new Field(getterName, false))
        .where(
            (field) => constructorParametersThatAreSetters.contains(field))
        .toList();

  /// Fields that are set by constructor arguments.
  get fieldswithConstructorArgs => publicFields.where(
      (field) => constructorParametersThatAreSetters.contains(field));

  /// All public constructors for the target class.
  List<ConstructorDeclaration> get constructors {
    if (_constructors != null) return _constructors;
    var filtered = _declaration.members.where(
        (each) => each is ConstructorDeclaration &&
            ((each.name == null) || !each.name.name.startsWith('_')));
    _constructors = new List<ConstructorDeclaration>.from(filtered);
    return _constructors;
  }
  var _constructors;

  /// The public constructor with the fewest parameters.
  ConstructorDeclaration get shortestConstructor {
    if (_shortest != null) return _shortest;
    if (constructors.isEmpty) return null;
    _shortest = constructors.reduce((one, other) =>
        one.parameters.length <= other.parameters.length ? one : other);
    return _shortest;
  }
  var _shortest;

  /// The name of the shortest constructor.
  String get constructorName =>
      shortestConstructor == null || shortestConstructor.name == null ?
          '' :
          '.${shortestConstructor.name.name}';

  /// Constructor parameters of the form "this.field"
  List<Field> get constructorParametersThatAreSetters {
    if (_setterParams != null) return _setterParams;
    if (shortestConstructor == null) return [];
    _setterParams = shortestConstructor.parameters.parameters
        .where((each) => each is FieldFormalParameter)
        .map((each) => new Field.constructor(each.identifier.name))
        .toList();
    return _setterParams;
  }
  var _setterParams;

  /// All parameters of the shortest constructor.
  List<Field> get constructorParameters =>
      shortestConstructor == null ?
          [] :
          new List<Field>.from(shortestConstructor.parameters.parameters.map(
              (each) => new Field.constructor(each.identifier.name)));

  /// All fields which are not set in the constructor.
  List<Field> get individuallySetFields =>
      allFields.where((each) => !constructorParameters.contains(each)).toList();

  /// All "fields", including public, getter/setter pairs, and getters/fields
  /// with matching constructor arguments in the shortest constructor.
  List<Field> get allFields {
    if (_allFields != null) return _allFields;
    _allFields = [publicFields, gettersWithSetters, gettersWithConstructorArgs,
                  fieldswithConstructorArgs].expand((x) => x).toSet().toList();
    _allFields.sort();
    return _allFields;
  }
  var _allFields;
}

/// Represents a 'field' or combination of getters, setters, and constructor
/// parameters that we can treat as a serializable field.
///
/// Note that we may create these with partial knowledge, e.g. we may
/// create one for just the getter and later combine it to produce one
/// that knows how it is set.
class Field implements Comparable {
  /// The name of the field, which might be a getter name.
  String name;
  /// If we are private, what's the equivalent public name.
  ///
  /// So, if we
  /// represent a private field with a public getter, this would be the
  /// getter name.
  String _publicName;
  /// Is this field used in the constructor.
  bool usedInConstructor;

  Field(this.name, this.usedInConstructor);

  /// Create a field known to be a constructor parameter.
  Field.constructor(this.name) : usedInConstructor = true;

  equals(aField) {
    if (aField is! Field) return false;
    return name == aField.name;
  }

  /// If we are private, what's the equivalent public name. So, if we
  /// represent a private field with a public getter, this would be the
  /// getter name.
  get publicName => _publicName != null ? _publicName : _publicName =
      _publicForm(name);

  _publicForm(String name) => name.startsWith('_') ? name.substring(1) : name;

  compareTo(aField) {
    if (aField is! Field) return 0;
    return publicName.compareTo(aField.publicName);
  }

  operator ==(aField) {
    if (aField is! Field) return false;
    return publicName == aField.publicName;
  }

  get hashCode => publicName.hashCode;

  toString() => 'Field($publicName)';
}
