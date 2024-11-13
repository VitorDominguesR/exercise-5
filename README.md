# exercise-5

# Flow

`setup.sh:`

    - create users
    - register job in cronjob (system-wide)

`create_users_from_csv`: create users reading csv userlist_add.csv

`check_group_exists`: check if group exists before create

`check_date_format`: check if date format is write to stablish a standard

`check_userpassword_expire.sh`:

    - Parses etc/shadow
    - Check if password will expire within 3 days or less
    - Write information in log

# How to run

needs to install `docker`

`DOCKER_BUILDKIT=1 docker build --progress=plain -t exercise5:git -f Dockerfile .`

`docker run --rm -it --entrypoint bash exercise5:git`

May need to run inside container `service cron start`