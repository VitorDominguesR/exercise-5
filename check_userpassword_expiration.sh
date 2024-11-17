#!/bin/bash

# Check if the current user is a superuser, exit if the user is not
# $EUID:  user identity utilized by the system to ascertain process privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

LOG_WARNING_DAYS=3 # days that will warn in advance
TODAY_IN_SECONDS=$(date +%s $now) # Needed to get today date in seconds
TODAY_IN_DAYS=$(( $TODAY_IN_SECONDS / 86400 )) # Today date in days


check_user_date_parameters()
{
    if [[ $1 -gt 0 && ! -z $2 && $2 -ne 99999 ]] # Check if last_password_change is greater than 0 (special case) and if valid_password_max_days is not 99999 (not expire) or empty 
    then
        return 0 # Return Ok
    else
        return 1 # Return Error
    fi
}

parse_etcshadow()
{   

    # echo "$((TODAY_IN_DAYS + 3))"
    # Define an array with key:pair values to split values from etc/shadow line
    declare -A etcshadow_line_parameters
    # Read /etc/shadow and store in etcshadow_content
    etcshadow_content=$(cat /etc/shadow)
    # Loop for read each line of /etc/shadow
    for line in ${etcshadow_content[@]}
    do
        # echo $line and redirect to sed 
        # replaced * for - because it was giving a strange error list all the files in dir
        # replace : for \n because it will be considered a separator for bash
        line_parameters=($(echo "$line" |sed 's/*/-/g' |sed 's/:/\n/g'))

        # Last password change (in days)
        last_password_change=${line_parameters[2]}
        # Days that password will least before it get expired counting after last password change
        valid_password_max_days=${line_parameters[4]}
        
        # If last_password_change is greater than 0 (password expired) and valid_password_max_days is empty (to validate if the field is filled) 
        # valid_password_max_days is empty (to validate if the field is filled) and is differente from 99999 (special case: user doesnt expire)
        # We consider user to counting expiration days else go to next element
        if check_user_date_parameters $last_password_change $valid_password_max_days
        then
            # First element of /etc/shadow file is the username
            # We define key user for etcshadow_line_parameters with value of the first parameter (username)
            etcshadow_line_parameters['user']=${line_parameters[0]}

            # the expiration date is:  
            # sum of date created + number of days it will expire since creation, we will get the expiration date in days
            etcshadow_line_parameters['expiration_date']=$(($last_password_change + $valid_password_max_days))
        else
            continue # if check_user_date_parameters is not ok, go to the next element
        fi

        # Compare if user's password expiration date is under the estipulated 3 days in exercise 
        if [[ ${etcshadow_line_parameters['expiration_date']} -le $((TODAY_IN_DAYS + $LOG_WARNING_DAYS)) ]]
        then
            # Write in log if user will expire within 3 days
            days_to_expire=$(( ${etcshadow_line_parameters['expiration_date']} - TODAY_IN_DAYS ))
            echo "[$(date +'%Y-%m-%d %H:%M')] User ${etcshadow_line_parameters['user']} will expire in $days_to_expire day(s)"
        fi
    done
}

# Executes funtion
parse_etcshadow
