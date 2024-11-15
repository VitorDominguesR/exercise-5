#!/bin/bash

# Check if the current user is a superuser, exit if the user is not
# $EUID:  user identity utilized by the system to ascertain process privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

LOG_WARNING_DAYS=3
TODAY_IN_SECONDS=$(date +%s $now)
TODAY_IN_DAYS=$(( $TODAY_IN_SECONDS / 86400 ))


check_user_date_parameters()
{
    if [[ $1 -gt 0 && ! -z $2 && $2 -ne 99999 ]]
    then
        return 0
    else
        return 1
    fi
}

parse_etcshadow()
{   

    # echo "$((TODAY_IN_DAYS + 3))"
    declare -A etcshadow_line_parameters
    etcshadow_content=$(cat /etc/shadow)
    for line in ${etcshadow_content[@]}
    do
        # echo $line
        # replaced * for - because it was giving a strange error list all the files in dir
        line_parameters=($(echo "$line" |sed 's/*/-/g' |sed 's/:/\n/g'))

        # Last password change (in days)
        last_password_change=${line_parameters[2]}
        # Days that password will least before it get expired counting after last password change
        valid_password_max_days=${line_parameters[4]}
        
        # If last_password_change is greater than 0 (password expired) and valid_password_max_days is empty (to validate if the field is filled) 
        # valid_password_max_days is empty (to validate if the field is filled) and is differente from 99999 (special case: user doesnt expire)
        # We consider user to counting expiration days else go to next element
        if [[ $(check_user_date_parameters $last_password_change $valid_password_max_days) -eq 0 ]]
        then
            # First element of /etc/shadow file is the username
            etcshadow_line_parameters['user']=${line_parameters[0]}
            # echo ${line_parameters[@]}

            # the expiration date is:  
            # sum of date created + number of days it will expire since creation
            etcshadow_line_parameters['expiration_date']=$(($last_password_change+$valid_password_max_days))
        else
            continue
        fi
        # echo ${etcshadow_line_parameters[@]}

        # Compare if user's password expiration date is under the estipulated 3 days in exercise 
        if [[ ${etcshadow_line_parameters['expiration_date']} -le $((TODAY_IN_DAYS + $LOG_WARNING_DAYS)) ]]
        then
            # Write in log if user will expire
            days_to_expire=$(( ${etcshadow_line_parameters['expiration_date']} - TODAY_IN_DAYS ))
            echo "[$(date +'%Y-%m-%d %H:%M')] User ${etcshadow_line_parameters['user']} will expire in $days_to_expire day(s)"
        fi
    done
}

# Executes funtion
parse_etcshadow

if [[ $? -ne 0 ]]
then
    echo "$0 dit not execute: error code $?"
fi