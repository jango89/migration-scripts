##!/usr/bin/env bash
## Use this once we enable feature flag for devices_table
##USAGE = ./catchup_data.sh {from_host} {from_user} {to_host} {to_user} {from_date} eg : ./catchup_data.sh postgres11-db.prelive.mytaxi.com mytaxi dbmaster.johnny.mytaxi.com mytaxi '2015-07-15 00:00:00'
##  --- WHY we have another script to catch up data => Because here we use insert statements rather than COPY. INSERT statements are very slow and we do it this way assuming.
##  --- 1. Assuming, catching up data will only have smaller subset of data.
##  --- 2. COPY will fail incase of duplicate ID's and with insert statements we can insert new records and not fail for duplicates.
if [ $# -lt 5 ]
  then
    echo "ERROR : Please use like this ==> = ./catchup_data.sh {from_host} {from_user} {to_host} {to_user} {from_date} eg : ./catchup_data.sh postgres11-db.prelive.mytaxi.com mytaxi dbmaster.johnny.mytaxi.com mytaxi '2019-12-21 00:00:00'"
    exit -1
fi

from_host=$1
from_user=$2
to_host=$3
to_user=$4
from_date=$5

#read password from file
cp pgpass.conf ~/.pgpass
chmod 0600 ~/.pgpass

#dump data
echo "Data catching up started !!!"
psql -h $from_host -U $from_user -d mytaxi -w -c "copy(select id_prim, id, status, token, os_version, os, model, language, date_created, date_last_update from devices where date_last_update >= '$from_date' order by id_prim asc) to stdout WITH (FORMAT CSV, DELIMITER ',', QUOTE '\"', FORCE_QUOTE (id, status, token, os_version, os, model, language, date_created, date_last_update), NULL 'NULL') "  > devices.sql


#Create restore commands via insert statements.
echo "Data dumped from $from_host, Prepare insert statements for restoring data !!!"
echo "" >  devices_to_be_inserted.sql

#read the file content and convert into insert statements
while IFS= read -r line
do
  #replace double quotes with single quotes
  replaced_line=${line//\"/\'}
  #save the insert command to a file to be persisted
  echo "INSERT INTO DEVICES(device_id_primary,device_id,status,token,os_version,os,model,language,date_created,date_updated) VALUES ($replaced_line) ON CONFLICT DO NOTHING;" >> devices_to_be_inserted.sql
done < devices.sql

#Restoring data
echo "Restoring to $to_host in progress !!!"

#store dumped data
psql -d passengeraccountservice -h $to_host -U $to_user -f devices_to_be_inserted.sql

#set sequence to max device_id_primary
echo "Set sequence value to max id !!!"
psql -d passengeraccountservice -h $to_host -U $to_user -c "SELECT setval('device_id_sequence', (SELECT MAX(device_id_primary) + 10 FROM devices))"

#cleanup
rm -r devices_to_be_inserted.sql devices.sql

echo "Completed !!!"
exit 0
