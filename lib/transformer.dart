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
///  This transformer generates rules like the above for each class in
///  the libraries that are listed in the pubspec.
///
/// ## Usage
/// In your pubpsec
///
///     transformers:
///       - serialization :
///         $include: ["lib/stuff.dart", "lib/more_stuff.dart"]
///         format: <lists|maps>
///
/// For each library 'foo' listed in the $include section this will
/// generate a `foo_serialization_rules.dart` library with serialization
/// rules for those classes.
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
///  You can use the generated rules by adding them to a [Serialization].
///
///     import 'package:my_package/stuff_serialization_rules.dart' as foo;
///     ...
///     var serialization = new Serialization();
///     foo.rules.values.forEach(serialization.addRule);
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
/// possible to write a different rule and use it instead. Just
/// add that rule to the Serialization instead of the generated one. This
/// transformer can also be used as an example for a more sophisticated version,
/// which can be customized to the way classes in a particular project are
/// structured.
library serialization_transformer;

import "package:barback/barback.dart";
import "package:path/path.dart" as path;
import "package:serialization/src/custom_rule_generator.dart";


class SerializationTransformer extends Transformer {
  BarbackSettings _settings;

  get allowedExtensions => ".dart";

  SerializationTransformer.asPlugin(this._settings);

  apply(Transform t) {
    return t.readInputAsString(t.primaryInput.id).then((contents) {
      var id = t.primaryInput.id;
      var fileName = path.url.withoutExtension(id.path);
      var format = _settings.configuration['format'];
      var useLists = format == null || format == 'lists';
      var text = generateCustomRulesFor(
          contents,
          listFormat: useLists,
          libraryName: path.url.basename(fileName),
          originalImport: path.url.basename(id.path));
      var newId =
          new AssetId(id.package, "${fileName}_serialization_rules.dart");
      // Remove the leading /lib on the file name.
      var fileNameInPackage = path.joinAll(path.split(id.path).skip(1));
      if (_settings.mode == BarbackMode.DEBUG) {
        t.logger.info("Generated serialization rules in $newId");
      }
      t.addOutput(new Asset.fromString(newId, text));
    });
  }
}
