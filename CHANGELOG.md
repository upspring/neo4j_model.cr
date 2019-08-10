# Changelog

Arranged in reverse chronological order (latest changes on top).

## Unreleased

* Added: Pass a string to .order (instead of a symbol) and it will be passed through untouched. Example: "last_updated_at IS NOT NULL" (so that NULLs appear before actual values)
* Support for Crystal 0.30.0
* Support for Crystal 0.29.0
* Fixed: Bug in which #save would refuse to create a new (empty) node when it determined there were no changes to save

## v1.0.2 - 2019-06-01

* Support for Crystal 0.28.0
* Added: Support for Float64 properties
* Fixed: Set created_at timestamp on update if it is still null for some reason
* Fixed: Defined #hash to make Array#uniq work (as well as other things that depend on having proper hash keys)

## v1.0.1 - 2019-04-17

* Fixes to permit use alongside JSON.mapping

## v1.0.0 - 2019-04-06

It's not perfect, but it's good enough for a 1.0 release. There are lots of things I'd like to clean up, and I'd definitely like to reduce the impact on compile times, but it's plenty usable as-is.

* Fixed: Querying false values of boolean props was being treated IS NULL
* Fixed: Pluck was omitting NULL values (now returns nils as expected)
* Reworded "Neo4jModel doesn't know how to convert [type] to [type]" message to make it obvious that it's coming from Neo4jModel
* Updated to work with neo4j.cr 0.4

## v0.10.0 - 2019-02-16

* Added: #pluck (to avoid constructing model objects when all you want are property values)
* Added: #touch (updates updated_at timestamp, skips other callbacks)
* Fixed: Several issues with relationship property get/set
* Fixed: Several issues with using undeclared properties API to access declared properties
* Fixed: Can remove belongs_to/has_one associated objects by setting to nil or ""
* Support for Crystal 0.27.2
* Filled in missing return types
* Better handling for incoming blank strings (e.g. from web form submission)
* Increased default connection pool size from 5 to 25 (and added a setting; can also set to zero to disable pool)
* Improved debug output when a callback returns false (considered failure)

## v0.9.1 - 2019-01-19

* Added: find_by!
* Fixed: Omit SKIP and LIMIT from queries when not applicable
* Fixed: Redefined QueryProxy#skip in type-specific subclass to override Enumerable#skip

## v0.9.0 - 2018-12-20

* Added support for WHERE IN queries with array param
* Added support for arbitrary queries with arbitrary return values (some assembly required)
* Added QueryProxy#set_label
* Added QueryProxy#distinct (RETURN DISTINCT), with a caveat: cannot return rels if distinct is used
* Added optional argument `plural` to belongs_to and has_one
* Fixed issue that caused QueryProxy#map to require a call to #to_a first
* Fixed bug that prevented saving boolean false values (ended up saving as NULL)

## v0.8.0 - 2018-11-28

* Added support for serialized Array(String) and Hash(String, String) properties
* Added support for undeclared properties via [] and []= interface
* Updated rel properties API to match new undeclared properties API
* Added Relationship#get_i convenience method (casts to Int)
* Fix to allow non-nilable properties as long as they have defaults
* Fixed runtime error when trying to convert invalid/empty String to Int
* Changed license to Apache 2.0

## v0.7.1 - 2018-11-21

* Added connection pooling
* Fixes for chained association queries not being scoped appropriately
* Added Relationship classes to make it easier to read/write properties on associations

## v0.7.0 - 2018-11-16

* Support for Crystal 0.27.0
* Neo4j url and logger now configurable via Neo4jModel.settings
* Added support for logger, similar to Granite; added elapsed query time to log output
* Added test suite, added to travis
* Added _id/_ids meta-properties to allow set_properties/update to be used with assocations (for forms); belongs_to and has_one associations now wait until save to persist changes;
* Associations can now associate with same class (e.g. tree or linked list structures)
* #set_attributes now handles a wider variety of types
* Added find/find!/new/create class methods on QueryProxy
* Added self.order
* Reject changes to updated_at when called via update_columns

## v0.6.2 - 2018-11-06

* Expanded type handling for set_attributes
* Many other fixes

## v0.6.1 - 2018-11-03

* Fixes for associations and ordering
* Many other fixes

## v0.6.0 - 2018-11-02

* First implementation of proxy chaining
* Many other fixes

## v0.5.0 - 2018-11-01

* Added simple scopes
* Added #where_not
* handle nil => NULL transformation on where and set
* fix to make created_at/updated_at timestamps truly optional

## v0.4.1 - 2018-11-01

* First public release
