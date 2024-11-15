# Exercise 5 - Report

## Objective

The objective of this exercise is creating a cronjob that log in a file named `password_notices.log` **every day at 23:55** if an user's password will expire within 3 days or less.

## Method

The exercise is divided in two scripts and one input file: `setup.sh`, `check_userpassword_expiration.sh` and `userslist_add.csv`

This division allows us to setup the environment in an automated way.

`setup.sh` will register the users from `userlist_add.csv` and register `check_userpassword_expiration.sh` in cronjon (system-wide) to run **every day at 23:55**

`check_userpassword_expiration.sh` caontains the logic to parse /etc/shadow and check if the user's password is about to expire

`userlist_add.csv` contains a list of users (valids and invalids)

We decided to create this log file in `/var/log` because some programs uses this folder as a default location to write log files, but thats a parameter that could be easily modified in `setup.sh`


## setup.sh

First of all, we created a script to setup the environment with the proper setup to execute our cron job successfully. This script has consumes a csv file containing the following fields:

- `user`: username that will be setted for a user
- `expiredate`: Expiration date that will be setted to the users password
- `firstgroup`: The primary group of the user
- `secondgroup`: The secondary/complementary group of the user

This script should run with elevated privilege because we need to perform operations that includes/modifies users,passwords and crontab entries.

To ensure that this requirement is fulfilled, we inserted this code in the begining of the script:

```bash
if [ "$EUID" -ne 0 ]; then # Check the Effective ID 
    echo "Please run as root"
    exit 1
fi
```
The Effective UID ($EUID) is the user ID that is running the script. When runned with high privilege, the EUID should be 0. (root privilege)

The comparison operator `-ne` means `not equal`. It means 


---

After this, we delcared some **Global variables** that we will need to log the script action into a file

```bash
# Global variables
# declare a global key:pair array
declare -A registered_users
# global to check not registered users
not_registered_users=()
LOG_PATH="/var/log"
# This part we will convert the today's date from seconds to days
# This will be important to setup the user's password expiration date
TODAY_IN_SECONDS=$(date +%s $now)
TODAY_IN_DAYS=$(( $TODAY_IN_SECONDS / 86400 ))
```

`registered_users`: Users that was effective registered in system

`not_registered_users`: User that didnt pass the validations

`LOG_PATH`: Path to log folder

---

For the next step we defined some functions before execute the proper flow to register users

- `create_users_from_csv()`: Registers users based on supplied CSV file
- `check_group_exists()`:  Check if the group exists before create user group (defined in CSV)
- `check_valid_format_date()`: Check if its a valid date to insert in password expiration (defined in CSV)

**create_users_from_csv**

```bash
function create_users_from_csv()
{


    # Here we read from CSV supplied as an argumento to the function
    # $1: CSV input file
    # the flag -n +2 means 'read from the second line to end'
    user_csv_data=$(cat $1 | tail -n +2)

    # read: -r Disable backslashes to escape character
    # IFS: Internal file separator. Here we are setting custom separator in order to set the 
    # four variables: user expiredate firstgroup secondgroup
    # This loop receives a here-string as input, this string is the user_csv_data
    while IFS=',' read -r user expiredate firstgroup secondgroup; do
        
        # Here we created an array with the groups to check if they already exists
        user_groups=($firstgroup $secondgroup)
        # for loop to check if groups exists
        for group in ${user_groups[@]}
        do
            # Function that checks if the group alread exists, and if not, create the group
            check_group_exists $group
        done
        #Here we check the input expiriration date from CSV
        check_valid_format_date $expiredate

        # Check if output from function check_valid_format_date was 0 (Ok)
        # $?: means the result of the last command, in this case 'check_valid_format_date'

        if [[ $? -ne 0 ]]; then

            # In this line we log if the users was not created and register it into a log
            echo "User $user not created: date format is wrong" >> "$LOG_PATH/setup_users.log"
            # Here we add the user to an array to check which users were not registered
            not_registered_users+=($user)
            # go to the next element
            continue
        fi
        # echo $expiredate
        # useradd -m -s /bin/bash -g $firstgroup -G $secondgroup --password $(openssl rand -base64 12) $user

        # In this block, we convert the user's password expiration date from string to seconds and after this, days
        # The logic is subtract the today's date (in days) from user's expiration date (in days) to set it in 
        # password expiration 
        user_expire_date_seconds=$(date +%s -d $expiredate)
        user_expire_days=$(( $user_expire_date_seconds / 86400 - $TODAY_IN_DAYS ))

        # This condition checks if the user has an expiration date before the today's date
        if [[ $user_expire_days -lt 0 ]]; then
            echo "$user password expiration date is less or equal then todays date" >> "$LOG_PATH/setup_users.log"
            not_registered_users+=($user)
            continue
        fi

        # If al the checks are ok, we add the user with bash shell, home directory, first and secondary groups
        useradd -m -s /bin/bash -d /home/$user -g $firstgroup -G $secondgroup $user

        # Here we define a password to user, its an insecure way and very weak password, but it is just for demonstration purposes
        echo "$user:superpassword" | chpasswd

        # Here we set the expiration for the date defined in CSV with an warning 7 days before expire
        passwd --maxdays $user_expire_days --warndays 7 $user

        # Here we append the user to registered_users array to log the information 
        registered_users[$user]="$expiredate $firstgroup $secondgroup"
        
    # <<<: here-string you give a pre-made string of text to a program
    done <<< "$user_csv_data"
    
}
```

```bash
check_group_exists()
{
    # In this function, we check either if the group exists or not and create it
    # $1: group name
    # getent: search a key in a database
    # getent group $1: retrieve /etc/groups line regarding given group and check if its not empty) 
    if [[ ! -z $(getent group $1) ]]; then
        # Log if the group already exists
        echo "group \"$1\" exists." >> "$LOG_PATH/setup_users.log"
    else
        # Log if group does not exists
        echo "group \"$1\" does not exist." >> "$LOG_PATH/setup_users.log"
        echo "Creating..."
        # Create if no error or log that it failed
        groupadd $1 || echo "Group creation failed" >> "$LOG_PATH/setup_users.log"
    fi
}
```

```bash
check_valid_format_date()
{
    # $1: date to be checked
    # regex to check string pattern and date command to check if its valid
    # Both condition should be fulfilled
    if [[ $1 =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ && $(date +%s -d $1) ]]; then
        # Return 0 (ok code)
        echo "The input $1 is valid."
        return 0
    else
        # Return code 1 (Not ok)
        echo "The input $1 is NOT valid." >> "$LOG_PATH/setup_users.log"
        return 1
    fi
}
```

The next step in setup script is actually run the logic to register the test users and add the job in crontab file

```bash

# Warning about the process started
echo "Reading CSV"

# Execute the process of register users from CSV
create_users_from_csv userslist_add.csv

# Loop to print in console users that was succefullyu registrated and log into a file
for user in ${!registered_users[@]}
do 
    # First we get users parameters to print with the users creation message
    # awk: process text using bash
    # awk: $1-> expiration fate; $2->primary group; $3-> second group
    users_parameters=$( echo ${registered_users[$user]} | awk -F' ' '{print "\n\tExpiration Date: " $1"\n\tGroups: " $2 " " $3}')
    echo "$user created: $users_parameters" >> "$LOG_PATH/setup_users.log"
done

# Print users that were not registered successfully into OS
echo "Not registered users: ${not_registered_users[@]}" >> "$LOG_PATH/setup_users.log"

# stablish that only root can manage the file for security purposes
chmod 700 check_userpassword_expiration.sh

# Start cron service
service cron start

echo "Adding script to crontab" >> "$LOG_PATH/setup_users.log"

# Schedule  for everydaay at 23:55
# As we are defing this cronjob system wide, we need to specify which user will be used to run the script
# We could give to a system user that has high privileges and no password in order to make it more secure
# echo "55 23 * * * root $(pwd)/check_userpassword_expiration.sh >> /var/log/password_notices.log" >> /etc/crontab
# Every minute (test purpose)
echo "* * * * * root $(pwd)/check_userpassword_expiration.sh >> $LOG_PATH/password_notices.log" >> /etc/crontab

# Write that process was done, indicating that steps above were performed
echo "Done !" >> "$LOG_PATH/setup_users.log"
```

## check_userpassword_expiration.sh

This next script will be the one that will be added to cronjob to execute.

Here we have a simple function that will execute all the necessary flow.

First we start with the same code block that require us to run as root.

```bash
# Check if the current user is a superuser, exit if the user is not
# $EUID:  user identity utilized by the system to ascertain process privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi
```
Then we define a constant to set the expiration days check interval from today's date.
As the exercise instructed, we setted to 3 days before expiration

Here we had to use the today's date in days for the same purpose as before

```bash
LOG_WARNING_DAYS=3
TODAY_IN_SECONDS=$(date +%s $now)
TODAY_IN_DAYS=$(( $TODAY_IN_SECONDS / 86400 ))
```

Now we defined a function to make the code more readable when execute the validation check

The function perform the following comparisons:

- `Last Password Change` (in /etc/passwd) is not a special case
- If `Max Password Days` is not empry and does expire

You can see that is and AND condition and all three should be True in order to continue the script

```bash
check_user_date_parameters()
{
    if [[ $1 -gt 0 && ! -z $2 && $2 -ne 99999 ]]
    then
        return 0
    else
        return 1
    fi
}
```

Following in the script, we define the function that will perform the check
```bash
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
```

And finishing the exercise we execute the function `parse_etcshadow` and check if there was any errors executing the previous script 

```bash
# Executes funtion
parse_etcshadow

if [[ $? -ne 0 ]]
then
    echo "$0 dit not execute: error code $?"
fi
```

## Proof-of-Concept

TBD