// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A transformer for generating [CustomRule] classes for simple
/// model classes.
///
/// Consider the case where we have some simple objects we want to transfer.
/// There's no inheritance among them, and the constructor arguments, if any,
/// are just field assignments. There aren't a lot of complex issues about
/// order in which objects must be created. We're talking between our own
/// client and server, both of them in Dart, so we don't have any requirements
/// on the format, and we don't need it to be particularly human readable.
/// But we do want to have web clients in Javascript, so we'd like to avoid
/// using mirrors.
///
/// We can write a [CustomRule] subclass that knows how to read and write
/// any particular object. For example,
/// if we had
///
///     class Person {
///        String name;
///        DateTime birthdate;
///        Address address;
///      }
///
/// We could write a rule like
///
///         class PersonSerializationRule {
///       appliesTo(obj) => obj.runtimeType == Person;
///       create(state) => new Person();
///       getState(Person instance) => [
///         instance.address,
///         instance.birthdate,
///         instance.name
///       ];
///       void setState(Person instance, state) {
///         instance.address = state[0];
///         instance.birthdate = state[1];
///         instance.name = state[2];
///       }
///
///  This has four methods. The appliesTo() method tells us that this rule only
///  applies
///  to instances of Person. It tests the runtimeType rather than using
///  an "is Person" test because it doesn't want to apply to subclasses.
///  The getState() method gets the values out of the instance and puts them
///  in a list. The create() and setState() methods know how to take those
///  type of lists and use them to create a new instance. The create method
///  is very simple here, but it would be more complicated if the constructor
///  took arguments.
///
///  Note that one of these fields is a complex object in its own right, an
///  Address. This class doesn't worry about how to get data from the Address
///  object or how to recreate it. That's the job of an
///  AddressSerializationRule.
///
///  This transformer generates rules like the above for each of the classes in
///  the libraries that are listed in the pubspec.
///
/// ## Usage
/// In your pubpsec
///
///     transformers:
///     - serialization :
///       useAnnotation: true
///       files:
///       - bin/stuff.dart
///       - lib/more_stuff.dart
///       format: <"lists"|"maps">
///
/// For each of the classes defined in one of the files listed in the `files:`
/// section and for each of the classes annotated with @Serializable()
/// (if `useAnnotation: true` is used) a serialization rule will be generated.
///
/// All the generated serialization rules are added to
/// `generated_serialization_rules.dart` files located at the base of the
/// project directories in build (bin, web etc...) and in the
/// packages/<package-name>/ if a 'lib' directory was present.
///
/// The format option can be either 'lists' or 'maps'. The default is
/// 'lists'. If
/// 'lists', then the generated rule reads and writes lists of all
/// fields where the values must all be present and are expected
/// to be positional in alphabetical order. This is the more efficient
/// format.
/// If 'maps', then the generated rule reads and writes maps from field
/// names to field values. This format is easier to debug.
///
/// The transformer will automatically add the generated rules to the
/// Serialization objects. To serialize objects use:
///
///     import 'package:serialization/serialization.dart';
///     ...
///     var serialization = new Serialization();
///     ...
///     sendToClient(serialization.write(somePerson));
///
/// and on the client, we would just need something like
///
///     p = readFromServer(personId).then((data) => serialization.read(data));
///
/// For an example, see the test/transformer directory. The program
/// generate_standalone.start will run the same code as the transformer
/// and produce example output.
///
/// ## Limitations
/// Note that this is quite limited. It does not handle inheritance at all.
/// If constructors have parameters which are not of the form "this.field",
/// those will always be passed as null. It will always use the constructor
/// with the fewest parameters. It does handle getter/setter pairs and
/// getters or fields which correspond to constructor parameters. It will
/// probably not work with part files, and it expects all the classes that will
/// be serialized to be listed in those files.
///
/// If the generated rule is not adequate for a particular class, or a class
/// that's not in one of these libraries needs to be serialized, it's
/// possible to write a different serialization rule and use it instead. Just
/// add that rule to the Serialization instead of the generated one. Pass your
/// custom serialization rules in the constructor:
///
///    Map<Type, SerializationRule> custom = {Dog: myCustomDogRule};
///    var serialization = new Serialization(customRules: custom);
///
/// This transformer can also be used as an example for a more sophisticated
/// version, which can be customized to the way classes in a particular project
/// are structured.
library serialization_transformer;

import "dart:async";
import "package:barback/barback.dart";
import "package:path/path.dart" as path;
import "package:serialization/src/custom_rule_generator.dart";

class SerializationTransformer extends AggregateTransformer {


  /// File copied from the template where the generated rules are written.
  static const String GENERATED_RULES_FILE_NAME =
      "generated_serialization_rules.dart";

  /// URI that is imported in source files when using serialization.
  static const String SERIALIZATION_IMPORT =
      "package:serialization/serialization.dart";

  BarbackSettings _settings;

  get allowedExtensions => ".dart";

  SerializationTransformer.asPlugin(this._settings);

  String classifyPrimary(AssetId id) {
    return "allAssets";
  }

  apply(AggregateTransform transform) {

    Completer completer = new Completer();

    // Extracting settings.
    bool useAnnotation = _settings.configuration['useAnnotation'];
    List<String> files = _settings.configuration['files'];
    if (files == null) files = new List();
    String format = _settings.configuration['format'];
    bool useLists = format == null || format == 'lists';

    // Create an Asset for each package file path defined in the pubspec
    // transformer attribute.
    List<String> packageFiles = files.where(
        (String s) => s.startsWith("package:"));
    List<Asset> packageAssets = new List();
    packageFiles.forEach((String packageFile){
      List<String> packageFilePathSplit =
          packageFile.replaceFirst("package:", "").split("/");
      String filePath = path.joinAll(
          new List.from(packageFilePathSplit)..insert(0, "packages"));
      String packageName = packageFilePathSplit.removeAt(0);
      String barbackPath = path.joinAll(
          new List.from(packageFilePathSplit)..insert(0, "lib"));
      AssetId assetId = new AssetId(packageName, barbackPath);
      packageAssets.add(new Asset.fromPath(assetId, filePath));
    });

    // Get the list of assets.
    Future<List<Asset>> assetsFuture = transform.primaryInputs.toList();

    assetsFuture.then((List<Asset> assets) {

      // Save what's the current project's package so we can differentiate the imported Assets (which we can't write to).
      String mainPackage = assets[0].id.package;

      // Add the packaged files defined in pubspec to the list of assets.
      assets.addAll(packageAssets);

      // Map of Libraries => [AssetId] to import.
      Map<String, AssetId> librariesPath = new Map();

      // All Generated Rule Code to include in the Template file.
      List<AssetSerializationAnalysisResults> allGeneratedRuleCodes =
          new List();

      transform.logger.info("Got template and ${assets.length} assets.");

      // Build the list of Future reads of all assets because we'll want to
      // process them sequentially.
      Future.forEach(assets, (Asset asset) {
        var id = asset.id;
        return asset.readAsString()..then((String content) {

          // Get code to inject in the template for the current asset.
          AssetSerializationAnalysisResults results = analyzeAsset(
              content,
              listFormat: useLists,
              processAnnotatedClasses: useAnnotation,
              processAllClasses: files.contains(id.path)
                  || (id.package != mainPackage));

          // If there are generated rules we'll add them to the template.
          if (results.generatedRule != null) {
            allGeneratedRuleCodes.add(results);
            if (_settings.mode == BarbackMode.DEBUG) {
              transform.logger.info("Compiled serialization rules for $id");
            }
          }
          // Keep track of all main libraries files. This will be useful to know
          // which files to import in the case of "part of" files.
          if (!results.isPartOf) {
            librariesPath[results.library] = id;
          }

          // List all assets that import the serialization package. We only do
          // that for assets in the current package because transformers can't
          // modify files outside the current package.
          if (results.importsSerialization && (id.package == mainPackage)) {
            Asset newAsset = replaceSerializationImport(content, id);
            transform.addOutput(newAsset);
            if (_settings.mode == BarbackMode.DEBUG) {
              transform.logger.info("Auto-imported serialization rules in $id");
            }
          }
        });
      }).then((_){
        // Generate the files containing the serialization rules and add them to
        // the transformer output.
        List<Asset> newAssets = generateSerializationRulesAsset(
            allGeneratedRuleCodes, librariesPath, mainPackage,
            transform.logger);
        newAssets.forEach(transform.addOutput);

        if (_settings.mode == BarbackMode.DEBUG) {
          for (Asset asset in newAssets) {
            transform.logger.info(
                "Generated serialization file ${asset.id.path}.");
          }
        }

        completer.complete();
      });
    });

    return completer.future;
  }

  /// Replaces the Serialization imports with the generated rules file import.
  /// Returns a new Asset with the new content.
  static Asset replaceSerializationImport(String content, AssetId id) {
    String newImport = GENERATED_RULES_FILE_NAME;
    int pathDepth = path.split(id.path).length - 2;
    for (int i = 0; i < pathDepth; i++) {
      newImport = "../$newImport";
    }
    content = content.replaceAll(SERIALIZATION_IMPORT, newImport);

    return new Asset.fromString(id, content);
  }

  /// Generates the files containing the serialization rules.
  static List<Asset> generateSerializationRulesAsset(
      List<AssetSerializationAnalysisResults> generatedRuleCodes,
      Map<String, AssetId> librariesPath, String mainPackage,
      TransformLogger logger) {

    // Map of importable Rules for each top directory.
    Map<String, List<AssetSerializationAnalysisResults>>
        importableRulesPerTopDir = new Map();
    librariesPath.values.forEach((AssetId assetId){
      // Getting top directory of the assets to import ("lib", "bin", "web").
      if (assetId.package == mainPackage) {
        String dir = path.split(assetId.path)[0];
        importableRulesPerTopDir[dir] = new List();
      }
    });

    // Adding generated rules code and imports to the Generated Rules Files.
    for(AssetSerializationAnalysisResults results in generatedRuleCodes) {

      // Finding AssetId to import.
      AssetId toImport = librariesPath[results.library];
      if (toImport == null) {
        logger.warning("Unable to add Serialization rules of library "
            "${results.library} becasue we couldn't find the file to import. "
            "This is likely happening becasue one of the files listed in the "
            "transfomer is a `part of` but the main library file was not also "
            "listed.");
      }

      // Generate the import statement in the result.
      results.setImportStatementFromAsset(toImport);

      // filter out files that can be imported for each top directory.
      for (String topDir in importableRulesPerTopDir.keys) {
        String topDirForImport = path.split(toImport.path)[0];
        if (topDirForImport == "lib" || topDirForImport == topDir) {
          importableRulesPerTopDir[topDir].add(results);
        }
      }
    }

    // Creating new assets with the generated code.
    List<Asset> newAssets = new List();
    for (String topDir in importableRulesPerTopDir.keys) {
      String code = generateSerializationRulesFileCode(
          importableRulesPerTopDir[topDir]);
      AssetId generatedRulesAssetId = new AssetId(mainPackage,
          "$topDir/$GENERATED_RULES_FILE_NAME");
      newAssets.add(new Asset.fromString(generatedRulesAssetId, code));
    }
    return newAssets;
  }


}
