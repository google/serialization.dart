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

depending on whether or not you want the mirrored rules. These are
more convenient, but cause increased code size in dartj2s.

To use the transformer, include something in your pubspec like

     transformers:
       - serialization :
         $include: ["lib/stuff.dart", "lib/more_stuff.dart"]

and set up the generated rules in a Serialization instance, on which
you can then call write().

    import 'package:my_package/stuff_serialization_rules.dart' as foo;
     ...
     var serialization = new Serialization();
     foo.rules.values.forEach(serialization.addRule);
     ...
     sendToClient(serialization.write(somePerson));

and on the client, do something like

     p = readFromServer(personId).then((data) => serialization.read(data));

If you're using the mirrored rules, then you can just tell the
serialization which classes you're interested in.

      var serialization = new Serialization()
        ..addRuleFor(Address);
      serialization.write(address);

## Requests and bugs

Please file feature requests and bugs via the
[GitHub Issue Tracker][issues]. This is licensed under the
[same license as Dart][LICENSE]

## Disclaimer

This is not an official Google project.

[issues]: https://github.com/google/serialization.dart/issues
[LICENSE]: https://github.com/google/serialization.dart/blob/master/LICENSE
