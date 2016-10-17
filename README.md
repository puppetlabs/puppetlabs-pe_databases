Table of Contents
=================

* [Overview](#overview)
  * [What does this module provide?](#what-does-this-module-provide)
  * [Items you may want to configure](#items-you-may-want-to-configure)
    * [Backup schedule](#backup-schedule)
    * [Disable the maintenance cron job](#disable-the-maintenance-cron-job)
* [General PostgreSQL Recommendations](#general-postgresql-recommendations)
  * [Tuning](#tuning)
  * [Backups](#backups)
  * [Maintenance](#maintenance)
    * [Vacuuming](#vacuuming)
    * [Reindexing](#reindexing)
  * [PostgreSQL Settings](#postgresql-settings)
    * [maintenance_work_mem](#maintenance_work_mem)
    * [work_mem](#work_mem)
    * [autovacuum_work_mem](#autovacuum_work_mem)
    * [autovacuum_max_workers](#autovacuum_max_workers)
    * [checkpoint_segments and checkpoint_completion_target](#checkpoint_segments-and-checkpoint_completion_target)

# Overview

This module is meant to provide the basic tuning, maintenance, and backups you need for your PE PostgreSQL instance.

## What does this module provide?

By default you get the following:

1.  Backups for all of your databases
  - PuppetDB is backed up once a week
  - The other PE databases are backed up every night
  - The node_check_ins table is TRUNCATED from the pe-classifier database to keep the size down
2.  A weekly reindex and vacuum analyze run on all databases
3.  Slightly better default settings for PE PostgreSQL

## Items you may want to configure

### Backup schedule

You can modify the default backup schedule by provide an array of hashes that describes the databases and the schedule to back them up on.  Please refer to the [hieradata_examples](./hieradata_examples) directory of this repo to see examples

NOTE: If you change the default schedule you'll likely stop managing a crontab entry and there's not a clean way to remove unmanaged crontab entries.  So you may want to simply delete the pe-postgres crontab entry and let puppet repopulate it.  `crontab -r -u pe-postgres`

### Disable the maintenance cron job

If you run into your maintenance cron job having DEADLOCK errors as described in the [reindexing section](#reindexing) you may want to disable it.  You can do so by setting `pe_databases::maintenance::disable_maintenace: true` in your hieradata.

# General PostgreSQL Recommendations

## Tuning

Under normal operating conditions there is very little that needs to be changed with the PostgreSQL instance that comes with Puppet Enterprise.

If you are using a monolithic installation of Puppet Enterprise then the default settings are likely well tuned.  Puppet Enterprise is tuned assuming all of the PE components are on the same box.  If you are using a dedicated node for PostgreSQL or even a split installation of PE then some of the settings can be tuned upwards but likely with little difference in performance.

This module attempts to provide default settings that accommodate both a monolithic install and a dedicated PostgreSQL instance.  The defaults change based on the $all_in_one_pe parameter.

## Backups

You can read the PE documentation on backups here:

https://docs.puppet.com/pe/latest/maintain_console-db.html#individual-database-backup

It is recommended that you backup each database individually so that if you have an issue with one database you do not have to roll back the data in all of your databases.

Under ideal conditions you’d backup your databases daily, however, backing up large databases such as PuppetDB, takes a lot of I/O so you may prefer to backup PuppetDB once a week while backing up the rest of the smaller databases on a daily basis.

The choice to backup PuppetDB more frequently should be based on the business needs during a time of an incident that would require losing information in PuppetDB.

This module provides a script for backing up the Puppet Enterprise databases and 2 default cron jobs.  A cron job to backup every database except PuppetDB every day and then a weekly cron job for backing up just the PuppetDB database.

## Maintenance

Note: You may be able to improve the performance ( reduce time to completion ) of maintenance tasks by increasing the [maintenance_work_mem](#maintenance_work_mem) setting.

This module provides a monthly cron job that performs a reindex and then a VACUUM ANALYZE.  This cron job should be monitored to make sure the reindex is not failing on a DEADLOCK error as discussed in the [reindexing](#reindexing) section.

### Vacuuming

Generally speaking PostgreSQL keeps itself in good shape with a process called [auto vacuuming](https://www.postgresql.org/docs/9.4/static/runtime-config-autovacuum.html).  This is on by default and tuned for Puppet Enterprise out of the box.

There are a few things that autovacuum does not touch though and it is prudent to run an infrequent VACUUM ANALYZE to prevent any issues that could manifest.

Please note that you should never need to run VACUUM FULL.  VACUUM FULL rewrites the entire database and is a blocking operation that will take down your Puppet Enterprise installation while it runs.  It is rarely necessary and causes a lot of I/O and downtime for Puppet Enterprise.  If you think you need to run VACUUM FULL then be prepared to have your Puppet Enterprise installation down for a while.

### Reindexing

Reindexing is also a prudent exercise.  It may not be necessary very often but doing every month or so can definitely prevent performance issues in the long run.

Reindexing is a blocking operation.  While an index is rebuilt the data in the table cannot change and operations have to wait for the index rebuild to complete.  If you don’t have a large installation or you have a lot of memory / a fast disk you may be able to complete a reindex while your Puppet Enterprise installation is up.  PuppetDB will backup commands in its command queue and the console may throw some errors about not being able to load data.  After the reindex is complete the PuppetDB command queue will work through and the console UI will work as expected.

In some cases, you cannot complete a reindex while the Puppet Enterprise services are trying to use the database.  You may receive a DEADLOCK error because the table that is supposed to be reindexed has too many requests on it and the reindex command cannot complete.  In these cases you need to stop the Puppet Enterprise services, run the reindex, and then start the Puppet Enterprise services again.  If you are getting a DEADLOCK error you can reduce the frequency of reindexing, the most important times to reindex are when you add new nodes, so reindexing is more important early in your PE installation when you are adding new nodes but less important to do frequently when you are in a steady state.

## PostgreSQL Settings

### [maintenance_work_mem](https://www.postgresql.org/docs/9.4/static/runtime-config-resource.html#GUC-MAINTENANCE-WORK-MEM)

You can improve the speed of vacuuming, reindexing, and backups by increasing this setting.  Consider a table that is 1GB if you have a maintenance_work_mem of 256MB then to perform operations on the table a quarter of it will be read into memory, operated on, then written out to disk, and then that will happen 3 more times.  If the maintenance_work_mem is 1GB then the table can be read into memory, operated on, and written back out.

Note: that each autovacuum worker can use up to this much memory if you do not set [autovacuum_work_mem]() as well.

### [work_mem](https://www.postgresql.org/docs/9.4/static/runtime-config-resource.html#GUC-WORK-MEM)

Puppet Enterprise ships with a default work_mem of 4MB.  For most installations this is all that is needed, however, at a larger scale you may need to increase to 8MB or 16MB.  One way to know if you need more work_mem is to change the log_temp_files setting to 0 which will log all temporary files created by PostgreSQL.  When you see a lot of temporary files being logged over the work_mem threshold then it’s time to consider increasing the work_mem, however, I would run a REINDEX and VACUUM ANALYZE to see if that reduces the number of temporary files being logged.

Another way to determine the need for an increase in work_mem is to get the query plan from a slow running query ( accomplished by adding EXPLAIN ANALYZE to the beginning of the query).  Query plans that have something like `Sort Method: external merge Disk` in them indicate a possible need for for more work_mem.

This is also discussed on the [Tuning Your PostgreSQL Server Wiki](https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server#work_mem)

### [autovacuum_work_mem](https://www.postgresql.org/docs/9.4/static/runtime-config-resource.html#GUC-AUTOVACUUM-WORK-MEM)

This setting is essentially maintenance_work_mem but for autovacuum processes only.  Usually you will set maintenance_work_mem higher and this lower since autovacuum_work_mem is used by autovacuum_max_workers number of autovacuum processes.

### [autovacuum_max_workers](https://www.postgresql.org/docs/9.4/static/runtime-config-autovacuum.html#GUC-AUTOVACUUM-MAX-WORKERS)

The larger your database the more autovacuum workers you may need.  The default is 3 is good for most small/medium installations of Puppet Enterprise.  When you’re tracking the size of your database tables / indexes and you notice some of them seem to keep getting bigger then you might need more autovacuum workers.

If you’ve placed PostgreSQL on its own node then I recommend CPUs / 2 as a default for this setting ( maximum of 8).  If you have PostgreSQL on the same node as all your other components then increasing this setting means you likely need to compensate by reducing other settings that may cause your CPU to be over-subscribed during a peak.  Examples would be PuppetDB command processing threads or puppet server JRuby instances.

### [checkpoint_segments and checkpoint_completion_target](https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server#checkpoint_segments_checkpoint_completion_target)

I suggest a middle ground of 128 for checkpoint_segements and .9 for checkpoint_completion_target.  As mentioned in the wiki, the larger value you use for checkpoint_segments affords you better performance but you sacrifice in potential recovery time.

If you see messages like “LOG:  checkpoints are occurring too frequently (xx
seconds apart)” then you definitely want to increase your checkpoint_segments.
