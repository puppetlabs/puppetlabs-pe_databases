# Change log

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](http://semver.org).

## [v2.1.2](https://github.com/puppetlabs/puppetlabs-pe_databases/tree/v2.1.2) (2021-10-06)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-pe_databases/compare/v2.1.1...v2.1.2)

### Fixed

- \(SUP-2571\) Purge legacy cron jobs if present [\#97](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/97) ([gavindidrichsen](https://github.com/gavindidrichsen))
- \(SUP-2557\) Ensure backup class is not included by default [\#95](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/95) ([m0dular](https://github.com/m0dular))

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- \(SUP-2677\) Deprecate backup functionality [\#96](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/96) ([elainemccloskey](https://github.com/elainemccloskey))

## [v2.1.1](https://github.com/puppetlabs/puppetlabs-pe_databases/tree/v2.1.1) (2021-09-30)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-pe_databases/compare/v2.1.0...v2.1.1)

### Fixed

- \(SUP-2682\) Remove Requires= property from timers [\#92](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/92) ([m0dular](https://github.com/m0dular))

## [v2.1.0](https://github.com/puppetlabs/puppetlabs-pe_databases/tree/v2.1.0) (2021-07-13)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-pe_databases/compare/v2.0.0...v2.1.0)

### Added

- \(SUP-2545\) Disable table maintenance by default [\#83](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/83) ([m0dular](https://github.com/m0dular))

## [v2.0.0](https://github.com/puppetlabs/puppetlabs-pe_databases/tree/v2.0.0) (2021-07-02)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-pe_databases/compare/v1.2.0...v2.0.0)

### Changed

- Remove Puppet 5 support and EOL PE versions [\#76](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/76) ([MartyEwings](https://github.com/MartyEwings))
- SUP-2404 Migrate from cron to systemd timers [\#65](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/65) ([m0dular](https://github.com/m0dular))

### Added

- Addition of SLES 12 Test Platform [\#77](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/77) ([MartyEwings](https://github.com/MartyEwings))

### Fixed

- Fix path in backup.pp and reset pgrepack schema task [\#74](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/74) ([carabasdaniel](https://github.com/carabasdaniel))
- Fix scope of disable\_maintenance param [\#73](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/73) ([m0dular](https://github.com/m0dular))

## [v1.2.0](https://github.com/puppetlabs/puppetlabs-pe_databases/tree/v1.2.0) (2021-06-02)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-pe_databases/compare/v1.1.0...v1.2.0)

### Added

- Adding catalog\_inputs to the pg\_repack scheme for PE 2019.8.0+ [\#54](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/54) ([coreymbe](https://github.com/coreymbe))
- \(SUP-2372\) add pg\_repack schema reset task [\#53](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/53) ([pgrant87](https://github.com/pgrant87))
- \(SUP-2374\) Remove external module deps [\#51](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/51) ([MartyEwings](https://github.com/MartyEwings))
- \(sup-2095\) Remove cron\_core from dependencies [\#49](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/49) ([jarretlavallee](https://github.com/jarretlavallee))

## [v1.1.0](https://github.com/puppetlabs/puppetlabs-pe_databases/tree/v1.1.0) (2020-08-07)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-pe_databases/compare/1.0.1...v1.1.0)

### Added

- Changes to pg\_repack.pp per SUP-1949 [\#42](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/42) ([coreymbe](https://github.com/coreymbe))

### Fixed

- \(GH-30\) Update repack logging to separate files [\#43](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/43) ([jarretlavallee](https://github.com/jarretlavallee))

## [1.0.1](https://github.com/puppetlabs/puppetlabs-pe_databases/tree/1.0.1) (2020-03-25)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-pe_databases/compare/1.0.0...1.0.1)

## [1.0.0](https://github.com/puppetlabs/puppetlabs-pe_databases/tree/1.0.0) (2020-03-20)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-pe_databases/compare/0.15.0...1.0.0)

### Added

- Add resource events to pg repack [\#28](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/28) ([npwalker](https://github.com/npwalker))

### Fixed

- Refactor shell scripts [\#36](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/36) ([m0dular](https://github.com/m0dular))

## [0.15.0](https://github.com/puppetlabs/puppetlabs-pe_databases/tree/0.15.0) (2019-02-06)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-pe_databases/compare/0.14.2...0.15.0)

### Added

- Add pg\_repack as default maintenance strategy [\#25](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/25) ([npwalker](https://github.com/npwalker))
- Allow not managing table settings [\#21](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/21) ([reidmv](https://github.com/reidmv))

### Fixed

-  PE Database is a reserved node group name in 2019.0 [\#24](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/24) ([MartyEwings](https://github.com/MartyEwings))
- Set permissions on /opt/puppetlabs/pe\_databases and /opt/puppetlabs/pe\_databases/scripts [\#18](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/18) ([mmarod](https://github.com/mmarod))

## [0.14.2](https://github.com/puppetlabs/puppetlabs-pe_databases/tree/0.14.2) (2018-11-01)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-pe_databases/compare/0.14.1...0.14.2)

## [0.14.1](https://github.com/puppetlabs/puppetlabs-pe_databases/tree/0.14.1) (2018-06-25)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-pe_databases/compare/0.14.0...0.14.1)

## [0.14.0](https://github.com/puppetlabs/puppetlabs-pe_databases/tree/0.14.0) (2018-05-23)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-pe_databases/compare/0.13.0...0.14.0)

### Added

- Update for compatibility with 2018.1.0 [\#17](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/17) ([npwalker](https://github.com/npwalker))
- Add autovacuum settings for certnames and catalogs [\#14](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/14) ([npwalker](https://github.com/npwalker))

## [0.13.0](https://github.com/puppetlabs/puppetlabs-pe_databases/tree/0.13.0) (2017-12-01)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-pe_databases/compare/0.12.1...0.13.0)

## [0.12.1](https://github.com/puppetlabs/puppetlabs-pe_databases/tree/0.12.1) (2017-11-02)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-pe_databases/compare/0.12.0...0.12.1)

### Added

- Add analyze when performing VACUUM FULL [\#13](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/13) ([npwalker](https://github.com/npwalker))
- Make cronjobs to vacuum full PuppetDB tables [\#12](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/12) ([npwalker](https://github.com/npwalker))

## [0.12.0](https://github.com/puppetlabs/puppetlabs-pe_databases/tree/0.12.0) (2017-10-18)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-pe_databases/compare/0.11.2...0.12.0)

## [0.11.2](https://github.com/puppetlabs/puppetlabs-pe_databases/tree/0.11.2) (2017-09-19)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-pe_databases/compare/0.11.1...0.11.2)

## [0.11.1](https://github.com/puppetlabs/puppetlabs-pe_databases/tree/0.11.1) (2017-09-19)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-pe_databases/compare/0.11.0...0.11.1)

## [0.11.0](https://github.com/puppetlabs/puppetlabs-pe_databases/tree/0.11.0) (2017-09-19)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-pe_databases/compare/0.10.1...0.11.0)

### Fixed

- Do not manage fact\_values table in PuppetDB in PE 2017.2+ [\#6](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/6) ([npwalker](https://github.com/npwalker))

## [0.10.1](https://github.com/puppetlabs/puppetlabs-pe_databases/tree/0.10.1) (2017-06-19)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-pe_databases/compare/0.10.0...0.10.1)

## [0.10.0](https://github.com/puppetlabs/puppetlabs-pe_databases/tree/0.10.0) (2016-12-08)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-pe_databases/compare/0.9.0...0.10.0)

## [0.9.0](https://github.com/puppetlabs/puppetlabs-pe_databases/tree/0.9.0) (2016-12-05)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-pe_databases/compare/0.8.1...0.9.0)

## [0.8.1](https://github.com/puppetlabs/puppetlabs-pe_databases/tree/0.8.1) (2016-10-17)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-pe_databases/compare/0.8.0...0.8.1)

## [0.8.0](https://github.com/puppetlabs/puppetlabs-pe_databases/tree/0.8.0) (2016-10-17)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-pe_databases/compare/ed135c2576450d698a7338a70be62b9d7317761a...0.8.0)

### Added

- Add retention policy to backup script [\#4](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/4) ([npwalker](https://github.com/npwalker))
- Make an actual backup script [\#2](https://github.com/puppetlabs/puppetlabs-pe_databases/pull/2) ([npwalker](https://github.com/npwalker))



\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
