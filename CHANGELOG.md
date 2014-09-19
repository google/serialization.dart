## 0.10.0

  * BREAKING CHANGE: serialization.dart no longer imports dart:mirrors by
    default. If you want mirrors, import serialization_mirrors.dart instead.
    Note that the default ordering of rules has also changed, because the 
    non-mirrored version no longer includes SymbolRule, so even in the 
    mirrored version it occurs later in the order. So even if you are still
    using mirrors, data serialized using an older version with default rule
    setup may not deserialize in this version. If you need to do this, you 
    can explicitly create a Serialization instance with the old numbering.
