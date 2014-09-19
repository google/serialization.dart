# A general-purpose serialization facility for Dart Objects.

[![Build Status](https://travis-ci.org/google/serialization.dart.svg?branch=master)](https://travis-ci.org/google/serialization.dart)

This provides the ability to save and restore objects to pluggable
Formats using pluggable Rules.

These rules can use mirrors or be hard-coded. The main principle
is using only public APIs on the serialized objects, so changes to the
internal representation do not break previous serializations. It also handles
cycles, different representations, filling in known objects on the 
receiving side, and other issues. It is not as much intended for
APIs using JSON to pass acyclic structures without class information,
and is fairly heavweight and expensive for doing that compared to simpler
approaches.

## Warning - Generated code size implications

There are two different libraries which can be imported. The default 
library does not use `dart:mirrors`, so you need to write or generate
SerializationRule classes for everything that can be serialized and
make sure they're added to your Serialization instances. For a
nicer experience you can import `serialization\_mirrors.dart`, but 
this uses `dart:mirrors`, which can significantly increase the size of
generated JavasScript when compiled with dart2js. 
You can use `@MirrorsUsed` to try to mitigate
this issue.

## Requests and bugs

Please file feature requests and bugs via the [GitHub Issue Tracker][issues].

## Disclaimer

This is not an official Google project.

[issues]: https://github.com/google/serialization.dart/issues
