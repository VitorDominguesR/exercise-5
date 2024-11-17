#!/bin/bash

# Check if the current user is a superuser, exit if the user is not
# $EUID:  user identity utilized by the system to ascertain process privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Global variables
# declare a global key:pair array
declare -A registered_users
# global to check not registered users
not_registered_users=()
LOG_PATH="/var/log" # Global variable to set the log write path
TODAY_IN_SECONDS=$(date +%s $now) # Needed to get today date in seconds
TODAY_IN_DAYS=$(( $TODAY_IN_SECONDS / 86400 )) # Today date in days

### Functions
function create_users_from_csv()
{
    # $1: CSV input file
    user_csv_data=$(cat $1 | tail -n +2) # Read CSV file from the second line to bottom

    # read: -r Disable backslashes to escape character
    # IFS: Internal file separator. Here we are setting custom separator in order to set the 
    # four variables: user expiredate firstgroup secondgroup
    while IFS=',' read -r user expiredate firstgroup secondgroup; do
        user_groups=($firstgroup $secondgroup)
        # for loop to check if groups exists
        for group in ${user_groups[@]}
        do
            check_group_exists $group # Check if group exists
        done
        #check expiriration date format
        check_valid_format_date $expiredate

        # Check if output from function check_valid_format_date was 0 (Ok)
        if [[ $? -ne 0 ]]; then
            echo "User $user not created: date format is wrong" >> "$LOG_PATH/setup_users.log"
            not_registered_users+=($user)
            # go to the next element
            continue
        fi
        user_expire_date_seconds=$(date +%s -d $expiredate) # convert users expiration date from string to seconds
        user_expire_days=$(( $user_expire_date_seconds / 86400 - $TODAY_IN_DAYS )) # subtract the today date and the date of expiration in csv to set the user expiration date

        if [[ $user_expire_days -lt 0 ]]; then # If its negative it means that the date setted to user's password is no longer valid
            echo "$user password expiration date is less or equal then todays date" >> "$LOG_PATH/setup_users.log" # Write in log the user was not registered
            not_registered_users+=($user) # Append user that was not registered
            continue # go to next while loop element
        fi

        useradd -m -s /bin/bash -g $firstgroup -G $secondgroup $user # add user
        echo "$user:superpassword" | chpasswd # set a password for use (only for test purposes)
        passwd --maxdays $user_expire_days --warndays 7 $user # set expiration date for user based on csv
        registered_users[$user]="$expiredate $firstgroup $secondgroup" # Append user to registered_users array
        
    # <<<: here-string you give a pre-made string of text to a program
    done <<< "$user_csv_data"

}

check_group_exists()
{
    # $1: group name
    if [[ ! -z $(getent group $1) ]]; then # Check if group exists by checking if string is empty or not
        echo "group \"$1\" exists." >> "$LOG_PATH/setup_users.log" # Write log group exists
    else
        echo "group \"$1\" does not exist." >> "$LOG_PATH/setup_users.log" # If group doesnt exists log in file
        echo "Creating..."
        groupadd $1 || echo "Group creation failed" >> "$LOG_PATH/setup_users.log" # Try to create a group, if error print the echo string. After log the output in file
    fi
}

check_valid_format_date()
{
    # $1: date to be checked
    # regex to check string pattern and date command to check if its valid
    if [[ $1 =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ && $(date +%s -d $1) ]]; then # Check regex pattern and if we can convert the date without error
        echo "The input $1 is valid."
        return 0 # If its valid, return ok
    else
        echo "The input $1 is NOT valid." >> "$LOG_PATH/setup_users.log" # write the input is not valid in log
        return 1 # If not ok, return error code
    fi
}
#####


echo "Reading CSV"
create_users_from_csv userslist_add.csv # read and create users from csv

for user in ${!registered_users[@]} # For all registered users write in log data about creation
do 
    # First we get users parameters to print with the users creation message
    # awk: process text using bash
    # awk: $1-> expiration fate; $2->primary group; $3-> second group
    users_parameters=$( echo ${registered_users[$user]} | awk -F' ' '{print "\n\tExpiration Date: " $1"\n\tGroups: " $2 " " $3}')
    echo "$user created: $users_parameters" >> "$LOG_PATH/setup_users.log"
done

echo "Not registered users: ${not_registered_users[@]}" >> "$LOG_PATH/setup_users.log" # Log which users were not registered

# stablish that only root can manage the file
chmod 700 check_userpassword_expiration.sh

# Start cron service
service cron start

echo "Adding script to crontab" >> "$LOG_PATH/setup_users.log" # write step that will write to cronjob

# Schedule  for everydaay at 23:55
# As we are defing this cronjob system wide, we need to specify which user will be used to run the script
echo "55 23 * * * root $(pwd)/check_userpassword_expiration.sh >> /var/log/password_notices.log" >> /etc/crontab
# Every minute (test purpose)
# echo "* * * * * root $(pwd)/check_userpassword_expiration.sh >> $LOG_PATH/password_notices.log" >> /etc/crontab

# Write that the setup script is done
echo "Done !" >> "$LOG_PATH/setup_users.log"