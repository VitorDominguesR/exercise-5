# Exercise 5 - Report

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
today_in_seconds=$(date +%s $now)
today_in_days=$(( $today_in_seconds / 86400 ))
```

`registered_users`: Users that was effective registered in system

`not_registered_users`: User that didnt pass the validations

`LOG_PATH`: Path to log folder

---

For the next step we defined some functions before execute the proper flow to register users

- `create_users_from_csv()`: Registers users based on supplied CSV file
- `check_group_exists()`:  Check if the group exists before create user group (defined in CSV)
- `check_valid_date()`: Check if its a valid date to insert in password expiration (defined in CSV)

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
        check_valid_date $expiredate

        # Check if output from function check_valid_date was 0 (Ok)
        # $?: means the result of the last command, in this case 'check_valid_date'

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
        user_expire_days=$(( $user_expire_date_seconds / 86400 - $today_in_days ))

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