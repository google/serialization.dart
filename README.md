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
       useAnnotation: true
       files:
       - bin/stuff.dart
       - lib/more_stuff.dart
       - package:package_name/imported_stuff.dart

There are two ways to specify which Classes needs serialization:

 - You can annotate your classes with `@Serialization()` and specify the
   `useAnnotation: true` parameter in the transformer. This only works for files
   part of your project. It won;t work for files part of imported packages.
 - You can list the Dart files in the `files:` parameter as shown above. In this
   case a Serialization rule will be generated for all the Classes in these
   files.

A file named `generated_serialization_rules.dart` containing all the
Serialization rules is created and imported automatically in your project. It
effectively overrides `Serialization` and provides a link to all generated rules
in `Serialization.generatedSerializationRules: Map<Type, Function>`. All these
rules are automatically add when creating a `new Serialization()` but if you'd
like to use one individually you can get an instance with:

    CustomRule personRule = serialization.generatedSerializationRules[Person]();

You can also choose to remove a generated serialization rule by doing:

    serialization.generatedSerializationRules.remove(Person);

And adding your own manually written rule:

    Serialization serialization = new Serialization();
    serialization.addRule(new MyPersonSerializationRule);

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
