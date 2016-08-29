#!/bin/bash

function wait_for_log_entry {
	LOG_FILE=$1
	LOG_ENTRY=$2

	echo "Waiting for $LOG_ENTRY in $LOG_FILE"

	while ! grep -q "$LOG_ENTRY" "$LOG_FILE"; do
		echo "Waiting for $LOG_ENTRY in $LOG_FILE"
		sleep 1
	done

	echo "Finished waiting for $LOG_ENTRY in $LOG_FILE"
}

function restore_db_from_file {
	BACKUP_FILE=$1
	DUMP_FILE_NAME=$(basename "$BACKUP_FILE")
	DUMP_FILE_NAME=${DUMP_FILE_NAME/\.gz/}
	DB_NAME=$(echo $DUMP_FILE_NAME | sed -e 's/\(\|\.db\|\.dump\|\.dmp\)$//' -e 's/[.+-]\+/_/g')
	DB_DEV_NAME=${DB_NAME}dev

	echo "Extracting datbase $DB_NAME from file: $BACKUP_FILE (extracted $DUMP_FILE_NAME)"
	mkdir -p /var/lib/sap/datadir/backups
	mv -v $BACKUP_FILE /var/lib/sap/datadir/backups
	cd /var/lib/sap/datadir/backups
	gunzip -v *.gz
	cd -

	echo "Restoring database $DB_NAME"
	dump_transaction_log master

	isql -Usa -P --retserverror -SSYBASE << EOF | tee /tmp/restore.log
load database master from "/var/lib/sap/datadir/backups/$DUMP_FILE_NAME" with headeronly
go
EOF
	DB_PAGE_SIZE=$(awk '/Database page size/ {print $4}' /tmp/restore.log)
	DB_PAGE_SIZE_KB=$(expr ${DB_PAGE_SIZE/\./} / 1024)
	DB_PAGES=$(awk '/Number of logical pages/ {print $5}' /tmp/restore.log)
	DB_SIZE_KB=$(expr $DB_PAGES '*' $DB_PAGE_SIZE_KB)
	rm /tmp/restore.log
	
	isql -Usa -P --retserverror -SSYBASE << EOF | tee /tmp/restore.log
disk init name = "$DB_DEV_NAME", physname = "/var/lib/sap/datadir/$DB_NAME.dat", 
	skip_alloc = true, dsync = true, size = "${DB_SIZE_KB}K"
go
create database $DB_NAME on $DB_DEV_NAME = "${DB_SIZE_KB}K" for load
go
load database $DB_NAME from "/var/lib/sap/datadir/backups/$DUMP_FILE_NAME"
go
online database $DB_NAME
go
EOF

	grep -q 3115 /tmp/restore.log
	STATUS=$?

	rm -v /tmp/restore.log
	rm -vrf /var/lib/sap/datadir/backups

	dump_transaction_log master

	echo "Restore finished for $DB_NAME"

	if [ "$STATUS" = "0" ]; then
		exit
	fi

	# http://www.petersap.nl/SybaseWiki/index.php?title=Bypasssing_cross_platform_load_issues
	echo "Bypassing Msg 3151 for $DB_NAME - changeing server configuration"
	isql -Usa -P --retserverror -SSYBASE << EOF
use master
go
sp_configure "allow updates",1
go
update sysdatabases set status = -32768,status3=131072 where name = "$DB_NAME"
go
EOF

	stop_db_server
	start_db_server

	wait_for_log_entry /var/lib/sap/datadir/SYBASE.log "Bypassing recovery of database id"
	wait_for_log_entry /var/lib/sap/datadir/SYBASE.log "Recovery complete"

	echo "Bypassing Msg 3151 for $DB_NAME - running dbcc"
	isql -Usa -P --retserverror -SSYBASE << EOF
dbcc traceon(3604)
go
dbcc save_rebuild_log($DB_NAME)
go
update sysdatabases set status = 0 where name = "$DB_NAME"
go
EOF

	stop_db_server
	start_db_server

	wait_for_log_entry /var/lib/sap/datadir/SYBASE.log "Recovery complete"

	sleep 1

	isql -Usa -P -SSYBASE <<EOF | grep -q background
Select *  from master..sysprocesses where status = "background" 
GO
EOF

	STATUS=$?

	while [ "$STATUS" = "0" ]; do
		echo "Winting for $DB_NAME database recovery background process to finish ..."
		sleep 1
		isql -Usa -P -SSYBASE <<EOF | grep -q background
Select *  from master..sysprocesses where status ="background" 
GO
EOF
		STATUS=$?
	done

	echo "Bypassing Msg 3151 for $DB_NAME - Remove replication logs"
	isql -Usa -P --retserverror -SSYBASE << EOF
dbcc dbrepair($DB_NAME,ltmignore)
go
online database $DB_NAME
go
EOF

	dump_transaction_log master

	echo "Bypassing Msg 3151 for $DNBNAME - Finishing"
	isql -Usa -P --retserverror -SSYBASE << EOF
dbcc dbrepair($DB_NAME,ltmignore)
go
update sysdatabases set status3=524288 where name = "$DB_NAME"
go
use $DB_NAME
go
sp_post_xpload
go
use master
go
update sysdatabases set status3=0 where name = "$DB_NAME"
go
EOF
	dump_transaction_log master

	echo "Recovery finished for $DB_NAME"
}

for backup_file in /var/lib/sap/backups/*; do
	echo "Starting database restore for $backup_file"
	restore_db_from_file $backup_file
	echo "Finished database restore for $backup_file"
done
