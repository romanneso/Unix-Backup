#!/bin/bash
#
# 2014 by Roman Neso Laupmaa

# BEGIN CONFIGURATION ==========================================================

BACKUP_DIR="/backup"  # Where to keep the backups
KEEP_MYSQL="30" # How many days worth of mysql dumps to keep
KEEP_SITES="5" # How many days worth of site tarballs to keep

MYSQL_SERVER="localhost"
MYSQL_USER="root"
MYSQL_PASS=""
MYSQL_BACKUP_DIR="$BACKUP_DIR/mysql/"

SITES_DIR="/var/www/" # Where your websites are stored
SITES_BACKUP_DIR="$BACKUP_DIR/sites/"

SYNC="rsync" # 'rsync' or 'none'

# Always setup public key authentication
RSYNC_SERVER=""
RSYNC_USER="root"
RSYNC_DIR="/path/to/backups/$HOSTNAME/"
RSYNC_PORT="22" # Change this if you've customized the SSH port of your backup system

# You probably won't have to change these
THE_DATE="$(date '+%d-%m-%Y')"

MYSQL_PATH="$(which mysql)"
MYSQLDUMP_PATH="$(which mysqldump)"
FIND_PATH="$(which find)"
TAR_PATH="$(which tar)"
RSYNC_PATH="$(which rsync)"

# END CONFIGURATION ============================================================



# Announce the backup time
echo "Backup Started: $(date)"

# Create the backup dirs if they don't exist
if [[ ! -d $BACKUP_DIR ]]
  then
  mkdir -p "$BACKUP_DIR"
fi
if [[ ! -d $MYSQL_BACKUP_DIR ]]
  then
  mkdir -p "$MYSQL_BACKUP_DIR"
fi
if [[ ! -d $SITES_BACKUP_DIR ]]
  then
  mkdir -p "$SITES_BACKUP_DIR"
fi

# Get a list of mysql databases and dump them one by one
echo "------------------------------------"
DBS="$($MYSQL_PATH -h $MYSQL_SERVER -u$MYSQL_USER -p$MYSQL_PASS -Bse 'show databases')"
for db in $DBS
do
  if [[ $db != "information_schema" && $db != "mysql" && $db != "performance_schema" ]]
    then
    echo "Dumping: $db..."
    $MYSQLDUMP_PATH -u $MYSQL_USER -p$MYSQL_PASS $db | gzip > $MYSQL_BACKUP_DIR$db\_$THE_DATE.sql.gz
  fi
done

# Delete old dumps
echo "------------------------------------"
echo "Deleting old backups..."
# List dumps to be deleted to stdout (for report)
$FIND_PATH $MYSQL_BACKUP_DIR*.sql.gz -mtime +$KEEP_MYSQL
# Delete dumps older than specified number of days
$FIND_PATH $MYSQL_BACKUP_DIR*.sql.gz -mtime +$KEEP_MYSQL -exec rm {} +

# Get a list of files in the sites directory and tar them one by one
echo "------------------------------------"
cd $SITES_DIR
for d in *
do
  echo "Archiving $d..."
  $TAR_PATH --exclude="/log" --exclude="/logs" -C $SITES_DIR -czf $SITES_BACKUP_DIR/$d\_$THE_DATE.tgz $d
done

# Delete old site backups
echo "------------------------------------"
echo "Deleting old backups..."
# List files to be deleted to stdout (for report)
$FIND_PATH $SITES_BACKUP_DIR*.tgz -mtime +$KEEP_SITES
# Delete files older than specified number of days
$FIND_PATH $SITES_BACKUP_DIR*.tgz -mtime +$KEEP_SITES -exec rm {} +

# Rsync everything with another server
if [[ $SYNC == "rsync" ]]
  then
  echo "------------------------------------"
  echo "Sending backups to backup server..."
  $RSYNC_PATH --del -vaze "ssh -p $RSYNC_PORT" $BACKUP_DIR/ $RSYNC_USER@$RSYNC_SERVER:$RSYNC_DIR

# Announce the completion time
echo "------------------------------------"
echo "Backup Completed: $(date)"