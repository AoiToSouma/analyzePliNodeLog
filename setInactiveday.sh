#!/bin/bash

source .env

if [ $# = 0 ]; then
    echo "Usage: $0 YYYY-MM-DD"
    exit
fi

inactiveday=$(sqlite3 data/${dbname} "SELECT logdate FROM aggregation WHERE logdate = '$1';")
if [ "$inactiveday" == "" ]; then
    echo "Invalid Date or unregistered date."
    exit
fi

exist=$(sqlite3 data/${dbname} "SELECT date FROM inactivedays WHERE date = '$1';")
if [ $? -eq 0 ]; then
    echo "Date already registered."
    exit
fi


sqlite3 data/${dbname} \
"INSERT INTO inactivedays(date) VALUES('$1');"
