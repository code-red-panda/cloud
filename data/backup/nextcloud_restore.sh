#!/bin/bash

source /opt/cloud/.env

BACKUP_DIR="/backups"

echo "Getting the list of backups..."
/root/.local/bin/aws s3 ls s3://$S3_BUCKET/nextcloud/

i=0

while [ $i -lt 1 ]
do
  read -p "Which backup would you like to restore? [EX: 2020-03-17_22-31-UTC.tar.gz.gpg]: " TS

  /root/.local/bin/aws s3 cp s3://$S3_BUCKET/nextcloud/$TS $BACKUP_DIR

  if test -f "$BACKUP_DIR/$TS"
  then
    echo "Downloaded backup OK."
    BACKUP_TAR=$(echo $TS | sed 's/.gpg//')
    i=1
  else
    echo -e "\nCould not download backup. See error above and try again."
    i=0
  fi
done

echo "Decrypting the backup..."
gpg --output $BACKUP_DIR/$BACKUP_TAR --decrypt $BACKUP_DIR/$TS

echo "Untar'ing the backup..."
tar xzf $BACKUP_DIR/$BACKUP_TAR -C /
BACKUP_SRC=$(echo $BACKUP_TAR | sed 's/.tar.gz//')

echo "WARNING..."
echo "1) Restoring this backup will delete ALL Docker data (even data for your non-Nextcloud containers)."
echo "2) All data since this restore will be lost."
echo "3) Nextcloud will be offline during the restore."

while read -p "Are you sure you want to proceed? [y/n]: " REPLY
do
  case $REPLY in
  y) echo "OK. Restoring backup." ; break ;;
  Y) echo "OK. Restoring backup." ; break ;;
  n) echo "Exiting. Not restoring backup." ; exit 1 ;;
  N) echo "Exiting. Not restoring backup." ; exit 1 ;;
  *) echo "Please answer y or n." ;;
  esac
done

echo "Stopping Docker containers..."
cd /opt/cloud
/usr/local/bin/docker-compose down

echo "Deleting all Docker data..."
ls /var/lib/docker/volumes/ | grep -v cloud_percona_datadir | xargs -iX rm -rf /var/lib/docker/volumes/X

echo "Restoring Docker data from backup..."
tar xzf $BACKUP_DIR/$BACKUP_SRC/nextcloud_backup.tar.gz -C /

echo "Starting Docker containers..."
/usr/local/bin/docker-compose up -d

echo "Restoring Mydumper data from backup..."
IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' percona-server)
sed -i 's/host=.*/host='$IP'/' /root/.my.cnf
myloader --directory=$BACKUP_DIR/$BACKUP_SRC/mydumper --overwrite-tables --enable-binlog --queries-per-transaction=10 --threads=2 --verbose 3

echo "Taking Nextcloud out of maintenance mode..."
docker exec -u www-data nextcloud php occ maintenance:mode --off

echo "Restore completed."
