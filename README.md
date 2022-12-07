# geocint-runner

## geocint processing pipeline

Geocint is is an open source Kontur's geodata ETL/CI/CD pipeline designed for ease of maintenance and high single-node throughput. Writing
the code as Geocint target makes sure that it is fully recorded, can be run autonomously, can be inspected, reviewed and
tested by other team members, and will automatically produce new artifacts once new input data comes in.

### Geocint structure:

Geocint consists from 3 different parts:
- [geocint-runner](https://github.com/konturio/geocint-runner) - core part of pipeline, includes utilites and initial Makefile
- [geocint-openstreetmap](https://github.com/konturio/geocint-runner) - chain of targets for downloading, updating and loading 
  to database OpenStreetMap planet dump
- [geocint-private] any repository that contains your additional functionality

### Technology stack is:

- Huge bare metal machine. High CPU count, high memory, large industrial SSD. All further stack is tuned for this
  specific machine, not some abstract one. OS is latest Ubuntu version (not necessarily LTS).
- Bash (linux shell) for scripting one-liners that get data into the database for further processing, or get data out of
  the database for deployment. https://tldp.org/LDP/abs/html/
- GNU Make as job server. We do not use advanced features like variables and wildcards, using simple explicit
  "file-depends-on-file" mode. Make takes care of running different jobs concurrently whenever possible.
  https://makefiletutorial.com/
- make-profiler is used as linter and preprocessor for Make that outputs network diagram of what is getting built when
  and why. The output chart allows to see what went wrong and quickly get to logs.
  https://github.com/konturio/make-profiler
- Postgres (latest stable) for data manipulation. No replication, minimal WAL logging, disabled synchronous_commit
  (fsync enabled!), parallel costs tuned to prefer parallel execution whenever possible. To facilitate debugging
  auto_explain is enabled, you can find slow query plans in postgresql's log files. When you need to make it faster,
  follow https://postgrespro.ru/education/courses/QPT
- GNU Parallel for paralleling tasks that cannot be effectively paralleled by Postgres, essentially parallel-enabled
  Bash. https://www.gnu.org/software/parallel/parallel.html
- PostGIS (latest unreleased master) for geodata manipulation. Kontur has maintainers for PostGIS in team so you can
  develop or ask for features directly. https://postgis.net/docs/manual-dev/reference.html
- h3_pg for hexagon grid manipulation, https://github.com/bytesandbrains/h3-pg. When googling for manuals make sure you
  use this specific extension.
- aws-cli is used to deploy data into s3 buckets or get inputs from there. https://docs.aws.amazon.com/cli/index.html
- python3 for small tasks like unpivoting source data.
- GDAL, OGR, osm-c-tools, osmium, and others are used as needed in Bash CLI.

### Directory and files structure:

- [start_geocint.sh](start_geocint.sh) - script, that runs the pipeline: checking dependencies, cleaning targets and
  posting info messages
- [runner_install.sh](runner_install.sh) - script, that runs installation of dependencies of geocint-runner part
- [congig.inc.sh.sample](config.inc.sh.sample) - sample config file
- [Makefile](Makefile) - maps dependencies between generation stages
- [your_make.sample](your_make.sample) - sample make file that shows how to integrate geocint-runner and 
geocint-openstreetmap parts with your own targets
- [functions/](functions) - service SQL functions, used in more than a single other file
- [procedures/](procedures) - service SQL procedures, used in more than a single other file
- [scripts/](scripts) - scripts that perform transformation on top of table without creating new one
- [tables/](tables) - SQL that generates a table named after the script
- [static_data] - static file-based data stored in geocint repository
Сreated automatically when launching targets
- [data/](data) - file-based input and output data 
    - data/in - all input data, downloaded elsewhere
    - data/in/raster - all downloaded geotiffs
    - data/mid - all intermediate data (retiles, unpacks, reprojections and etc) which can removed after
      each launch
    - data/out - all generated final data (tiles, dumps, unloading for the clients and etc)
- [db/](db) - files - makefile mark about executing "db/..." targets
- [deploy/](deploy) - files - makefile mark about executing "deploy/..." targets

### How to install geocint

1. Create your repository to store your own part of pupeline.
Your repository should contain next required files:
- README.md (could be empty, just make sure if it exists)
- install.sh (use [runner_install.sh](runner_install.sh) as an example, store installation of your additional dependencies)
- your_make (use [private_make.sample](your_make.sample) as an example; take at look that make shouldn't be named "Makefile",
use another one name to keep compatibility with geocint-runner repository)

2.Create a new user with sudo permisions (dufault user is gis).
Take at look, that the best practise is to use this user name for creation postgres role and database.
Path ~/ is an equivalent to /home/your_user/. This folder is a working directory for geocint pipeline.

2. Clone 3 repository (geocint-runner, geocint-openstreetmap, your repo) to ~/ 

3. Copy [congig.inc.sh.sample](config.inc.sh.sample) from geocint-runner to root and set variables:
```shell
  cp ~/geocint-runner/config.inc.sh.sample ~/config.inc.sh
```
  set necessary values of variables.

4. Add slack integrations:
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

5. Set crontab for autostarting pipeline
  * add SLACK_KEY=your_slack_integration_key to crontab settings, to avoid errors when slack_key doesn't exist
  * setif you want to run your pipeline at half past 5 am add this row:
  * /5 * * * /bin/bash /home/gis/geocint-runner/start_geocint.sh > /home/gis/geocint/log.txt
  * Take a look that time on your local mashine and on your server can be different (thorough time belts).

6. Run ~/geocint-runner/runner_install.sh (necessary dependencies to run runner part)

7. Add connection settings to the pg_hba.conf
`local   gis +geocint_users  trust`

6. Greate postgres role and create postgresql extensions:
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
7. Run pipeline manually, or set necessary time in crontab
```shell
    /bin/bash /home/gis/geocint-runner/autostart_geocint.sh > /home/gis/geocint/log.txt
```

### Geocint deployment best practices:

#### Things to avoid:

- Don't create files with the same name and the same nesting level as files in geocint-runner and geocint-openstreetmap 
repositories. This does not apply to folders.
- Views and materialized views.
- Complex python scripts should become less complex bash+sql scripts.
- Comments for targets, containing double quote characters (")

#### Organizational points:

- Task and action plan is analyzed and you understand what you need to do. Remember, no code at all is always better.
- Make sure you have source data always available. Do not store it locally on geocint - add a target to download data
  from S3 at least.
- Store your commits on a remote repository: your laptop/pc could break anytime. Make regular commits under
  **Draft** MR status
- After your MR is ready, write about it to a suitable slack channel. Mention people who are able to review code and
  approve it. Describe how did you test your code.
- Try to run the pipeline at least once on your test branch, or create simple short makefile for test_* tables in
  separate folder and run it, avoiding affect on running pipeline.
- Add sources for download 3rd-party data
- Before sending to QA or analysis make sure that you wrote 3 points at the task for the mr you have:
    - summary what did you do
    - info on how to test (general flow)
    - some tips on what should be tested in your opinion and what part of the app can be affected.

#### Technical details for **code review** checks:

- Make sure your scripts (especially bash, ansible) are working as a part of Makefile, not only by themselves.
- Idempotence: how will it run the first time? Second time? 100 times?
    - copying of non-existing yet files
    - deleting or renaming functions and procedures, especially when you change the number or order of parameters
    - try to use drop/alter database_object IF EXIST
- Does your target need to be launched every day? Don’t forget to put it into the Clean one. Or make it manually
  (see Cache invalidation).
- Check all dependencies twice.
- Commands log level - will it generate lots of unnecessary info?
- If you replace one target with another one, make sure to delete unused one everywhere (especially dev/prod targets)
- Updates on tables should be a part of target, where this tables are created, for not updating smth twice.

#### After-Merge duties. Share them and your progress with teammates.

- Cache invalidation: manual clean of currently updated but existed targets
- Delete local/S3 (how - link to instruction) files and DB objects that you don’t need anymore
- Сheck periodically the make.svg after launch, maybe you can find out how to make a quick fix for not losing
  a whole day before next launch.


### Slack messages

The geocint pipeline should send messages to the Slack channel. Create channel with name `geocint`, generate Slack token
and store it in the `SLACK_KEY` variable in file `$HOME/.profile`.

```shell
export SLACK_KEY=<your_key>
```

### User schemas

User schemas can be used to separation pipeline and dev data.
Run [scripts/create_geocint_user.sh](scripts/create_geocint_user.sh) to initialize the user schema.

`scripts/create_geocint_user.sh [username]`

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
