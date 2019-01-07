## Minor Release 0.15.0

- Make pg_repack the default way to perform maintenance [#25](https://github.com/npwalker/pe_databases/pull/25)
- Start maintaining the reports table which we could not afford to perform a VACUUM FULL on
- Rename typoed `pe_databases::maintenance::disable_maintenace` parameter to `pe_databases::maintenance::disable_maintenance`

## Z Release 0.14.2
 - Allow not managing table settings [#21](https://github.com/npwalker/pe_databases/pull/21)

## Z Release 0.14.1

 - Set permissions on pe_databases directories [#18](https://github.com/npwalker/pe_databases/pull/18)
 - Log pe-classifier truncation to log files instead of STDOUT [#18](https://github.com/npwalker/pe_databases/pull/18)

## Minor Release 0.14.0

- Make compatible with PE 2018.1 [#17](https://github.com/npwalker/pe_databases/pull/17)

## Minor Release 0.13.0

 - Manage certnames and catalogs tables autovacuum_vacuum_scale_factor [#14](https://github.com/npwalker/pe_databases/pull/14)
 - Change way we cast strings to appease puppet lint

## Z Release 0.12.1

 - Add `--analyze` during VACUUM FULL commands run in maintenance [#13](https://github.com/npwalker/pe_databases/pull/13)

## Minor Release 0.12.0

 - Improve maintenance cron jobs [#12](https://github.com/npwalker/pe_databases/pull/12)
   - Change from reindexing all tables to VACUUM FULL on just the smaller tables

## Z Release 0.11.2

 - Fix metadata.json version

## Z Release 0.11.1

 - Correct logic for detecting PostgreSQL version

## Minor Release 0.11.0

 - Prepare for PostgreSQL 9.6 in PE 2017.3.0
 - Manage fact_values autovacuum again in 2017.3.0

## Z Release 0.10.1

 - Bug Fixes
   - Do not manage fact_values auto vacuum on PE 2017.2.0
