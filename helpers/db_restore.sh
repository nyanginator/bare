#!/bin/bash

if [ $# == 5 ]; then

  SITENAME=$1
  THEDB=$2
  LABEL=$3
  BKUPPATH=$4
  MYSQLCMDPATH=$5

  GZLABEL=$BKUPPATH/${LABEL}-${THEDB}.sql.gz

  if [ ! -f ${GZLABEL} ]; then
    echo "[ERROR] DB backup file not found: ${GZLABEL}"
    echo ""
    exit
  fi

  cd $BKUPPATH

  echo "[INFO] Dropping old database, if it exists"
  if ! $MYSQLCMDPATH --defaults-group-suffix=$THEDB -e "DROP DATABASE IF EXISTS ${THEDB}"; then
      echo "[ERROR] Could not drop old database"
      echo ""
      exit
  fi

  echo "[INFO] Creating new empty database"
  if ! $MYSQLCMDPATH --defaults-group-suffix=$THEDB -e "CREATE DATABASE ${THEDB} COLLATE utf8_general_ci"; then
      echo "[ERROR] Could not create new empty database"
      echo ""
      exit
  fi
  echo ""
  
  if time -p gzip -cd < ${GZLABEL} | $MYSQLCMDPATH --defaults-group-suffix=$THEDB $THEDB; then
    echo "mysql import COMPLETE ($?) for database: $THEDB of site: $SITENAME"
  else
    echo "mysql import ERRORS encountered ($?) for database: $THEDB of site: $SITENAME"
  fi
  echo ""

else

  echo "Usage: db_restore.sh <sitename> <dbname> <label> <backuppath> <mysqlcmdpath>"
  echo "  sitename     - Used to create subdirectory in backups directory"
  echo "  dbname       - Name of database"
  echo "  label        - Prefix for archives, usually timestamp"
  echo "  backuppath   - Path to the backup directory"
  echo "  mysqlcmdpath - Path to the mysql command"

fi
