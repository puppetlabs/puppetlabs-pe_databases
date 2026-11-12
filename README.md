Table of Contents
=================

- [Table of Contents](#table-of-contents)
- [Overview](#overview)
  - [What does this module provide?](#what-does-this-module-provide)
  - [Usage](#usage)
  - [Items you may want to configure](#items-you-may-want-to-configure)
    - [Maintenance](#maintenance)
      - [Repack jobs](#repack-jobs)
      - [Runtime limit and stopped jobs](#runtime-limit-and-stopped-jobs)
      - [Lock handling](#lock-handling)
      - [Tables repacked by default](#tables-repacked-by-default)
      - [Cleanup before and after each job](#cleanup-before-and-after-each-job)
      - [Stopping a repack and resetting the pg_repack schema](#stopping-a-repack-and-resetting-the-pg_repack-schema)
      - [GIN index bloat on the factsets table](#gin-index-bloat-on-the-factsets-table)
      - [Upgrading](#upgrading)
      - [Disable Maintenance](#disable-maintenance)
  - [Deprecated functionality](#deprecated-functionality)
    - [Backups](#backups)
    - [PE PostgreSQL Tuning](#pe-postgresql-tuning)
- [Supporting Content](#supporting-content)
    - [Articles](#articles)
    - [Videos](#videos)
  - [How to Report an issue or contribute to the module](#how-to-report-an-issue-or-contribute-to-the-module)

# Overview

## What does this module provide?

This module provides maintenance tasks to keep the `pe-puppetdb` database lean and fast

## Usage

This module is bundled with all currently support versions of Puppet Enterprise, and enabled by default. When with Puppet Enterprise, see the following documentation for instructions on how to enable or disable.

https://puppet.com/docs/pe/latest/pe_database_maintenance.html#enable_pe_database_module


## Items you may want to configure


### Maintenance

This module provides systemd timers to pg_repack tables in the `pe-puppetdb` database. These times are configurable using the corresponding parameters, but default to:

 - facts tables are pg_repack'd  Tuesdays and Saturdays at 4:30AM
 - catalogs tables are pg_repack'd  Sundays and Thursdays at 4:30AM
 - reports table is pg_repack'd on the 10th of the month at 05:30AM on systems with PE 2019.7.0 or less
 - resource_events table is pg_repack'd on the 15th of the month at 05:30AM on systems with PE 2019.3.0 or less
 - other tables are pg_repack'd on the 20th of the month at 5:30AM

Classify the following parameters to change the values:
```
$facts_tables_repack_timer           = 'Tue,Sat *-*-* 04:30:00',
$catalogs_tables_repack_timer        = 'Sun,Thu *-*-* 04:30:00',
$other_tables_repack_timer           = '*-*-20 05:30:00',
$reports_tables_repack_timer         = '*-*-10 05:30:00',
$resource_events_tables_repack_timer = '*-*-15 05:30:00',
```


Please note that when using `pg_repack` as part of the pe_databases module, unclean exits can leave behind the schema when otherwise it should have been cleaned up. This can result in the messages similar to the following:

```
INFO: repacking table "public.fact_paths"
WARNING: the table "public.fact_paths" already has a trigger called "repack_trigger"
DETAIL: The trigger was probably installed during a previous attempt to run pg_repack on the table which was interrupted and for some reason failed to clean up the temporary objects. Please drop the trigger or drop and recreate the pg_repack extension altogether to remove all the temporary objects left over.
```

See Stopping a repack and resetting the pg_repack schema below for how to remove the leftovers.

#### Repack jobs

The module creates one systemd service and timer for each repack job: `facts`, `catalogs` and `other` (in the `pe-puppetdb` database) and `activity` (in the `pe-activity` database). The units are named `pe_databases-<job>.service` and `pe_databases-<job>.timer`.

Each job can be turned off on its own with a Boolean parameter of `pe_databases::pg_repack` (default `true`):

```
pe_databases::pg_repack::facts_tables_repack_enabled: true
pe_databases::pg_repack::catalogs_tables_repack_enabled: true
pe_databases::pg_repack::other_tables_repack_enabled: true
pe_databases::pg_repack::activity_tables_repack_enabled: true
```

Setting a flag to `false` removes the unit files of that job and stops and disables its timer. If a run of that job is in progress, systemd ends it with `SIGTERM` within about 90 seconds after the Puppet run that turns the job off (at once if the run is already older), because the running unit no longer has a unit definition. The `SIGTERM` reaches the whole job, including pg_repack, so pg_repack cannot remove its own objects; the wrapper's cleanup then removes any leftovers and the unit ends as failed. To let pg_repack stop and clean up after itself, stop the job first (`systemctl stop pe_databases-<job>.timer pe_databases-<job>.service`) and turn it off afterwards, as in the manual procedure below.

#### Runtime limit and stopped jobs

Each service runs `repack_run.sh <cleanup command> -- <pg_repack command>` (in the module's scripts directory). The wrapper starts pg_repack. When it receives `SIGTERM` (or `SIGINT`) it stops pg_repack with `SIGINT`, which lets pg_repack remove its own objects. After pg_repack has ended for any reason, the wrapper runs the cleanup command once and exits with the exit status of pg_repack, so a stopped or timed-out job still shows as a failed unit.

`max_runtime` and `stop_timeout` must be systemd time spans such as `12h`, `10min` or `1min 30s`. A bare number means seconds. In Hiera, quote a bare number (for example `'0'` or `'600'`), because YAML reads an unquoted number as an integer, which these parameters do not accept. A value that is not made of numbers with systemd time units fails the compilation of the catalog. A value of `0` means no limit, which also removes the protection against a run that never ends.

Each service is limited by `pe_databases::pg_repack::max_runtime` (default `12h`). The value is a systemd time span and is rendered as `TimeoutStartSec` in the service. When the limit is reached, or when the service is stopped, systemd sends `SIGTERM` to the wrapper, which stops pg_repack as described above. The unit sets `KillSignal=SIGTERM` and `KillMode=mixed`. This stop path applies to a job that still has its unit files. For a job that is turned off while it runs, see the behavior described under Repack jobs above.

`pe_databases::pg_repack::stop_timeout` (default `10min`) is rendered as `TimeoutStopSec`. It is the longest time systemd waits for a stopping job, which covers the abort of pg_repack (it can wait up to twice the lock wait timeout) plus the cleanup. After that time systemd kills the job.

A run that is stopped or that reaches `max_runtime` ends as a failed unit. To see it:

```
systemctl --failed
journalctl -u pe_databases-<job>.service
```

On RHEL 7 (systemd 219), `journalctl -u pe_databases-<job>.service` can miss the last lines written by the cleanup and the wrapper. They are shown by `journalctl -t repack_cleanup.sh` and `journalctl -t repack_run.sh`.

`max_runtime` must be shorter than the smallest gap between two scheduled runs of the same job. With the default activity schedule (Wednesday and Friday) the smallest gap is 2 days. If `max_runtime` is longer than the gap, the timer starts the job again shortly after it was stopped.

Limits of the stop:

 - A stop request that reaches the wrapper in the first moments after the job starts may not reach pg_repack. The cleanup before the next run removes any leftovers.
 - If pg_repack ignores the stop and systemd kills the job when `stop_timeout` is reached, leftovers can remain until the cleanup before the next run. Systemd versions that run the after-run cleanup following a forced kill also remove them then.
 - A repack wrapper started outside systemd with `SIGINT` already ignored (for example as a background job of a non-interactive shell) cannot stop pg_repack.

#### Lock handling

pg_repack needs a short exclusive lock on each table. Two parameters of `pe_databases::pg_repack` control what happens when another session holds a conflicting lock:

 - `wait_timeout` is a number of seconds, passed to pg_repack as `-T`. After that many seconds pg_repack cancels the conflicting sessions, and after twice that many seconds it terminates them (when `kill_backend` is `true`). When it is not set, the pg_repack default applies.
 - `kill_backend` (default `true`) allows pg_repack to cancel and terminate the conflicting sessions. When it is `false`, pg_repack is run with `--no-kill-backend` and a job skips a table it cannot lock. The job still exits 0, so the skip is visible only in the log of the job (`journalctl -u pe_databases-<job>.service`).

#### Tables repacked by default

The default `pe_databases::pg_repack::fact_tables` contains only `fact_paths`. The `factsets` table is not repacked by default. To repack `factsets` as well, set the list in your hieradata:

```
pe_databases::pg_repack::fact_tables:
  - fact_paths
  - factsets
```

Do not set a table list to `[]` to turn a job off. An empty list repacks every table in the database. Use the per-job flag (for example `pe_databases::pg_repack::facts_tables_repack_enabled: false`) instead.

#### Cleanup before and after each job

Each service runs the cleanup step before pg_repack starts (`ExecStartPre`). The wrapper runs it again after pg_repack has ended, including after a stop or a timeout. The cleanup also runs in `ExecStopPost` after every run. On systemd versions that do not run `ExecStopPost` after a failed or timed-out start, the cleanup run by the wrapper covers that case.

The step removes what an interrupted pg_repack run leaves behind: the `repack_trigger` on a table and the objects in the `repack` schema. It does this by dropping and recreating the pg_repack extension, and acts only when a table of the database carries a `repack_trigger`. A pg_repack session on one of the job's tables is ended first. If a pg_repack session holds locks on a table outside the job, the step skips (see below). A table with a `repack_trigger` that no pg_repack session touches is orphaned and is cleaned whether or not it belongs to the job. With no leftovers the step changes nothing.

The cleanup skips (exit code 2, nothing is changed) when another repack job of the same database is running, which it detects through the other units of that database, or when a pg_repack session holds locks on a table outside the job (for example a repack started by hand). It exits with code 3 when it cannot lock the affected tables within 5 seconds, and with code 1 on an error. A failure or skip of the cleanup appears in the journal of the service (`journalctl -u pe_databases-<job>.service`, see the note on RHEL 7 above) and does not fail the unit.

The cleanup connects with a 10 second timeout and limits each statement to 60 seconds, so that an unresponsive database cannot hold a job back.

#### Stopping a repack and resetting the pg_repack schema

An interrupted pg_repack run can leave messages such as the following in later runs:

```
INFO: repacking table "public.fact_paths"
WARNING: the table "public.fact_paths" already has a trigger called "repack_trigger"
```

The cleanup step usually removes these leftovers. The task `reset_pgrepack_schema` does the same on demand, and always drops and recreates the pg_repack extension. Use the following procedure to stop a repack and reset the schema by hand:

1. Stop the timer and the service of the job so that nothing starts it again: `systemctl stop pe_databases-<job>.timer pe_databases-<job>.service`.
2. Set the per-job flag `pe_databases::pg_repack::<job>_tables_repack_enabled: false` (with `<job>` one of `facts`, `catalogs`, `other`, `activity`) or `pe_databases::disable_maintenance: true`, and run the Puppet agent. Turning a job off removes its unit files, and without the flag Puppet restores a stopped timer on its next run.
3. Run the task against the primary or the PE-PostgreSQL node: `puppet task run pe_databases::reset_pgrepack_schema --nodes <FQDN of the primary or the PE-PostgreSQL node>`. For the activity database add `database=pe-activity`. The `database` parameter accepts only `pe-puppetdb` (the default) or `pe-activity`.
4. When the work is done, turn the job on again by setting its flag back to `true` (or `pe_databases::disable_maintenance` back to `false`) and run the Puppet agent. Puppet restores the unit files and the timer.

The task refuses to run while a repack service for that database is running. It ends leftover pg_repack sessions, locks only the tables that carry the `repack_trigger` (with a 5 second lock timeout) and always drops and recreates the pg_repack extension.

#### GIN index bloat on the factsets table

The GIN index `idx_factsets_jsonb_merged` on the `factsets` table can grow large. Rebuild it off-peak by running the following statement with `psql` as the `pe-postgres` user against the `pe-puppetdb` database:

```
REINDEX INDEX CONCURRENTLY public.idx_factsets_jsonb_merged;
```

`REINDEX INDEX CONCURRENTLY` needs PostgreSQL 12 or later. To reduce the size of the index, remove frequently changing facts from what PuppetDB stores with a fact blocklist (`puppet_enterprise::puppetdb::database_ini::facts_blocklist`). Blocklisted facts no longer appear in PuppetDB queries or in fact-based node group rules.

#### Upgrading

Before you upgrade the module, check whether a repack job is running:

```
systemctl list-units --no-legend --state=activating,deactivating 'pe_databases-*.service'
```

No output means that no job is running (a running job is in the `activating` state, and in the `deactivating` state while it stops). If a job is running, stop it (`systemctl stop pe_databases-<job>.service`) and wait until it has ended before you upgrade. After the upgrade, run the `pe_databases::reset_pgrepack_schema` task (add `database=pe-activity` for the activity job) to remove what the stopped job left behind. The cleanup that runs before each repack job removes such leftovers as well.


#### Disable Maintenance

The maintenance systemd timers  will perform a `pg_repack` on various `pe-puppetdb` tables to keep them lean and fast.
pg_repack is a non blocking operation and should have no impact on the operations of Puppet Enterprise, however, if for some reason you experience issues you can disable the maintenance systemd timers.
You can do so by setting `pe_databases::disable_maintenance: true` in your hieradata.
To turn off a single job, set its flag (`pe_databases::pg_repack::facts_tables_repack_enabled`, `catalogs_tables_repack_enabled`, `other_tables_repack_enabled` or `activity_tables_repack_enabled`) to `false`. For what happens to a run that is in progress when a job is turned off, see Repack jobs above.




## Deprecated functionality


### Backups 
> WARNING: The backup functionality in this module has been removed. 
Please refer to the [PE Backup and Restore documentation](https://puppet.com/docs/pe/latest/backing_up_and_restoring_pe.html) for details on how to backup.
You should ensure the parameter `pe_databases::manage_database_backups` and any parameters from the `pe_databases::backup` class are removed from classification or hiera.
You should also clean up associated crontab entries.

### PE PostgreSQL Tuning

Recent versions of PE PostgreSQL included in all supported versions of Puppet Enterprise have superseded or improved upon the parameters previously tuned by this module, as such they are no longer required.
Any classifications of the parameters relating to this functionality should be removed, however if set will harmlessly omit a warning of this deprecation.

---

# Supporting Content

### Articles

The [Support Knowledge base](https://support.puppet.com/hc/en-us) is a searchable repository for technical information and how-to guides for all Puppet products.

This Module has the following specific Article(s) available:

1. [The "puppetlabs-pe_databases" module causes a “/Stage[main]/Pe_databases” error message on the PE-PostgreSQL node when upgrading to the latest version of Puppet Enterprise ](https://support.puppet.com/hc/en-us/articles/7174830720151)
2. [Keep PE PostgreSQL database size maintained with the puppetlabs-pe_databases module for Puppet Enterprise](https://support.puppet.com/hc/en-us/articles/231234927)
3. [Recommended reading - Prevent an eventual PuppetDB slowdown - Preventative maintenance for PuppetDB: node-purge-ttl](https://support.puppet.com/hc/en-us/articles/115004896948)

### Videos

The [Support Video Playlist](https://youtube.com/playlist?list=PLV86BgbREluWKzzvVulR74HZzMl6SCh3S) is a resource of content generated by the support team

## How to Report an issue or contribute to the module

If you are a PE user and need support using this module or are encountering issues, our Support team would be happy to help you resolve your issue and help reproduce any bugs. Just raise a ticket on the [support portal](https://support.puppet.com/hc/en-us/requests/new).
If you have a reproducible bug or are a community user you can raise it directly on the Github issues page of the module [puppetlabs/puppetlabs-pe_databases](https://github.com/puppetlabs/puppetlabs-pe_databases/issues). We also welcome PR contributions to improve the module. Please see further details about contributing [here](https://puppet.com/docs/puppet/7.5/contributing.html#contributing_changes_to_module_repositories)

   
   ---


