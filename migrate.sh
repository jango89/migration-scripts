##!/usr/bin/env bash
##USAGE = ./migrate.sh {from_host} {from_user} {to_host} {to_user} eg : ./migrate.sh postgres11-db.prelive.mytaxi.com mytaxi dbmaster.johnny.mytaxi.com mytaxi
if [ $# -lt 4 ]
  then
    echo "ERROR : Please use like this ==> = ./migrate.sh {from_host} {from_user} {to_host} {to_user}\n  eg : ./migrate.sh postgres11-db.prelive.mytaxi.com mytaxi dbmaster.johnny.mytaxi.com mytaxi"
    exit -1
fi

from_host=$1
from_user=$2
to_host=$3
to_user=$4

#read password from file
cp pgpass.conf ~/.pgpass
chmod 0600 ~/.pgpass

#dump data
echo "Data dumping started !!!"
psql -h $from_host -U $from_user -d mytaxi -w -c "copy(select id_prim as device_id_primary, id as device_id, status, token, os_version, os, model, language, date_created, date_last_update as date_updated from devices) to stdout" > devices.sql
echo "Data dumped, restoring in progress !!!"

#store dumped data
psql -d passengeraccountservice -h $to_host -U $to_user -c 'copy devices from stdin' < devices.sql

#set sequence to max device_id_primary
echo "Set sequence value to max id !!!"
psql -d passengeraccountservice -h $to_host -U $to_user -c "SELECT setval('device_id_sequence', (SELECT MAX(device_id_primary) + 10 FROM devices))"

#cleanup
rm -r devices.sql

echo "Completed !!!"
exit 0