#!/bin/bash

# Check if the current user is a superuser, exit if the user is not
# $EUID:  user identity utilized by the system to ascertain process privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# read csv to add users and groups
# Check if group exists
# add user to groups with expiration dates
# check expiration dates
# add to crontab

# declare a global key:pair array
declare -A registered_users
# global to check not registered users
not_registered_users=()


function create_users_from_csv()
{
    today_in_seconds=$(date +%s $now)
    today_in_days=$(( $today_in_seconds / 86400 ))
    # $1: CSV input file
    user_csv_data=$(cat $1 | tail -n +2)

    # read: -r Disable backslashes to escape character
    # IFS: Internal file separator. Here we are setting custom separator in order to set the 
    #four variables: user expiredate firstgroup secondgroup
    while IFS=',' read -r user expiredate firstgroup secondgroup; do
        user_groups=($firstgroup $secondgroup)
        # for loop to check if groups exists
        for group in ${user_groups[@]}
        do
            # echo $group
            check_group_exists $group
        done
        #check expiriration date format
        check_date_format $expiredate

        # Check if output from funtion was 0 (Ok)
        if [[ $? -ne 0 ]]; then
            echo "User $user not created: date format is wrong"
            not_registered_users+=($user)
            # go to the next element
            continue
        fi
        # echo $expiredate
        # useradd -m -s /bin/bash -g $firstgroup -G $secondgroup --password $(openssl rand -base64 12) $user
        user_expire_date_seconds=$(date +%s -d $expiredate)
        user_expire_days=$(( $user_expire_date_seconds / 86400 - $today_in_days ))
        useradd -m -s /bin/bash -g $firstgroup -G $secondgroup $user
        echo "$user:superpassword" | chpasswd
        passwd --maxdays $user_expire_days --warndays 7 $user
        registered_users[$user]="$expiredate $firstgroup $secondgroup"
        
    # <<<: here-string you give a pre-made string of text to a program
    done <<< "$user_csv_data"
    
    # echo ${!registered_users[@]}

}

check_group_exists()
{
    # $1: group name
    if [ $(getent group $1) ]; then
        echo "group \"$1\" exists."
    else
        echo "group \"$1\" does not exist."
        echo "Creating..."
        groupadd $1 || echo "Group creation failed"
    fi
}

check_date_format()
{
    # $1: date to be checked
    # regex to check string pattern and date command to check if its valid
    if [[ $1 =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ && $(date +%s -d $1) ]]; then
        echo "The input $1 is in the yyyy-mm-dd date format."
        return 0
    else
        echo "The input is NOT in the yyyy-mm-dd date format."
        return 1
    fi
}

echo "Reading CSV"
create_users_from_csv userslist_add.csv

for user in ${!registered_users[@]}
do 
    # First we get users parameters to print with the users creation message
    # awk: process text using bash
    # awk: $1-> expiration fate; $2->primary group; $3-> second group
    users_parameters=$( echo ${registered_users[$user]} | awk -F' ' '{print "\n\tExpiration Date: " $1"\n\tGroups: " $2 " " $3}')
    echo "$user created: $users_parameters"
done

echo "Not registered users: ${not_registered_users[@]}"

service cron start

echo "Adding script to crontab"

# Schedule  for everydaay at 23:55 
# echo "55 23 * * * $(whoami) $(pwd)/check_userpassword_expiration.sh >> /var/log/password_notices.log" >> /etc/crontab
# Every minute (test purpose)
echo "* * * * * $(whoami) $(pwd)/check_userpassword_expiration.sh >> /var/log/password_notices.log" >> /etc/crontab
