Table of Contents
=================

- [Table of Contents](#table-of-contents)
- [Overview](#overview)
  - [What does this module provide?](#what-does-this-module-provide)
  - [Usage](#usage)
  - [Items you may want to configure](#items-you-may-want-to-configure)
    - [Maintenance](#maintenance)
      - [Disable Maintenance](#disable-maintenance)
  - [Deprecated functionality](#deprecated-functionality)
    - [Backups](#backups)
    - [PE PostgreSQL Tuning](#pe-postgresql-tuning)
- [Supporting Content](#supporting-content)
    - [Articles](#articles)
    - [Videos](#videos)
  - [How to Report an issue or contribute to the module](#how-to-report-an-issue-or-contribute-to-the-module)

# Overview

This module maintenance jobs for PE PostgreSQL.

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

The module now contains a task `reset_pgrepack_schema` to mitigate this issue. This needs to be run against your Primary or PE-postgreSQL server to resolve this and it will drop and recreate the extension, removing the temporary objects.


#### Disable Maintenance

The maintenance systemd timers  will perform a `pg_repack` on various `pe-puppetdb` tables to keep them lean and fast.
pg_repack is a non blocking operation and should have no impact on the operations of Puppet Enterprise, however, if for some reason you experience issues you can disable the maintenance systemd timers.
You can do so by setting `pe_databases::disable_maintenance: true` in your hieradata.




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


