## 2.0.0-nullsafety.4

* Support for null safety.

## [1.0.3]

* Fixed bug where `SimpleJsonPersistence.delete()` did not correctly update cached value.

## [1.0.2]

* Use [getLibraryDirectory] on windows instead of [getApplicationDocumentsDirectory].
* Allow customizing base directory via [StoreBackend.defaultBaseDirectoryBuilder].

## [1.0.1]

* Make sure only one call to [update] runs at a time.
  (ie. fix race condition when two calls to update happens at the same time, 
  one would be overwritten by the other)

## [1.0.0+1]

* Fixed possible race condition with creating folders not being `await`ed.

## [1.0.0]

* Added .update() convenience method.

## [1.0.0-dev.2]

* make sure directories are created during initialization.

## [1.0.0-dev.1]  - 2020-04-21

* Refactored api, made it more simple
* Support for flutter web by using local s torage.

## [0.2.0] - 2019-01-07

* Upgrade to rxdart 0.23

## [0.1.1+2] - 2019-09-16

* Possible bug fix not correctly caching loaded files.

## [0.1.1+1] - 2019-08-19

* Added LICENSE file and more documentation.

## [0.1.1] - 2019-08-09

* Allow custom names for storage.
* Added simple example application.
* More test coverage.

## [0.1.0+1] - dartfmt

## [0.1.0] - 2019-08-09

* Initial Release
