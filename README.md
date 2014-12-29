# General serialization for Dart objects.

[![Build Status](https://travis-ci.org/google/serialization.dart.svg?branch=master)](https://travis-ci.org/google/serialization.dart)

Save and restore objects flexibly.

This can serialize and de-serialize objects to multiple different
formats. It is most useful if you have Dart on both ends, rather
than needing to communicate with an external system. It can handle
cycles, inheritance, getters and setters, private or final fields set
via constructors, objects
serialized in different ways at different times, and other complex
options. It can handle serializing acyclic objects with only public
fields to a simple JSON format, but might be more heavyweight than is
necessary if that's the only requirement.

This has no privileged access to object representations, so objects
are accessed and created according to their public APIs. As a result,
serializations from older versions where the internal representation
has changed can still be read as long as the public API is still available.

The way an object's state is read and written is defined by
SerializationRules. These can be implemented in various ways. The
easiest to use is using mirrors to find the members. Rules can also be
hand-written or, for relatively simple classes, generated using a
transformer.

## Usage

Import either

    import "package:serialization/serialization.dart"

or

    import "package:serialization/serialization_mirrors.dart"

depending on whether or not you want the mirrored rules. The mirror rules are
more convenient, but cause increased code size in dartj2s.

To use the transformer, include something in the pubspec like:

     transformers:
     - serialization :
       use_annotation: true
       files:
       - bin/stuff.dart
       - lib/more_stuff.dart
       - package:package_name/imported_stuff.dart

There are two ways to specify which Classes needs serialization:

 - You can annotate your classes with `@Serializable()` and specify the
   `use_annotation: true` parameter in the transformer. This only works for files
   part of your project. It won;t work for files part of imported packages.
 - You can list the Dart files in the `files:` parameter as shown above. In this
   case a Serialization rule will be generated for all the Classes in these
   files.

A file named `generated_serialization_rules.dart` containing all the
Serialization rules is created and imported automatically in your project. It
effectively overrides `Serialization` and provides a link to all generated rules
in `Serialization.automaticRules: Map<Type, Function>`. All these
rules are automatically add when creating a `new Serialization()` but if you'd
like to use one individually you can get an instance with:

    CustomRule personRule = serialization.automaticRules[Person]();

You can also choose to remove a generated serialization rule by doing Although
beware as this is a static member and doing so will potentially remove it for
all instances of Serialization:

    Serialization.automaticRules.remove(Person);

You can add your own manually written rule to a Serialization instance:

    Serialization serialization = new Serialization();
    serialization.addRule(new MyPersonSerializationRule());

It could also be more convenient to add your own manually written rule to all
Serialization instances or replace the generated one:

    Serialization.automaticRules[MyPerson] =
        () => new MyPersonSerializationRule();

You can set the name of the file containing all the generated rules with
`rules_file_name: 'my_generated_rules_file_name.dart'` this could be useful in
the case where you need to generate rules with different settings. For
instance if you generate rules as `map` output for a set of files and `list`
output for another set of files. In order to do this you would use
`$include: ["file.dart", "file2.dart"]` to run the transformer multiple times
on separate part of your project. The `test` directory shows an example of this.

Normally you won't ever see the generated files, because the
transformer creates it on the fly and it is sent directly to pub serve
or to dart2js without ever being written to disk.
To see the generated code, run pub build in debug mode, e.g.
if there is a program in the package's `bin` directory to run something
using these files, then

    pub build --mode=debug bin

would generate the code for that. You can then have a look at the file:

    build/bin/generated_serialization_rules.dart

It's also possible to run the transformer's code outside of the
transformer, which is helpful for debugging or to use the code in a
different way. See the `test/transformer/generate_standalone.dart' for
an example of that.

The bin directory code would look something like.

    import 'package:serialization/serialization.dart';
    ...
    var serialization = new Serialization();
    ...
    sendToClient(serialization.write(somePerson));

and on the client, do something like

     p = readFromServer(personId).then((data) => serialization.read(data));

Alternatively, if using the mirrored rules, just tell the
serialization which classes might be serialized.

      var serialization = new Serialization()
	    ..addRuleFor(Person);
        ..addRuleFor(Address);
      serialization.write(address);

For more concrete examples, see the `test` directory, and particularly
for examples of the transformer it may be useful to look at the
`pubspec.yaml` for this package, and the`test/transformer` directory.

## Requests and bugs

Please file feature requests and bugs via the
[GitHub Issue Tracker][issues]. This is licensed under the
[same license as Dart][LICENSE]

## Disclaimer

This is not an official Google project.

[issues]: https://github.com/google/serialization.dart/issues
[LICENSE]: https://github.com/google/serialization.dart/blob/master/LICENSE
