Table of Contents
=================

- [Table of Contents](#table-of-contents)
- [Overview](#overview)
  - [What does this module provide?](#what-does-this-module-provide)
  - [Usage](#usage)
  - [Items you may want to configure](#items-you-may-want-to-configure)
    - [Backup Schedule](#backup-schedule)
    - [Backup Retention Policy](#backup-retention-policy)
    - [Disable Maintenance](#disable-maintenance)
- [General PostgreSQL Recommendations](#general-postgresql-recommendations)
  - [Tuning](#tuning)
  - [Backups](#backups)
  - [Maintenance](#maintenance)
  - [PostgreSQL Settings](#postgresql-settings)
    - [maintenance_work_mem](#maintenance_work_mem)
    - [work_mem](#work_mem)
    - [autovacuum_work_mem](#autovacuum_work_mem)
    - [autovacuum_max_workers](#autovacuum_max_workers)
    - [checkpoint_segments and checkpoint_completion_target](#checkpoint_segments-and-checkpoint_completion_target)
  - [How to Report an issue or contribute to the module](#how-to-report-an-issue-or-contribute-to-the-module)

# Overview

This module provides tuning, maintenance, and backups for PE PostgreSQL.

## What does this module provide?

This module provides the following functionaility

1.  Customized settings for PE PostgreSQL
1.  Maintenance to keep the `pe-puppetdb` database lean and fast
1.  Backups for all PE PostgreSQL databases, disabled by default
  - The `pe-puppetdb` database is backed up every week
  - Other databases are backed up every night

## Usage

In order to use this module, classify the node running PE PostgreSQL with the `pe_databases` class.
The Primary Server and Replica run PE PostgreSQL in most instances, but there may be one or more servers with this role in an XL deployment  

To classify via the PE Console, create a new node group called "PE Database Maintenance".
Then pin the node(s) running pe-postgresql to that node group.
It is not recommended to classify using a pre-existing node group in the PE Console.

## Items you may want to configure

### Backup Schedule

> WARNING: The backup functionality in this module has been deprecated and will be removed in a future release. 
Please refer to the [PE Backup and Restore documentation](https://puppet.com/docs/pe/latest/backing_up_and_restoring_pe.html) for details on how to backup.
You should ensure the parameter `pe_databases::manage_database_backups` and any parameters from the `pe_databases::backup` class are removed from classification or hiera.
You should also clean up associated crontab entries.

Backups are not activated by default but can be enabled by setting the following parameter:

Hiera classification example 

```
pe_databases::manage_database_backups:: true
```

You can modify the default backup schedule by provide an array of hashes that describes the databases to backup and their backup schedule.
Please refer to the [hieradata_examples](https://github.com/puppetlabs/puppetlabs-pe_databases/tree/main/hieradata_examples) directory of this repository for examples.

> IMPORTANT NOTE: If you change the default schedule, it will stop managing the associated crontab entries, and there's not a clean way to automatically remove unmanaged crontab entries.
So you should delete all pe-postgres crontab entries via `crontab -r -u pe-postgres` and let Puppet repopulate them if you change the default schedule.
Otherwise, you will create duplicate backups.

### Backup Retention Policy

By default, the backup script will retain two backups for each database.
When the backup script runs, it will remove the older of the two backups before starting the backup itself.
You can configure the retention policy by setting `pe_databases::backup::retention_policy: <NUMBER_OF_BACKUPS_TO_RETAIN>`.

### Disable Maintenance

The maintenance systemd timers  will perform a `pg_repack` on various `pe-puppetdb` tables to keep them lean and fast.
pg_repack is a non blocking operation and should have no impact on the operations of Puppet Enterprise, however, if for some reason you experience issues you can disable the maintenance systemd timers.
You can do so by setting `pe_databases::disable_maintenance: true` in your hieradata.


# General PostgreSQL Recommendations

## Tuning

Under normal operating conditions, there is very little tuning needed for PE PostgreSQL.

If you are using a Monolithic installation of Puppet Enterprise then the default settings are well-tuned.
If you are using a dedicated node for PE PostgreSQL, then some of the settings can be tuned upwards, but likely with little difference in performance.

This module attempts to provide default settings that accommodate both a Monolithic install and a dedicated PE PostgreSQL instance.
Those defaults change based on the `$all_in_one_pe` parameter.

## Backups

> WARNING: The backup functionality in this module has been deprecated and will be removed in a future release. 
Please refer to the [PE Backup and Restore documentation](https://puppet.com/docs/pe/latest/backing_up_and_restoring_pe.html) for details on how to backup.
You should ensure the parameter `pe_databases::manage_database_backups` and any parameters from the `pe_databases::backup` class are removed from classification or hiera.
You should also clean up associated crontab entries.

This is the documentation for Pupet Enterprise backups:

https://puppet.com/docs/pe/latest/backing_up_and_restoring_pe.html

This module provides an alternative to backup just the PE PostgreSQL databases.

It is recommended that you backup each database individually so that if you have an issue with one database you do not have to restore all databases.

Under ideal conditions you would backup all databases daily, however, backing up large databases such as `pe-puppetdb`, results in excessive disk I/O so you may prefer to backup `pe-puppetdb` weekly while backing up the rest of the smaller databases daily.

The choice to backup `pe-puppetdb` more frequently should be based on the business needs.

This module provides a script for backing up PE PostgreSQL databases and two default cron jobs: one weekly to back up the `pe-puppetdb` database, and one daily to backup every database except `pe-puppetdb`.

## Maintenance

This module provides systemd timers to pg_repack tables in the `pe-puppetdb` database:
 - facts tables are pg_repack'd  Tuesdays and Saturdays at 4:30AM
 - catalogs tables are pg_repack'd  Sundays and Thursdays at 4:30AM
 - reports table is pg_repack'd on the 10th of the month at 05:30AM on systems with PE 2019.7.0 or less
 - resource_events table is pg_repack'd on the 15th of the month at 05:30AM on systems with PE 2019.3.0 or less
 - other tables are pg_repack'd on the 20th of the month at 5:30AM

> Note: You may be able to improve the performance (reduce time to completion) of maintenance tasks by increasing the [maintenance_work_mem](#maintenance_work_mem) setting.


Please note that when using `pg_repack` as part of the pe_databases module, unclean exits can leave behind the schema when otherwise it should have been cleaned up. This can result in the messages similar to the following:

```
INFO: repacking table "public.fact_paths"
WARNING: the table "public.fact_paths" already has a trigger called "repack_trigger"
DETAIL: The trigger was probably installed during a previous attempt to run pg_repack on the table which was interrupted and for some reason failed to clean up the temporary objects. Please drop the trigger or drop and recreate the pg_repack extension altogether to remove all the temporary objects left over.
```

The module now contains a task `reset_pgrepack_schema` to mitigate this issue. This needs to be run against your Primary or PE-postgreSQL server to resolve this and it will drop and recreate the extension, removing the temporary objects.


## PostgreSQL Settings

### [maintenance_work_mem](https://www.postgresql.org/docs/11/runtime-config-resource.html)

You can improve the speed of vacuuming, reindexing, and backups by increasing this setting.
Consider a table that is 1GB.
If `maintenance_work_mem` is `256MB`, then to perform operations on the table a quarter of it will be read into memory, operated on, then written out to disk, and then that will repeat three more times.
If `maintenance_work_mem` is `1GB` then the entire table can be read into memory, operated on, then written out to disk.

Note: that each autovacuum worker can use up to this much memory, if you do not set [autovacuum_work_mem](https://www.postgresql.org/docs/11/runtime-config-resource.html) as well.

### [work_mem](https://www.postgresql.org/docs/11/runtime-config-resource.html)

Puppet Enterprise ships with a default `work_mem` of `4MB`.
For most installations, this is all that is needed, however, at a larger scale you may need to increase to `8MB` or `16MB`.
One way to know if you need more `work_mem` is to change the `log_temp_files` setting to 0 which will log all temporary files created by PostgreSQL.
When you see a lot of temporary files being logged over the `work_mem` threshold then it’s time to consider increasing `work_mem`, however, you should first run a `REINDEX` and `VACUUM ANALYZE` to see if that reduces the number of temporary files being logged.

Another way to determine the need for an increase in `work_mem` is to get the query plan from a slow running query (accomplished by adding `EXPLAIN ANALYZE` to the beginning of the query).
Query plans that have something like `Sort Method: external merge Disk` in them indicate a possible need for for more `work_mem`.

This is discussed on the [Tuning Your PostgreSQL Server Wiki](https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server#work_mem)

### [autovacuum_work_mem](https://www.postgresql.org/docs/11/runtime-config-resource.html)

This setting is essentially `maintenance_work_mem` but for autovacuum processes only.
Usually you will set `maintenance_work_mem` higher and this lower, since `autovacuum_work_mem` is used by `autovacuum_max_workers` number of autovacuum processes.

### [autovacuum_max_workers](https://www.postgresql.org/docs/11/runtime-config-autovacuum.html)

The larger your database the more autovacuum workers you may need.
The default of `3` is reasonable for most small or medium installations of Puppet Enterprise.
When you’re tracking the size of your database tables and indexes and you notice some of them seem to keep getting larger then you might need more autovacuum workers.

If you’ve installed PE PostgreSQL on its own node, then we recommend `CPU / 2` as a default for this setting (with a maximum of 8).
For a Monolithic installation, increasing this setting means you likely need to compensate by reducing other settings that may cause your CPU to be over-subscribed during a peak.
Those settings would be PuppetDB Command Processing Threads and Puppet Server JRuby Instances.

### [checkpoint_segments and checkpoint_completion_target](https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server#checkpoint_segments_checkpoint_completion_target)

We suggest a middle ground of `128` for `checkpoint_segments` and `.9` for `checkpoint_completion_target`.
As mentioned in the PostgreSQL Wiki, the larger value you use for `checkpoint_segments` affords you better performance but you sacrifice in potential recovery time.

If you see messages like “LOG:  checkpoints are occurring too frequently (xx seconds apart)” then you definitely want to increase your `checkpoint_segments`.

## How to Report an issue or contribute to the module

If you are a PE user and need support using this module or are encountering issues, our Support team would be happy to help you resolve your issue and help reproduce any bugs. Just raise a ticket on the [support portal](https://support.puppet.com/hc/en-us/requests/new).
If you have a reproducible bug or are a community user you can raise it directly on the Github issues page of the module [puppetlabs/puppetlabs-pe_databases](https://github.com/puppetlabs/puppetlabs-pe_databases/issues). We also welcome PR contributions to improve the module. Please see further details about contributing [here](https://puppet.com/docs/puppet/7.5/contributing.html#contributing_changes_to_module_repositories)
