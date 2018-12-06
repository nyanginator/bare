BAckup and REstore Script for Websites
======================================
https://github.com/nyanginator/bare

This is a Bash script for backing up and restoring website directories and/or their databases using `rsync` and `mysql`. Backups are tarred and gzipped to reduce space.

Table of Contents
=================
* [Purpose](#purpose)
* [Setup](#setup)
  * [Config File](#config-file)
  * [Site Data Files](#site-data-files)
  * [Database Login Credentials](#database-login-credentials)
* [Usage](#usage)
  * [Backup](#backup)
  * [Restore](#restore)
  * [Cron](#cron)
  * [Errors](#errors)
* [Contact](#contact)

Purpose
=======
I wanted more control over my backups, instead of using my webhost's backup options.

Setup
=====
Make sure all files and directories of `bare` are in the same folder.

Config File
-----------
Start by filling in variables for config file:
* `BKUPDESTPATH` - Specify the directory where you want backups saved.
* `DAILYRANGE`   - Backups are considered "old" if they are older than this number of days.
* `DATEHOURADJ`  - Timezone hour adjustment for timestamps.
* `DUMPCMDPATH`  - Path to MySQL dump command.
* `MYSQLCMDPATH` - Path to MySQL command.

Site Data Files
---------------
Directories to backup should be specified with an absolute path (e.g. `/var/www/html/webdirectory`), one-per-line, in a file named `webdirectory_directories`. This file should be placed in the `sitedata` folder. If you want to exclude any files/directories, then specify them each with a line beginning with `EXCLUDE=`.

Databases to backup should be specified by name, one-per-line, in a file name `webdirectory_databases`. This file should be placed in the `sitedata` folder as well.

Database Login Credentials
--------------------------
The usernames and passwords for database logins should be stored in `~/.my.cnf`, which should have 600 permissions. Specify each database's login information as follows:

```
[clientdatabasename1] # The literal word "client" + DB name
user=myuser
password=mypassword
host=localhost
      
[clientdatabasename2]
user=myuser
password=mypassword
host=localhost

...
(etc.)
```
Usage
=====

Backup
------
Normal backup:
```
$ ./bare.sh backup webdirectory
```
The backup will be saved in a directory according to the date, time, and webdirectory name (i.e. `2018-07-15/webdirectory/2018.07.15.0842`). A `.log` file will also be created in the same directory.

Backup and delete all "old" backups:
```
$ ./bare.sh backup webdirectory nokeep
```
Remember, "old" backups are defined by the `DAILYRANGE` variable in the `config` file.

Restore
-------
To restore the backup from July 15, 2018 8:42am.
```
$ ./bare.sh restore webdirectory 2018.07.15.0842
```
Make sure the backup directory (i.e. `2018-07-15/webdirectory/2018.07.15.0842`) exists in the `BKUPDESTPATH` you set. You may also want to first delete all files and tables in the folders and databases you are restoring to, since any new files/tables will not be deleted by the script.

Cron
----
You can set backups to run automatically everyday using cron. For example, to run a daily backup at 12:30am everyday and keep only the most recent days (as defined by `DAILYRANGE`), use the cron command:
```
30  0  *  *  *  /path/to/bare.sh backup webdirectory nokeep > /dev/null 2>&1
```

Errors
------
If there are any errors, the `.log` file will be prefixed with `BARE-ERRORS_`. It will appear in the backup script directory.

Contact
=======
Nicholas Yang\
http://nyanginator.wixsite.com/home
