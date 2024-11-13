#!/bin/bash

# Check if the current user is a superuser, exit if the user is not
# $EUID:  user identity utilized by the system to ascertain process privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi


parse_etcshadow()
{   
    today_in_seconds=$(date +%s $now)
    today_in_days=$(( $today_in_seconds / 86400 ))
    # echo "$((today_in_days + 3))"
    declare -A etcshadow_line_parameters
    etcshadow_content=$(cat /etc/shadow)
    for line in ${etcshadow_content[@]}
    do
        # echo $line
        line_parameters=($(echo "$line" |sed 's/*/-/g' |sed 's/:/\n/g'))
        # If line_parameters 2 is greater than 1 and line_parameters 4 is empty (to validate if the field is filled) and line parameter 4
        # is differente from 99999 (special case: user doesnt expire)
        
        if [[ ${line_parameters[2]} -gt 1 && ${line_parameters[4]} != '' && ${line_parameters[4]} -ne 99999 ]]
        then
            etcshadow_line_parameters['user']=${line_parameters[0]}
        # echo ${line_parameters[@]}

            # sum of date created + number of days it will expire since creation
            etcshadow_line_parameters['expiration_date']=$((${line_parameters[2]}+${line_parameters[4]}))
        else
            continue
        fi
        # echo ${etcshadow_line_parameters[@]}

        if [[ ${etcshadow_line_parameters['expiration_date']} -le $((today_in_days + 3)) ]]
        then
            days_to_expire=$(( ${etcshadow_line_parameters['expiration_date']} - today_in_days ))
            echo "[$(date +'%Y-%m-%d %H:%M')] User ${etcshadow_line_parameters['user']} will expire in $days_to_expire day(s)"
        fi
    done
}


parse_etcshadow
