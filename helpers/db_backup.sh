#!/bin/bash

if [ $# == 5 ]; then

  SITENAME=$1
  THEDB=$2
  LABEL=$3
  BKUPPATH=$4
  DUMPCMDPATH=$5

  mkdir -p $BKUPPATH
  if time -p $DUMPCMDPATH --defaults-group-suffix=$THEDB $THEDB | gzip > $BKUPPATH/${LABEL}-${THEDB}.sql.gz; then
    echo "mysqldump COMPLETE ($?) for database: $THEDB of site: $SITENAME"
  else
    echo "mysqldump ERRORS encountered ($?) for database: $THEDB of site: $SITENAME"
  fi
  echo ""

else

  echo "Usage: db_backup.sh <sitename> <dbname> <label> <backuppath> <dumpcmdpath>"
  echo "  sitename    - Used to create subdirectory in backups directory"
  echo "  dbname      - Name of database"
  echo "  label       - Prefix for archives, usually timestamp"
  echo "  backuppath  - Path to the backup directory"
  echo "  dumpcmdpath - Path to the mysqldump command"

fi
