#!/bin/bash
#
# bare.sh
# BAckupREstore Shell Script
# by Nicholas Yang
#

# Get directory that script is being run from and cd there
BKUPSCRIPTPATH="$( cd "$( dirname "$0" )" && pwd )"
cd $BKUPSCRIPTPATH

# Just in case, make sure file/directory permissions are correct
chmod 600 ./config
find ./sitedata -type f -exec chmod 600 {} \;
find . -type f -iname "*.sh" -exec chmod 700 {} \;
find . -type d -exec chmod 700 {} \;

if [ ! -d ~/.my.cnf ]; then
    touch ~/.my.cnf
fi
chmod 600 ~/.my.cnf

# Source the config variables
export SITENAME=${2}
. ./config

# Argument checks
if ([ $# -ge 2 ] && [ $# -le 3 ]); then

    # Useful date variables
    DATE=`date -u +"%s"`
    DATE=$((DATE+(DATEHOURADJ*3600)))
    DATESTAMPYEAR=$(date +\%Y -d @${DATE})
    DATESTAMPMONTH=$(date +\%m -d @${DATE})
    DATESTAMPDAY=$(date +\%d -d @${DATE})
    DATESTAMPTIME=$(date +\%H\.\%M.\%S -d @${DATE})
    DATESTAMP=$(date +"%a %b %d %Y %H:%M:%S" -d @${DATE})
    DATELABEL=$(date +"%Y.%m.%d.%H%M" -d @${DATE})
    TOUCHDATE=$(date +"%Y-%m-%d %H:%M:%S" -d @${DATE})

    if [ "${PREFLIGHTERRORS}" == "" ]; then
        # Pre-flight checks and setup for "backup"
        if [ "${1}" == "backup" ]; then
            # Should be "nokeep" to delete backups older than $DAILYRANGE days
            KEEP=${3}

            if ([ ! "${KEEP}" == "nokeep" ] && [ ! "${KEEP}" == "" ]); then
                PREFLIGHTERRORS="Invalid argument: $KEEP, specify 'nokeep' to delete old backups"
            fi

            # We want to extract database information, so we want the dump command
            MYSQLCMDTOUSE=${DUMPCMDPATH}

            # Destination of the backup
            BKUPPATH=$BKUPDESTPATH/$DATESTAMPYEAR-$DATESTAMPMONTH-$DATESTAMPDAY/$SITENAME.bak/$DATELABEL

        # Pre-flight checks and setup for "restore"
        elif [ "${1}" == "restore" ]; then

            # To restore database, we just run queries with regular mysql command
            MYSQLCMDTOUSE=${MYSQLCMDPATH}

            # Get source directory of the backup to restore
            DATELABEL=${3}
            DATELABEL=$(echo ${DATELABEL} | sed 's/_.*//' )
            RESTOREYEAR=$(echo ${DATELABEL} | cut -f1 -s -d. )
            RESTOREMONTH=$(echo ${DATELABEL} | cut -f2 -s -d. )
            RESTOREDAY=$(echo ${DATELABEL} | cut -f3 -s -d. )
            BKUPPATH=$BKUPDESTPATH/$RESTOREYEAR-$RESTOREMONTH-$RESTOREDAY/$SITENAME.bak/$DATELABEL

            # Make sure backup directory exists
            if [ $# -eq 2 ]; then
                PREFLIGHTERRORS="Restore requires Argument 3, the date in format YYYY.MM.DD.HHmm"
            elif [ ! -d $BKUPPATH ]; then
                PREFLIGHTERRORS="Restore path dir not found: ${BKUPPATH}. Check your date (YYYY.MM.DD.HHmm)."
            # Make sure backup directory has files
            elif [ ! "$(ls -A $BKUPPATH)" ]; then
                PREFLIGHTERRORS="Can't find backup files in ${BKUPPATH}."
            # Make sure a valid restoredate was entered
            elif ([ "${RESTOREYEAR}" == "" ]) || ([ "${RESTOREMONTH}" == "" ]) || ([ "${RESTOREDAY}" == "" ]); then
                PREFLIGHTERRORS="Invalid date (YYYY.MM.DD.HHmm): ${DATELABEL}"
            fi

        fi
    fi

    # Ready to begin actual backup/restore

    ############################################################################
    ### Write header to log file
    ############################################################################

    # Variables are different if we're outputting errors
    if [ ! "${PREFLIGHTERRORS}" == "" ]; then
        DATELABEL=$(date +"%Y.%m.%d.%H%M" -d @${DATE})
        LOGFILE=$BKUPSCRIPTPATH/BARE-ERRORS_${DATELABEL}-${1}.log
    else
        if [ "${1}" == "backup" ]; then
            LOGFILE=$BKUPSCRIPTPATH/${DATELABEL}-${1}.log
        else
            # Restore logfile's date should be of when the script was run
            RESTORELOGDATELABEL=$(date +"%Y.%m.%d.%H%M" -d @${DATE})
            LOGFILE=$BKUPSCRIPTPATH/${RESTORELOGDATELABEL}-${1}.log
        fi

        # Make sure path exists for logfile (and backup, if this is a backup)
        mkdir -p $BKUPPATH
    fi

    echo '********************************************************************************' 2>&1 | tee -a $LOGFILE
    echo "["${1}"] $SITENAME on $DATESTAMP" 2>&1 | tee -a $LOGFILE
    echo '' 2>&1 | tee -a $LOGFILE

    # If there were any errors before this, we need to stop here
    if [ ! "${PREFLIGHTERRORS}" == "" ]; then
        echo "[ERROR] ${PREFLIGHTERRORS}" 2>&1 | tee -a $LOGFILE
        echo '' 2>&1 | tee -a $LOGFILE
        exit
    fi

    ############################################################################
    ### Directories
    ############################################################################

    if [ -f "./sitedata/${SITENAME}_directories" ]; then
        BKUPEXCLUDES=""
        SPACESINPATH=0

        while IFS='' read -r line || [[ -n "$line" ]]; do
            # Skip comment and blank lines
            [[ $line = \#* ]] && continue
                [[ -z "$line" ]] && continue

            # Trim leading/trailing whitespace
            DIRPATH=$(echo "$line" | sed 's/^[ \t]*//;s/[ \t]*$//')

            # Check for spaces in filename (in which case we need external exclude file); no need to use backslash for spaces, example: EXCLUDE=learn/System 1
            SPACELESSDIRPATH=$(echo "$DIRPATH" | sed 's/[[:blank:]]//g')
            if [ ! "${DIRPATH}" == "${SPACELESSDIRPATH}" ]; then
                SPACESINPATH=1
            fi

            # Check if this is an EXCLUDE definition
            if [[ "${DIRPATH}" == EXCLUDE=* ]]; then
                EXCLUDE=$(echo ${DIRPATH} | cut -f2 -s -d '=');

                if [ "${1}" == "backup" ]; then
                    if [ ${SPACESINPATH} -eq 1 ]; then
                        echo $EXCLUDE >> excludes_$$.tmp
                    else
                        BKUPEXCLUDES="--exclude=${EXCLUDE} ${BKUPEXCLUDES}"
                    fi
                fi

                # No need to execute the rest of this while-loop if it's an exclude line
                continue
            fi

            if [ ! "${DIRPATH}" == "" ]; then
                # Set the external exclude file if necessary
                if [ ${SPACESINPATH} -eq 1 ]; then
                    BKUPEXCLUDES="--exclude-from="${BKUPSCRIPTPATH}"/excludes_$$.tmp "${BKUPEXCLUDES}
                fi

                # EXCLUDE lines need to be prefixed with directory name, since tar
                # is executed from one directory level above
                if [ ! "${BKUPEXCLUDES}" == "" ]; then
                    DIRPREFIX=${DIRPATH##*/}/

                    # Double-slash to replace all instances of --exclude=
                    BKUPEXCLUDES="${BKUPEXCLUDES//--exclude=/--exclude=$DIRPREFIX}"

                    # If there were spaces in any path, prefix lines of the excludes file
                    if [ -f "${BKUPSCRIPTPATH}"/excludes_$$.tmp ]; then
                        # Use sed with # delimiter instead of / because $DIRPREFIX has /
                        sed -i -e "s#^#$DIRPREFIX#" "${BKUPSCRIPTPATH}"/excludes_$$.tmp
                    fi
                fi

                # Start logfile entry
                echo "["${1}" directory] $DIRPATH" 2>&1 | tee -a $LOGFILE

                # Run the backup/restore script, depending on what was specified
                ./helpers/dir_${1}.sh $DIRPATH $DATELABEL $BKUPPATH "${BKUPEXCLUDES}" 2>&1 | tee -a $LOGFILE

                # Exclude lines only apply to the one directory specified after them,
                # so reset all the variables
                BKUPEXCLUDES=""
                SPACESINPATH=0
                rm -f excludes_$$.tmp
            fi

        done < "./sitedata/${SITENAME}_directories"
    else
        echo "[ERROR] ${SITENAME}_directories file not found in sitedata folder" 2>&1 | tee -a $LOGFILE
    fi

    ############################################################################
    ### Databases
    ############################################################################
    if [ -f "./sitedata/${SITENAME}_databases" ]; then
        while IFS='' read -r line || [[ -n "$line" ]]; do
            # Skip comment and blank lines
            [[ $line = \#* ]] && continue
                [[ -z "$line" ]] && continue

            # Trim whitespace
            DBINFO=${line}

            DBNAME=$(echo ${DBINFO} | cut -f1 -s -d ' ');
            DBNAME=$(echo "$DBNAME" | sed 's/^[ \t]*//;s/[ \t]*$//') # Trim

            echo "["${1}" database] $DBNAME" 2>&1 | tee -a $LOGFILE

            ./helpers/db_${1}.sh $SITENAME $DBINFO $DATELABEL $BKUPPATH $MYSQLCMDTOUSE 2>&1 | tee -a $LOGFILE

        done < "./sitedata/${SITENAME}_databases"
    else
        echo "[ERROR] ${SITENAME}_databases file not found in sitedata folder" 2>&1 | tee -a $LOGFILE
    fi

    ############################################################################
    ### Cleanup
    ############################################################################
    if [ "${1}" == "backup" ]; then

        if [ "${KEEP}" == "nokeep" ]; then
            # Remove old backups
            echo "[INFO] Removing backups older than ${DAILYRANGE} day(s):" 2>&1 | tee -a $LOGFILE
            if find $BKUPDESTPATH/* -maxdepth 0 -type d -mtime +$((DAILYRANGE - 1)) -exec rm -rf  {} \; ; then
                echo "  [OK] ($?) No problems" 2>&1 | tee -a $LOGFILE
            else
                echo "  [FAILED] ($?) Something went wrong with find command" 2>&1 | tee -a $LOGFILE
            fi
        else
            echo "[INFO] Not deleting old backups, as nokeep wasn't specified" 2>&1 | tee -a $LOGFILE
        fi

    fi

    # Make sure permissions are correct for all backups made
    echo "[INFO] Setting permissions of backup files" 2>&1 | tee -a $LOGFILE
    find $BKUPDESTPATH ! -perm 600 -type f -exec chmod 600 {} \;
    find $BKUPDESTPATH ! -perm 700 -type d -exec chmod 700 {} \;

    # Make sure timestamps are correct (in case adjusted for $DATEHOURADJ)
    if [ "${1}" == "backup" ]; then
        # Make sure there are files present, indicating no errors
        if [ "$(ls -A $BKUPPATH)" ]; then
            echo "[INFO] Correcting timestamps" 2>&1 | tee -a $LOGFILE

            touch -d "${TOUCHDATE}" $BKUPPATH
            touch -d "${TOUCHDATE}" $BKUPPATH/*

            touch -d "${TOUCHDATE}" $BKUPDESTPATH/$DATESTAMPYEAR-$DATESTAMPMONTH-$DATESTAMPDAY/$SITENAME.bak
            touch -d "${TOUCHDATE}" $BKUPDESTPATH/$DATESTAMPYEAR-$DATESTAMPMONTH-$DATESTAMPDAY
            touch -d "${TOUCHDATE}" $BKUPDESTPATH
        fi
    elif [ "${1}" == "restore" ]; then

        # In case of restore, logfile is the only file that should be touched
        touch -d "${DATEHOURADJ} hour" $LOGFILE

    fi

    echo '' 2>&1 | tee -a $LOGFILE
    echo 'DONE.' 2>&1 | tee -a $LOGFILE
    echo '' 2>&1 | tee -a $LOGFILE

    COMPLETEDDATE=`date -u +"%s"`
    COMPLETEDDATESTAMP=$(date +"%a %b %d %Y %H:%M:%S" -d @${COMPLETEDDATE})
    DATESTAMP=$(date +"%a %b %d %Y %H:%M:%S" -d @${DATE})
    echo "["${1}"] $SITENAME STARTED on $DATESTAMP" 2>&1 | tee -a $LOGFILE
    echo "["${1}"] $SITENAME COMPLETED on $COMPLETEDDATESTAMP" 2>&1 | tee -a $LOGFILE
    DURATION=$((COMPLETEDDATE - DATE))
    DURATIONFORMATTED=$(date +"%M:%S" -d @${DURATION})
    echo '' 2>&1 | tee -a $LOGFILE
    echo "Total Duration: ${DURATIONFORMATTED}" 2>&1 | tee -a $LOGFILE
    echo '' 2>&1 | tee -a $LOGFILE

    ############################################################################
    ### Rename logfile if errors were encountered
    ############################################################################
    if (grep -iq "\[ERROR\]" $LOGFILE || grep -iq "got error" $LOGFILE || grep -iq "ERRORS encountered" $LOGFILE); then
        echo '******** ERRORS WERE ENCOUNTERED ********' 2>&1 | tee -a $LOGFILE
        echo '' 2>&1 | tee -a $LOGFILE

        # Logfile will appear in backup script directory
        mv $LOGFILE $BKUPSCRIPTPATH/BARE-ERRORS_${DATELABEL}-${1}.log
    else
        # If all is well, move the .log file to the backup directory
        mv $LOGFILE $BKUPPATH
    fi

    exit

fi

echo "Usage: `basename "$0"` <backup|restore> <sitename> <nokeep|restoredate>"
echo "  backup|restore - operation to perform"
echo "  sitename       - site name, should be prefix of backup script name"
echo "  nokeep         - if backing up, this option deletes old backups"
echo "  restoredate    - name of backup directory, should be YYYY.MM.DD.HHmm"
