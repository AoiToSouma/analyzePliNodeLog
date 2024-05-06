#!/bin/bash

source .env

logdate=$(ls -l --time-style=+'%Y-%m-%dT%T' ~/.pm2/logs/NodeStartPM2-error.log.1 | sed -e 's/ \+/ /g' | cut -d' ' -f6)
ymd_date=$(date -d"${logdate}" +"%Y-%m-%d")

#Duplicate processing check
exist=$(sqlite3 data/${dbname} "SELECT count(*) FROM aggregation WHERE logdate = '$ymd_date';")
if [ "$exist" -ne 0 ]; then
    echo "This log has already been aggregated."
    exit
fi

cat ~/.pm2/logs/NodeStartPM2-error.log.1 | awk -F'.go' '{print $1}' | cut -c 25- | \
sed 's/Finished callback in [0-9]*.*[0-9]*.s *headtracker/Finished callback in 00\.00s headtracker/g' | \
sed 's/RPC endpoint failed to respond to [0-9]*/RPC endpoint failed to respond to 00/g' | \
sed 's/Starting backfill of logs from [0-9]*/Starting backfill of logs from 00/g' | \
sed 's/block number [0-9]*/block number 00000000/g' | \
sed 's/\#[0-9]* (0x[0-9a-zA-Z]*)/\#00000000 (0x0000000)/g' | \
sed 's/Calculated gas price of [0-9]*.*[0-9]*.*wei/Calculated gas price of 000.000 mwei/g' | \
sed 's/with hash 0x[0-9a-zA-Z]*/with hash 0x0000/g' | \
sed 's/gas price: [0-9]*.*[0-9]* Gwei/gas price: 0.00 Gwei/g' | \
sed 's/for block numbers \[.*\] even though the WS subscription/for block numbers \[00000000\] even though the WS subscription/g' | \
sed 's/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}Z/0000-00-00T00:00:00Z/g' | \
sed 's/subscriber 0x[0-9a-zA-Z]\{10\}/subscriber 0x0000000000/g' | \
sed 's/loaded [0-9]*\/[0-9]* results */loaded 00\/00 results /g' | \
sed 's/completed in [0-9]*.*[0-9]*.*s */completed in 0.000000ms /g' | \
sed 's/logs from [0-9]* to [0-9]* */logs from 00000000 to 99999999 /g' | \
sed 's/Plugin booted in [0-9]*.*s */Plugin booted in 00.00s /g' | \
sed 's/random port [0-9]*.\./random port 00000\./g' | \
sed 's/Node was offline for [0-9]*.*[0-9]*.*s/Node was offline for 0.0s/g' | \
grep -e '^\s\[' | sort | uniq -c | while read line
do
    count=$(cut -d '[' -f 1 <<<$line)
    loglevel=$(cut -d '[' -f 2 <<< $line | cut -d ']' -f 1)
    source=$(echo "$line" | rev | cut -d ' ' -f 1 | rev)
    logmsg=$(echo "$line" | awk -F"\[${loglevel}\] " '{print $2}' | awk -F"$source" '{print $1}')

    #Existence check
    exist=$(sqlite3 data/${dbname} "SELECT count(*) FROM logpattern WHERE loglevel = '$loglevel' AND logmsg = '$logmsg' AND source = '$source';")
    if [ "$exist" -eq 0 ]; then
        sqlite3 data/${dbname} \
          "INSERT INTO logpattern(loglevel, logmsg, source, createdat) \
           VALUES('$loglevel', '$logmsg', '$source', '$logdate');"
    fi

    #Aggregate logs
    id=$(sqlite3 data/${dbname} "SELECT id FROM logpattern WHERE loglevel = '$loglevel' AND logmsg = '$logmsg' AND source = '$source';")
    if [ "$id" == "" ]; then
        echo "Error has occured. Key items do not exist in log pattern."
        echo "loglevel: $loglevel"
        echo "logmsg  : $logmsg"
        echo "source  : $source"
    fi

    sqlite3 data/${dbname} \
      "PRAGMA foreign_keys=true; \
       INSERT INTO aggregation(patternid, occurrednumber, logdate) \
       VALUES($id, $count, '$ymd_date');"

done
