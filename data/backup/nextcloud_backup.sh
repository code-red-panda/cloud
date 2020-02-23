#!/bin/bash



LOG_DIR="/var/log/nextcloud"
DETAIL_LOG="$LOG_DIR/backup_details.log"
TS=`date +%Y-%m-%d_%H-%M-UTC`
BACKUP_DIR="/backups/$TS"
TAR_SRC="/var/lib/docker/volumes/* /opt/cloud/data/* /opt/cloud/.env /root/.my.cnf /etc/cron.d/nextcloud_crons --exclude /var/lib/docker/volumes/cloud_percona_datadir"
TAR_TRG="$BACKUP_DIR/nextcloud_backup.tar.gz"
MYDUMPER_DIR="$BACKUP_DIR/mydumper"
BACKUP_DIR_TAR_TRG="$BACKUP_DIR.tar.gz"
BACKUP_DIR_TAR_GPG="$BACKUP_DIR_TAR_TRG.gpg"
GPG_EMAIL="nextcloud@coderedpanda.com"



mkdir -p $LOG_DIR
  if test ! $? = 0
  then
      echo "`date "+%Y-%m-%d +%H:%M:%S UTC"` ERROR:: Backup failed to start. Log directory $LOG_DIR was not created. Exiting."
      exit 1
  fi



echo -e "\n`date "+%Y-%m-%d %H:%M:%S UTC"`" >> $DETAIL_LOG
  if test ! $? = 0
  then
      echo "`date "+%Y-%m-%d %H:%M:%S UTC"` ERROR:: Backup failed to start. Detail log $DETAIL_LOG was not able to be updated. Exiting."
      exit 1
  fi



echo "`date "+%Y-%m-%d %H:%M:%S UTC"` INFO::>>>>>>>>>>>>>>>>>> BACKUP STATUS: [ START ]"



echo "`date "+%Y-%m-%d %H:%M:%S UTC"` INFO STEP 1/7:: Putting Nextcloud into maintenance mode..."
docker exec -u www-data nextcloud php occ maintenance:mode --on >> $DETAIL_LOG 2>&1
  if test ! $? = 0
  then
      echo "`date "+%Y-%m-%d %H:%M:%S UTC"` ERROR:: Nextcloud was not put into maintenance mode. Check the details log $DETAIL_LOG. Exiting."
      echo "`date "+%Y-%m-%d %H:%M:%S UTC"` INFO::>>>>>>>>>>>>>>>>>> BACKUP STATUS: [ FAILED ]"
      exit 1
  fi



echo "`date "+%Y-%m-%d %H:%M:%S UTC"` INFO STEP 1/7:: Creating backup directory $BACKUP_DIR..."
mkdir -p $BACKUP_DIR >> $DETAIL_LOG 2>&1
mkdir -p $MYDUMPER_DIR >> $DETAIL_LOG 2>&1
  if test ! $? = 0
  then
      echo "`date "+%Y-%m-%d %H:%M:%S UTC"` ERROR:: Backup directory was not created. Check the details log $DETAIL_LOG. Exiting and taking Nextcloud out of maintenance mode."
      docker exec -u www-data nextcloud php occ maintenance:mode --off >> $DETAIL_LOG 2>&1
      echo "`date "+%Y-%m-%d %H:%M:%S UTC"` INFO::>>>>>>>>>>>>>>>>>> BACKUP STATUS: [ FAILED ]"
      exit 1
  fi



echo "`date "+%Y-%m-%d %H:%M:%S UTC"` INFO STEP 1/7:: Tar'ing Docker volumes $TAR_SRC..."
tar czf $TAR_TRG $TAR_SRC >> $DETAIL_LOG 2>&1
  if test ! $? = 0
  then
      echo "`date "+%Y-%m-%d %H:%M:%S UTC"` ERROR:: Tar'ing Docker volumes did not complete OK. Check the details log $DETAIL_LOG. Exiting and taking Nextcloud out of maintenance mode."
      docker exec -u www-data nextcloud php occ maintenance:mode --off >> $DETAIL_LOG 2>&1
      echo "`date "+%Y-%m-%d %H:%M:%S UTC"` INFO::>>>>>>>>>>>>>>>>>> BACKUP STATUS: [ FAILED ]"
      exit 1
  fi



echo "`date "+%Y-%m-%d %H:%M:%S UTC"` INFO STEP 1/7:: Taking Mydumper backup..."
mydumper --outputdir=$MYDUMPER_DIR --regex='^((nextcloud\.|mysql\.user))' --threads=2 --chunk-filesize=5120 --build-empty-files  --compress --verbose=3 --trx-consistency-only >> $DETAIL_LOG 2>&1
  if test ! $? = 0
  then
      echo "`date "+%Y-%m-%d %H:%M:%S UTC"` ERROR:: Mydumper backup did not complete OK. Check the details log $DETAIL_LOG. Exiting and taking Nextcloud out of maintenance mode."
      docker exec -u www-data nextcloud php occ maintenance:mode --off >> $DETAIL_LOG 2>&1
      echo "`date "+%Y-%m-%d %H:%M:%S UTC"` INFO::>>>>>>>>>>>>>>>>>> BACKUP STATUS: [ FAILED ]"
      exit 1
  fi



echo "`date "+%Y-%m-%d %H:%M:%S UTC"` INFO STEP 1/7:: Taking Nextcloud out of maintenance mode..."
docker exec -u www-data nextcloud php occ maintenance:mode --off >> $DETAIL_LOG 2>&1
  if test ! $? = 0
  then
      echo "`date "+%Y-%m-%d %H:%M:%S UTC"` ERROR:: Nextcloud was not taken out of maintenance mode. Check the details log $DETAIL_LOG. Exiting."
      echo "`date "+%Y-%m-%d %H:%M:%S UTC"` INFO::>>>>>>>>>>>>>>>>>> BACKUP STATUS: [ FAILED ]"
      exit 1
  fi



echo "`date "+%Y-%m-%d %H:%M:%S UTC"` INFO STEP 1/7:: Tar'ing backup directory $BACKUP_DIR..."
tar czf $BACKUP_DIR_TAR_TRG $BACKUP_DIR >> $DETAIL_LOG 2>&1
  if test ! $? = 0
  then
      echo "`date "+%Y-%m-%d %H:%M:%S UTC"` ERROR:: Tar'ing backup directory did not complete OK. Check the details log $DETAIL_LOG."
      echo "`date "+%Y-%m-%d %H:%M:%S UTC"` INFO::>>>>>>>>>>>>>>>>>> BACKUP STATUS: [ FAILED ]"
      exit 1
  fi



echo "`date "+%Y-%m-%d %H:%M:%S UTC"` INFO STEP 1/7:: Encrypting backup $BACKUP_DIR_TAR_TRG..."
gpg --output $BACKUP_DIR_TAR_GPG --encrypt --recipient $GPG_EMAIL $BACKUP_DIR_TAR_TRG
  if test ! $? = 0
  then
      echo "`date "+%Y-%m-%d %H:%M:%S UTC"` ERROR:: Encrypting backup did not complete OK."
      echo "`date "+%Y-%m-%d %H:%M:%S UTC"` INFO::>>>>>>>>>>>>>>>>>> BACKUP STATUS: [ FAILED ]"
      exit 1
  fi



echo "`date "+%Y-%m-%d %H:%M:%S UTC"` INFO STEP 1/7:: Cleaning up and removing untar'd and unecrypted backups $BACKUP_DIR and $BACKUP_DIR_TAR_TRG..."
rm -rf $BACKUP_DIR $BACKUP_DIR_TAR_TRG >> $DETAIL_LOG 2>&1
  if test ! $? = 0
  then
      echo "`date "+%Y-%m-%d %H:%M:%S UTC"` ERROR:: Removing backups did not complete OK. Check the details log $DETAIL_LOG."
      echo "`date "+%Y-%m-%d %H:%M:%S UTC"` INFO::>>>>>>>>>>>>>>>>>> BACKUP STATUS: [ FAILED ]"
      exit 1
  fi



echo "`date "+%Y-%m-%d %H:%M:%S UTC"` INFO::>>>>>>>>>>>>>>>>>> BACKUP STATUS: [ COMPLETED ]"
