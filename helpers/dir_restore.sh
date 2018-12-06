#!/bin/bash

if [ $# == 3 ] || [ $# == 4 ]; then

  DIRPATH=$1
  DIRNAME=${DIRPATH##*/}
  LABEL=$2
  BKUPPATH=$3
  UNUSED=$4 # Only used in the backup script

  TARGZNAME=${BKUPPATH}/${LABEL}-${DIRNAME}.tar.gz

  if [ ! -f ${TARGZNAME} ]; then
    echo "[ERROR] Site backup file not found: $TARGZNAME"
    echo ""
    exit
  fi

  if [ -d ${DIRPATH} ]; then
      echo "[INFO] Deleting existing ($DIRPATH)"
      if ! rm -rf $DIRPATH; then
          echo "[ERROR] Could not remove old directory"
          echo ""
          exit
      fi
  fi

  echo "[INFO] Creating new ($DIRPATH)"

  if ! mkdir -p $DIRPATH; then
      echo "[ERROR] Could not create directory"
      echo ""
      exit
  fi
  echo ""

  cd $DIRPATH
  cd ..

  # tar will overwrite files if same files found
  if time -p tar xfvz ${TARGZNAME}; then
    echo "tar extraction SUCCESSFUL ($?)"
  else
    echo "tar extraction ERRORS encountered ($?)"
  fi
  echo ""

else

  echo "Usage: site_restore.sh <dirpath> <label> <backuppath>"
  echo "  dirpath   - Full path to site directory (restores to here)"
  echo "  label      - Prefix for archives, usually timestamp"
  echo "  backuppath - Path to the backup directory"

fi
