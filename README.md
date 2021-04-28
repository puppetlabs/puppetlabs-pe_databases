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
    - [Vacuuming](#vacuuming)
    - [Reindexing](#reindexing)
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

By default you get the following:

1.  Customized settings for PE PostgreSQL
1.  Maintenance to keep the `pe-puppetdb` database lean and fast
1.  Backups for all PE PostgreSQL databases
  - The `pe-puppetdb` database is backed up every week
  - Other databases are backed up every night

## Usage

In order to use this module, classify the node running PE PostgreSQL with the `pe_databases` class.
That node is the Primary Master in a Monolithic installation, or the PE PuppetDB host in a Split install.  

To classify via the PE Console, create a new node group called "PE Database Maintenance".
Then pin the node running pe-postgresql to that node group.
It is not recommended to classify using a pre-existing node group in the PE Console.

## Items you may want to configure

### Backup Schedule

You can modify the default backup schedule by provide an array of hashes that describes the databases to backup and their backup schedule.
Please refer to the [hieradata_examples](https://github.com/puppetlabs/puppetlabs-pe_databases/tree/master/hieradata_examples) directory of this repository for examples.

> IMPORTANT NOTE: If you change the default schedule, it will stop managing the associated crontab entries, and there's not a clean way to automatically remove unmanaged crontab entries.
So you should delete all pe-postgres crontab entries via `crontab -r -u pe-postgres` and let Puppet repopulate them if you change the default schedule.
Otherwise, you will create duplicate backups.

### Backup Retention Policy

By default, the backup script will retain two backups for each database.
When the backup script runs, it will remove the older of the two backups before starting the backup itself.
You can configure the retention policy by setting `pe_databases::backup::retention_policy: <NUMBER_OF_BACKUPS_TO_RETAIN>`.

### Disable Maintenance

The maintenance cron jobs will perform a `VACUUM FULL` on various `pe-puppetdb` tables to keep them lean and fast.
A `VACUUM FULL` is a blocking operation and you will see the PuppetDB command queue grow while the cron jobs run.
The blocking should be short lived and the PuppetDB command queue should work itself down after, however, if for some reason you experience issues you can disable the maintenance cron jobs.
You can do so by setting `pe_databases::maintenance::disable_maintenance: true` in your hieradata.

With PE 2018.1.7 and 2019.0.2 and newer, this module uses `pg_repack` which does not block.

# General PostgreSQL Recommendations

## Tuning

Under normal operating conditions, there is very little tuning needed for PE PostgreSQL.

If you are using a Monolithic installation of Puppet Enterprise then the default settings are well-tuned.
If you are using a dedicated node for PE PostgreSQL, then some of the settings can be tuned upwards, but likely with little difference in performance.

This module attempts to provide default settings that accommodate both a Monolithic install and a dedicated PE PostgreSQL instance.
Those defaults change based on the `$all_in_one_pe` parameter.

## Backups

This is the documentation for Pupet Enterprise backups:

https://puppet.com/docs/pe/latest/backing_up_and_restoring_pe.html

This module provides an alternative to backup just the PE PostgreSQL databases.

It is recommended that you backup each database individually so that if you have an issue with one database you do not have to restore all databases.

Under ideal conditions you would backup all databases daily, however, backing up large databases such as `pe-puppetdb`, results in excessive disk I/O so you may prefer to backup `pe-puppetdb` weekly while backing up the rest of the smaller databases daily.

The choice to backup `pe-puppetdb` more frequently should be based on the business needs.

This module provides a script for backing up PE PostgreSQL databases and two default cron jobs: one weekly to back up the `pe-puppetdb` database, and one daily to backup every database except `pe-puppetdb`.

## Maintenance

This module provides cron jobs to VACUUM FULL tables in the `pe-puppetdb` database:
 - facts tables are VACUUMed Tuesdays and Saturdays at 4:30AM
 - catalogs tables are VACUUMed Sundays and Thursdays at 4:30AM
 - other tables are VACUUMed on the 20th of the month at 5:30AM

> Note: You may be able to improve the performance (reduce time to completion) of maintenance tasks by increasing the [maintenance_work_mem](#maintenance_work_mem) setting.

With PE 2018.1.7 and 2019.0.2 and newer, this module uses `pg_repack` instead of `VACUUM FULL`.

### Vacuuming

Generally speaking, PostgreSQL keeps itself in good shape with a process called [auto vacuuming](https://www.postgresql.org/docs/11/runtime-config-autovacuum.html).
This is enabled by default and tuned for Puppet Enterprise out of the box.

Note that there is a difference between `VACUUM` and `VACUUM FULL`.
`VACUUM FULL` rewrites a table on disk while `VACUUM` simply marks deleted row so the space that row occupied can be used for new data.

`VACUUM FULL` is generally not necessary, and if run too-frequently can cause excessive disk I/O.
However, in the case of `pe-puppetdb` the way it constantly receives and updates data causes bloat, and it is beneficial to VACUUM FULL the `facts` and `catalogs` tables every few days.
We, however, do not recommend a `VACUUM FULL` on the `reports` or `resource_events` tables as they are large and `VACUUM FULL` may cause extended downtime.

### Reindexing

Reindexing is also a prudent exercise.
It may not be necessary very often, but doing every month or so can definitely prevent performance issues in the long run.
In the scope of what this module provides, a `VACUUM FULL` will rewrite the table and all of its indexes so tables are reindexed during the `VACUUM FULL` maintenance cron jobs.
That only leaves the `reports` and `resource_events` tables to be reindexed.
Unfortunately, the most common place to get a `DEADLOCK` error mentioned below is when reindexing the `reports` table.

Reindexing is a blocking operation.
While an index is rebuilt, the data in the table cannot change and other operations have to wait for the rebuild to complete.
If you don’t have a large installation or you have a lot of memory or fast storage, you may be able to complete a reindex while your Puppet Enterprise installation is up.
PuppetDB will backup commands in its command queue and the PE Console may throw errors about not being able to load data.
After the reindex is complete, the PuppetDB command queue will be processed and the PE Console will work as expected.

In some cases, you cannot complete a reindex while the Puppet Enterprise services are trying to use the database.
You may receive a `DEADLOCK` error because the table that is supposed to be reindexed has too many requests on it and the reindex command cannot complete.
In these cases you need to stop the Puppet Enterprise services, run the reindex, and then start the Puppet Enterprise services again.
If you are getting a `DEADLOCK` error you can reduce the frequency of reindexing, the most important times to reindex are when you add new nodes, so reindexing is more important early in your PE installation when you are adding new nodes but less important to do frequently when you are in a steady state.

With PE 2018.1.7 and 2019.0.2 and newer, this module uses `pg_repack` instead of `VACUUM FULL`.

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
