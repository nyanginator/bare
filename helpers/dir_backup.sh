#!/bin/bash

if [ $# == 3 ] || [ $# == 4 ]; then

  DIRPATH=$1
  DIRNAME=${DIRPATH##*/}
  LABEL=$2
  BKUPPATH=$3
  EXCLUDE=""

  if [ $# == 4 ]; then
    EXCLUDE=$4
  fi
  echo "EXCLUDES: "${EXCLUDE}

  if [ ! -d ${DIRPATH} ]; then
    echo "[ERROR] Directory not found: $DIRPATH"
    echo ""
    exit
  fi

  mkdir -p $BKUPPATH
  cd $DIRPATH
  cd ..

  if time -p tar czfv $BKUPPATH/${LABEL}-${DIRNAME}.tar.gz ${EXCLUDE} ${DIRNAME}; then
    echo "tar SUCCESSFUL ($?)"
  else
    echo "tar ERRORS encountered ($?)"
  fi
  echo ""

else

  echo "Usage: site_backup.sh <dirpath> <label> <backuppath> [exclude]"
  echo "  dirpath   - Full path to site directory"
  echo "  label      - Prefix for archives, usually timestamp"
  echo "  backuppath - Path to the backup directory"
  echo "  exclude    - Optional tar --exclude parameter"

fi
