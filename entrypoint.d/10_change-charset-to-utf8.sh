#!/bin/bash


charset -Usa -SSYBASE -P binary.srt cp1250
charset -Usa -SSYBASE -P binary.srt utf8

isql -Usa -P -SSYBASE -J iso_1 << EOF
sp_configure 'default character set', 190
go
sp_configure 'default sortorder id', 50
go
EOF

stop_db_server

#This will exit after conversion
/ase-start-dataserver.sh

start_db_server
