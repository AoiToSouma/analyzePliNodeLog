#!/bin/bash

# Set Colour Vars
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

source .env

function show_msg_list() {
    start=$((page_size * page_num))
    end=$((start + page_size - 1))

    if [[ $end -gt $((msg_count - 1)) ]]; then
        end=$((msg_count - 1))
    fi

    for i in $(seq $start $end); do
        echo "$((i + 1))) ${logmsgs[i]}"
    done
    echo
}

function show_day_list() {
    sqlite3 -header -column data/${dbname} \
" SELECT L.logdate, ID.inactiveday, I.INFO, D.DEBUG, W.WARN, E.ERROR, C.CRIT FROM \
 (SELECT logdate FROM aggregation GROUP BY logdate) as L \
LEFT JOIN\
 (SELECT logdate, SUM(occurrednumber) as INFO FROM aggregation agg \
   INNER JOIN logpattern ptn ON ptn.id = agg.patternid \
   WHERE ptn.loglevel = 'INFO' GROUP BY agg.logdate) as I \
ON L.logdate = I.logdate \
LEFT JOIN \
 (SELECT logdate, SUM(occurrednumber) as DEBUG FROM aggregation agg \
   INNER JOIN logpattern ptn ON ptn.id = agg.patternid \
   WHERE ptn.loglevel = 'DEBUG' GROUP BY agg.logdate) as D \
ON L.logdate = D.logdate
LEFT JOIN \
 (SELECT logdate, SUM(occurrednumber) as WARN FROM aggregation agg \
   INNER JOIN logpattern ptn ON ptn.id = agg.patternid \
   WHERE ptn.loglevel = 'WARN' GROUP BY agg.logdate) as W \
ON L.logdate = W.logdate \
LEFT JOIN \
 (SELECT logdate, SUM(occurrednumber) as ERROR FROM aggregation agg \
   INNER JOIN logpattern ptn ON ptn.id = agg.patternid \
   WHERE ptn.loglevel = 'ERROR' GROUP BY agg.logdate) as E \
ON L.logdate = E.logdate \
LEFT JOIN \
(SELECT logdate, SUM(occurrednumber) as CRIT FROM aggregation agg \
   INNER JOIN logpattern ptn ON ptn.id = agg.patternid \
   WHERE ptn.loglevel = 'CRIT' GROUP BY agg.logdate) as C \
ON L.logdate = C.logdate \
LEFT JOIN \
(SELECT date, '*' as inactiveday FROM inactivedays) as ID
ON L.logdate = ID.date
;"
}

function show_newly_log() {
    echo -e "${YELLOW}"
    echo "Enter search conditions."
    echo -e "log date format is YYYY-MM-DD${NC}"
    read -p "Input log date to extract: " logdate
    echo

    sqlite3 -header -column data/${dbname} \
    "SELECT loglevel, logmsg, source, createdat FROM logpattern WHERE date(createdat) >= date('${logdate}');"
}

function show_log_by_day() {
    echo -e "${YELLOW}"
    echo "Enter search conditions."
    echo -e "log date format is YYYY-MM-DD${NC}"
    read -p "Input log date to extract: " logdate
    echo
    sqlite3 -header -column data/${dbname} \
    -cmd '.width 6 110 20 10' \
    "SELECT ' '||ptn.loglevel as level, ptn.logmsg, ptn.source, agg.occurrednumber as number \
       FROM logpattern ptn \
      INNER JOIN aggregation agg \
         ON ptn.id = agg.patternid \
      WHERE agg.logdate = '$logdate';"
}

function show_log_by_msg() {
    loglevels=($(sqlite3 data/${dbname} "SELECT DISTINCT loglevel FROM logpattern;"))
    level_count=$((${#loglevels[@]} -1))
    last_count=${#loglevels[@]}
    echo -e "${YELLOW}"
    echo "loglevel LIST"
    echo "=========================================="
    for i in $(seq 0 $level_count)
    do
        echo "$((i + 1))) ${loglevels[i]}"
    done
    echo
    echo "q) quit"
    echo -e "==========================================${NC}"
    while true; do
        read -p "Select loglevel: " choice
        if [ $choice == "q" ]; then
            echo "Processing ends."
            exit
        elif [[ $choice =~ ^[1-${last_count}]$ ]]; then
            selected_index=$((choice - 1))
            loglevel=${loglevels[${selected_index}]}
            break
        else
            echo -e "${RED}Invalid input${NC}"
            echo
            continue
        fi
    done

    IFS=$'\n'
    logmsgs=($(sqlite3 data/${dbname} "SELECT DISTINCT logmsg FROM logpattern WHERE loglevel = '${loglevel}' order by logmsg;"))
    msg_count=${#logmsgs[@]}
    page_size=10
    page_num=0

    while true; do
        goback=false
        gonext=false
        echo -e "${YELLOW}[${loglevel}] Message List  (Page No. $((page_num + 1)))"
        echo "=========================================="
        show_msg_list
        if [[ $page_num -eq $((msg_count / page_size)) ]]; then
            if [ $page_num -ne 0 ]; then
                goback=true
                echo "p) previous page"
            fi
            echo "q) quit"
        else
            if [ $page_num -ne 0 ]; then
                goback=true
                echo "p) previous page"
            fi
            gonext=true
            echo "n) next page"
            echo "q) quit"
        fi
        echo -e "==========================================${NC}"
        read -p "Select message: " choice
        echo
        if [ $choice == "q" ]; then
            echo "Processing ends."
            exit
        elif "$goback"  && [ $choice == "p" ]; then
            page_num=$((page_num - 1))
        elif "$gonext"  && [ $choice == "n" ]; then
            page_num=$((page_num + 1))
        elif [[ $choice =~ ^[0-9]+$ ]]; then
            selected_index=$((choice - 1))
            if [ "${logmsgs[${selected_index}]}" == "" ]; then
                echo -e "${RED}Invalid input${NC}"
                echo
                continue
            fi
            logmsg="${logmsgs[${selected_index}]}"
            break
        else
            echo -e "${RED}Invalid input${NC}"
            echo
            continue
        fi
    done

    echo -e "${YELLOW}[Search conditions]----------------------------------------"
    echo "[${loglevel}] ${logmsg}"
    echo -e "-----------------------------------------------------------${NC}"

    sqlite3 -header -column data/${dbname} \
    "SELECT agg.logdate, ptn.source, agg.occurrednumber \
       FROM logpattern ptn \
      INNER JOIN aggregation agg \
         ON ptn.id = agg.patternid \
      WHERE ptn.loglevel = '${loglevel}' \
        AND ptn.logmsg = '${logmsg}';"
}

case "$1" in
    daylist)
        show_day_list
        ;;
    newlylog)
        show_newly_log
        ;;
    byday)
        show_log_by_day
        ;;
    bymsg)
        show_log_by_msg
        ;;
    *)
        echo
        echo "Usage: $0 {function}"
        echo
        echo " where {option} is one of the following;"
        echo "  daylist  == Display a list of log collection dates."
        echo "  newlylog == Display newly generated logs after specified date."
        echo "  byday    == Display aggregation of messages for specified date."
        echo "  bymsg    == Display daily occurrences of specified messages."
        echo
        exit
esac
