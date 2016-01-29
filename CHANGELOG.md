## 0.10.4+3
  * Fix tests to deal with DateTimes on the VM using microseconds. 
  
## 0.10.4+2
  * Update prerequisites and .gitignore.

## 0.10.4+1
  * Added path package dependency (used in transformer).

## 0.10.4
  * Fix to handle null keys in maps.

## 0.10.3
  * Clean up setup for serialization. Adds `addRules`,
    `defaultFormat`, and a named `format` parameter to
    the constructors to set `defaultFormat`.

  * Improved the README.
	
## 0.10.2

  * Update README

  * Fixes for transformer when generating maps, test that option properly.

## 0.10.1

  * Adds a transformer that can generate serialization rules for simple
    classes.

## 0.10.0

  * BREAKING CHANGE: serialization.dart no longer imports dart:mirrors by
    default. If you want mirrors, import serialization_mirrors.dart instead.
    Note that the default ordering of rules has also changed, because the 
    non-mirrored version no longer includes SymbolRule, so even in the 
    mirrored version it occurs later in the order. So even if you are still
    using mirrors, data serialized using an older version with default rule
    setup may not deserialize in this version. If you need to do this, you 
    can explicitly create a Serialization instance with the old numbering.
