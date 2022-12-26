# geocint-runner

## geocint processing pipeline

Geocint is Kontur's open source geodata ETL/CI/CD pipeline designed for ease of maintenance and high single-node throughput. Writing
the code as Geocint target makes sure that it is fully recorded, can be run autonomously, can be inspected, reviewed and
tested by other team members, and will automatically produce new artifacts once new input data comes in.

### Geocint structure:

Geocint consists of 3 different parts:
- [geocint-runner](https://github.com/konturio/geocint-runner) - a core part of the pipeline, includes utilities and initial Makefile
- [geocint-openstreetmap](https://github.com/konturio/geocint-runner) - a chain of targets for downloading, updating and uploading 
to database OpenStreetMap planet dump
- [geocint-private] any repository that contains your additional functionality

![image](https://user-images.githubusercontent.com/810638/209176952-826382d6-35bc-469a-adaa-ef265cfdd9ac.png)

### Technology stack:

- A high-performance computer. OS:the latest Ubuntu version (not necessarily LTS).
- Bash (Linux shell) is used for scripting one-liners that get data into the database for further processing or get data out of the database for deployment. 
https://tldp.org/LDP/abs/html/
- GNU Make is used as job server. We do not use advanced features like variables and wildcards, using simple explicit
  "file-depends-on-file" mode. Make takes care of running different jobs concurrently whenever possible.
  https://makefiletutorial.com/
- make-profiler is used as linter and preprocessor for Make that outputs a network diagram of what is getting built when
  and why. The output chart allows to see what went wrong and quickly get to logs.
  https://github.com/konturio/make-profiler
- PostgreSQL (latest stable version) for data manipulation. No replication, minimal WAL logging, disabled synchronous_commit
  (fsync enabled!), parallel costs tuned to prefer parallel execution whenever possible. To facilitate debugging
  auto_explain is enabled, and you can find slow query plans in Postgres’ log files. log files. When you need to make it faster,
  follow https://postgrespro.ru/education/courses/QPT
- GNU Parallel is used for paralleling tasks that cannot be effectively paralleled by Postgres, essentially parallel-enabled
  Bash. https://www.gnu.org/software/parallel/parallel.html
- PostGIS (latest unreleased master) for geodata manipulation. Kontur has maintainers for PostGIS in the team so you can
  develop or ask for features directly. https://postgis.net/docs/manual-dev/reference.html
- h3_pg for hexagon grid manipulation, https://github.com/bytesandbrains/h3-pg. When googling for manuals make sure you
  use this specific extension.
- aws-cli is used to deploy data into s3 buckets or get inputs from there. https://docs.aws.amazon.com/cli/index.html
- python is used for small tasks like unpivoting source data.
- GDAL, OGR, osm-c-tools, osmium, and others are used if they are needed in Bash CLI.


[Install, first run guides and best practices](DOCUMENTATION.md) 

### Directory and file structure:

- [start_geocint.sh](start_geocint.sh) - script, that runs the pipeline: checking required packages, cleaning targets and
  posting info messages
- [runner_install.sh](runner_install.sh) - script, that runs installation of required packages of geocint-runner part
- [config.inc.sh.sample](config.inc.sh.sample) - sample config file
- [Makefile](Makefile) - map dependencies between data generation stages
- [your_make.sample](your_make.sample) - sample make file that shows how to integrate geocint-runner, 
geocint-openstreetmap and your own chains of targets
- [functions/](functions) - service SQL functions, used in more than one other file
- [procedures/](procedures) - service SQL procedures, used in more than one other file
- [scripts/](scripts) - scripts that perform data transformation on top of table without creating new table
- [tables/](tables) - SQL which generates a table with the same name as the script
- [static_data] - static file-based data stored in geocint repository

Сreated automatically when launching targets
- [data/](data) - file-based input and output data 
    - data/in - all input data, downloaded elsewhere
    - data/in/raster - all downloaded geotiffs
    - data/mid - all intermediate data (retiles, unpacks, reprojections and etc) which can be removed after
      each launch
    - data/out - all generated final data (tiles, dumps, unloading for the clients and etc)
- [db/](db) - files - makefile mark about executing "db/..." targets
- [deploy/](deploy) - files - makefile mark about executing "deploy/..." targets

### How to install geocint

1. Create your repository to store your own part of the pipeline.
Your repository should contain the following required files:
- README.md (could be empty, just make sure that it exists)
- install.sh (use [runner-install.sh](runner-install.sh) as an example, store installation of your additional dependencies)
- your_make (use [private_make.sample](your_make.sample) as an example; keep in mind that make shouldn't be named "Makefile",
use the other name to keep compatibility with geocint-runner repository)

2. Create a new user with sudo permissions (the default user is "gis"). Keep in mind that the best practice is to use this user name 
for creating a Postgres role and database. Path ~/ is equivalent to /home/your_user/. This folder is a working directory for the geocint pipeline.

3. Clone 3 repository (geocint-runner, geocint-openstreetmap, your repo) to ~/ 

4. Copy [config.inc.sh.sample](config.inc.sh.sample) from geocint-runner to ~/ and set variables:
```shell
  cp ~/geocint-runner/config.inc.sh.sample ~/config.inc.sh
```
  set the necessary values of variables.

5. Add slack integrations:
  * install pip - 
```shell
sudo apt install -y python3-pip
```
  * install slack packages - 
```shell
sudo pip3 install slack slackclient
```
  * test slack integration - set env variable SLACK_KEY - 
```shell
  export SLACK_KEY=your_slack_integration_key
```
  * echo "Test slack integration" | python3 scripts/slack_message.py your_slack_channel your_server raccoon

6. Set crontab for autostarting pipeline
  * add SLACK_KEY=your_slack_integration_key to crontab settings, to avoid errors when slack_key doesn't exist
  * set if you want to run your pipeline at half past 5 am add this row:
  * /5 * * * /bin/bash /home/gis/geocint-runner/start_geocint.sh > /home/gis/geocint/log.txt
  * Keep in mind that time on your local machine and on your server can be different.

7. Run ~/geocint-runner/runner_install.sh (necessary dependencies to run runner part)

8. Add connection settings to the pg_hba.conf

``shell
sudo nano /etc/postgresql/14/main/pg_hba.conf
```

`local   gis +geocint_users  trust`

9. Create postgresql role and create postgresql extensions:
```shell
    sudo -u postgres psql
    create role gis login;
    create database gis owner gis;
    \c gis
    create extension postgis;
    create extension postgis_raster;
    create extension postgis_sfcgal;
    create extension postgis_topology;
    create extension h3;
    create extension h3_postgis;
    -- create any additional extension, that you need
```
10. Run the pipeline manually, or set the necessary time in crontab
```shell
    /bin/bash /home/gis/geocint-runner/start_geocint.sh > /home/gis/geocint/log.txt
```

### Geocint deployment best practices:

#### Things to avoid:

- Files with the same name and the same nesting level as files in geocint-runner and geocint-openstreetmap 
repositories. This limitation does not apply to folders.
- Views and materialized views.
- Complex python scripts should become less complex bash+sql scripts.
- Comments for targets, containing double quote characters (")

#### Organizational points:

- Make sure you have source data always available. Do not store it locally on geocint - add a target to download data
  from S3 at least.
- Try to run the pipeline at least once on your test branch, or create a simple short makefile for test_* tables in a
  separate folder and run it, avoiding effect on running pipeline.

#### Technical details for **code review** checks:

- Make sure your scripts (especially bash, ansible) are working as a part of Makefile, not only by themselves.
- Idempotence: how will it run the first time? Second time? 100 times?
    - copying of non-existing yet files
    - deleting or renaming functions and procedures, especially when you change the number or order of parameters
    - try to use drop/alter database_object IF EXIST
- Does your target need to be launched every day? Don’t forget to put it into the Clean one. Or make it manually
  (see Cache invalidation).
- If you replace one target with another one, make sure to delete unused one everywhere (especially dev/prod targets)
- Updates on tables should be a part of the target, where these tables are created, for not updating something twice.

#### After-Merge duties. Share them and your progress with teammates.

- Cache invalidation: manual clean of currently updated but existing targets
- Delete local/S3 files and DB objects that you don’t need anymore

### Slack messages

The geocint pipeline should send messages to the Slack channel. Create a channel, generate Slack token
and store it in the `SLACK_KEY` variable in file `$HOME/.profile`.

```shell
export SLACK_KEY=<your_key>
```

### User schemas

User schemas can be used for separate pipeline and dev data.
Run [scripts/create_geocint_user.sh](scripts/create_geocint_user.sh) to initialize the user schema.

`sudo scripts/create_geocint_user.sh [username]`

Script for adding user role and schema to geocint database. If no username is provided, it will be prompted. User roles
are added to the geocint_users group role. You need to add the following line to pg_hba.conf.

`local   gis +geocint_users  trust`

### How to analyse build time for tables

Logs for every build are stored in `/home/gis/geocint/logs`

This command can show lastN {*Total times in ms*} for some {*tablename*} ordered by date

```bash
cd /home/gis/geocint/logs
find . -type f -regex ".*/db/table/osm_admin_boundaries/log.txt" -mtime -50 -printf "%T+ %p; " -exec awk '/Time:/ {sum += $4} END {print sum/60000 " min"}' '{}' \; | sort
```

`-mtime -50` - collects every row from 50 days ago to now

`-regex ".*/db/table/osm_admin_boundaries/log.txt"` - change `osm_admin_boundaries` to your {*tablename*}
