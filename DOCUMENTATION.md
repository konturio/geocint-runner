# Geocint Open Source documentation

* Geocint folder structure
* Geocint open-source installation and first run guide
    * Installation
    * First run
* How geocint pipeline works
    * How start_geocint.sh works
    * How to write targets
    * User schemas in the database
    * How to analyse the build time for tables
* Make-profiler
* Best practices of using

## Geocint folder structure

Geocint consists of 3 different parts:
- [geocint-runner](https://github.com/konturio/geocint-runner) - a core part of the pipeline, includes utilities and initial Makefile
- [geocint-openstreetmap](https://github.com/konturio/geocint-runner) - a chain of targets for downloading, updating and uploading
to database OpenStreetMap planet dump
- [geocint-private] any repository that contains your additional functionality

During the installation process, you should clone all these repositories to ~/.
During the installation of the geocint pipeline the next folders will be created in your home directory (~/):
- [public_html] - any public html that you want to share
- [domlogs] - access and errors logs for files from the public_html folder

Then start_geocint.sh will copy files from all these repositories to ~/geocint folder. Geocint folder will be the working folder for the geocint pipeline
(you can set any other name for this folder with the GENERAL_FOLDER variable in confic.inc.sh file)

In general case ~/geocint folder includes the next files and folders :
- [start_geocint.sh](start_geocint.sh) - script, that runs the pipeline: checking required packages, cleaning targets and
  posting info messages
- [runner_install.sh](runner_install.sh) - script, that runs installation of required packages of the geocint-runner part
- [config.inc.sh.sample](config.inc.sh.sample) - a sample config file
- [runner_make](runner_make) - map dependencies between data generation stages
- [osm_make](runner_make) - makefile with a set of targets
- [your_make.sample](your_make.sample) - sample makefile that shows how to integrate geocint-runner, 
geocint-openstreetmap and your own chains of targets
- [functions/](functions) - service SQL functions, used in more than one other file
- [procedures/](procedures) - service SQL procedures, used in more than one other file
- [scripts/](scripts) - scripts that perform data transformation
- [tables/](tables) - SQL-code, which generates a table
- [static_data](static_data) - static file-based data stored in the geocint repository
All these folders and files are removed and recreated each time the geocint pipeline starts. 

After running the pipeline, Makefile will create additional folders and files. These folders are used to store input (in folder), intermediate (mid folder), and output (out folder) data files:
- [data/](data) - file-based input, middle, output data.
	- data/in - all input data, downloaded elsewhere
	- data/in/raster - all downloaded GeoTIFFs
	- data/mid - all intermediate data (retiles, unpacks, reprojections, etc.) which can be removed after
  	each launch
	- data/out - all generated final data (tiles, dumps, unloading for the clients, etc.)
- [db/](db) - files - Makefile mark about executing "db/..." targets
- [deploy/](deploy) - files - Makefile mark about executing "deploy/..." targets
- [logs/](logs) - files - files with targets execution logs
- [report/](report) - folder to store HTML reports.

These folders are not deleted or re-created each time the geocint pipeline runs to avoid rebuilding targets that should not be rebuilt every time (if you want to rebuild some targets chain each time please see How geocint pipeline works in this doc).
You shouldn’t store all your input datasets in data/in/ folder. To make your data storage more organized, you can create additional folders for separate data sources (for example data/in/source_name). This rule also applies to other catalogs.

Also when running the pipeline Makefile will create additional files:
- make.lock - a special file used by start_geocint.sh as a flag to check if a pipeline is running in order not to start a new one until the running pipeline is complete
- make.svg - a file that shows a stored graphical representation of the graph with dependencies of targets
- make_profile.db - a database used to store information about the execution of targets

## Geocint open-source installation and first run guide

### Installation
Before the installation of your own geocint pipeline instance, you should create a repository to store your own part of the pipeline.
Your repository should contain the following required files:
- install.sh (use [runner-install.sh](runner-install.sh) as an example, store installation of your additional dependencies)
- Makefile (use [private_make.sample](your_make.sample) as an example; file to store your own additional targets chains. 

Your Makefile should start with export block:
```
## -------------- EXPORT BLOCK ------------------------

# configuration file
file := ~/config.inc.sh
# Add an export here for each variable from the configuration file that you are going to use in the targets.
export USER_NAME = $(shell sed -n -e '/^USER_NAME/p' ${file} | cut -d "=" -f 2)
export SLACK_CHANNEL = $(shell sed -n -e '/^SLACK_CHANNEL/p' ${file} | cut -d "=" -f 2)
export SLACK_BOT_NAME = $(shell sed -n -e '/^SLACK_BOT_NAME/p' ${file} | cut -d "=" -f 2)
export SLACK_BOT_EMOJI = $(shell sed -n -e '/^SLACK_BOT_EMOJI/p' ${file} | cut -d "=" -f 2)
export SLACK_BOT_KEY = $(shell sed -n -e '/^SLACK_BOT_KEY/p' ${file} | cut -d "=" -f 2)

# these makefiles are stored in geocint-runner and geocint-openstreetmap repositories
# runner_make contains the basic set of targets for creating the project folder structure
# osm_make contains a set of targets for osm data processing
include runner_make osm_make

## ------------- CONTROL BLOCK -------------------------

# replace your_final_target placeholder with the names of final target, that you will use to run pipeline
# you can also add here the names of targets that should not be rebuilt automatically, just when conditions are met or at your request
# to do it just add these names after the colon separated by a space
all: your_final_target ## [FINAL] Meta-target on top of all other targets, or targets on parking.

# by default the clean target is set to serve an update of the OpenStreetMap planet dump during every run
clean: ## [FINAL] Cleans the worktree for the next nightly run. Does not clean non-repeating targets.
	if [ -f data/planet-is-broken ]; then rm -rf data/planet-latest.osm.pbf ; fi
	rm -rf data/planet-is-broken
	profile_make_clean data/planet-latest-updated.osm.pbf

```

1. Create a new user with sudo permissions or use the existing one (the default user is "gis"). Keep in mind that the best practice is to use this username for creating a Postgres role and database. Path ~/ is equivalent to /home/your_user/. This folder is a working directory for the geocint pipeline.
2. Clone 3 repositories (geocint-runner, geocint-openstreetmap, your repo) to ~/
3. The geocint pipeline should send messages to the Slack channel. Create a channel, generate a Slack token and store it in the `SLACK_KEY` variable in the file `~/.profile`. The angle brackets around your_key need to be removed.
```shell
export SLACK_KEY=<your_key>
```
4. Copy [config.inc.sh.sample](config.inc.sh.sample) from geocint-runner to ~/:
```shell
cp ~/geocint-runner/config.inc.sh.sample ~/config.inc.sh
```
Open ~/config.inc.sh and set the necessary values for variables. See comments at this file for details.

5. Run installers:
- ~/geocint-runner/runner_install.sh (necessary dependencies to run a runner part)
- ~/geocint-openstreetmap/openstreetmap_install.sh (necessary dependencies to run a runner part)
- ~/geocint-runner/scripts/set_mods.sh (create /public_html and /domlogs folders and set access modes)

6. Create PostgreSQL role and create PostgreSQL extensions (replace "gis" with your username if you have different). Follow the next steps below :
```shell
	# open psql console by admin (user postgres)
	sudo -u postgres psql
	# create role and database
	create role gis login;
	create database gis owner gis;
	# connect to database
	\c gis
	# create extensions
	create extension postgis;
	create extension postgis_raster;
	create extension postgis_sfcgal;
	create extension postgis_topology;
	create extension h3;
	create extension h3_postgis;
	# you can create any additional extension you need
```
7. Set the crontab to autostart the pipeline. Add to [crontab settings](https://man7.org/linux/man-pages/man5/crontab.5.html) the next lines (keep in mind, that you should replace "gis" with your username):
0 12 * * * /bin/bash /home/gis/geocint-runner/start_geocint.sh > /home/gis/geocint/log.txt

add the following line to regenerate make.svg every 5 minutes; make.svg is a file with a stored graphical representation of graph with dependencies of targets (gray targets - not built, blue - successfully built, red - not built due to the error)
* /5 * * * * cd /home/gis/geocint/ && profile_make

### First run

To automatically start the full pipeline, set the preferred time in the crontab installation.
For example, to run the pipeline at 12:34 set
34 12 * * * /bin/bash /home/gis/geocint-runner/start_geocint.sh > /home/gis/geocint/log.txt

if you want to run the pipeline manually, then run the next line, but keep in mind, that you should replace "gis" with your username:
bash /home/gis/geocint-runner/start_geocint.sh > /home/gis/geocint/log.txt

## How geocint pipeline works

### How start_geocint.sh works

After start_geocint.sh is run, it imports the variables from the configuration file ~/config.inc.sh. 
It will then check the update flags in ~/config.inc.sh and git pull the repositories that have the flag set to “true”. 
Next, it will merge geocint-runner, geocint-openstreetmap and your personal repository into one folder - you can set the name for this folder in ~/config.inc.sh file with $GENERAL_FOLDER variable.
After these events are completed, start_geocint.sh will launch the targets specified in the $RUN_TARGETS variable. The last step is to create/update the make.svg file containing the dependency graph.

### How to write targets

You can read more about writing targets in the official [GNU Make manual](https://www.gnu.org/software/make/manual/make.html#toc-Writing-Rules)

The name of your target will be the name of the file which Make-profiler will use to define the timestamps when the target was executed. If the result of the target execution is a file - the target should be named as this file. If as the result of target execution you don't create a new file, please add `touch $@` line at the end of your target to create an empty file with the same name as a target (`$@` is the equivalent of the name of the target containing it).
For example, target from your_make.sample:
```
deploy/s3/fire_stations: data/out/fire_stations/fire_stations_h3_r8_count.gpkg.gz | deploy/s3 ## deploy/s3 is a dependency from geocint-runner makefile
    aws s3 cp data/out/fire_stations/fire_stations_h3_r8_count.gpkg.gz \
   	 s3://your_s3_bucket/fire_stations_h3_r8_count.gpkg.gz \
   	 --profile your_s3_profile \
   	 --acl public-read
    touch $@
```
As a result of this target execution, we don't have a file, which means we have to execute the `touch $@` command at the end. 
This command will create an empty deploy/s3/fire_stations file whose creation timestamp will be used by Make-profiler.

If you want to rebuild some targets in the chain each time when you run the pipeline, you must add the initial target of this chain to the clean target.
For example, you might have a target’s chain like (here is a simple chain of targets, just the target’s name):
```
data/in/some.tiff: | data/in ## initial target, download input data
data/mid/data_tiff.csv: data/in/some.tiff | data/mid## extract data from raster to intermediate file
db/table/table_from_csv: data/mid/data_tiff.csv | db/table ## load data from CSV to database
data/out/output.geojson.gz: db/table/table_from_csv | data/out ## extract data from database to output file
```
If you want to rebuild this chain of targets each time you run the pipeline, you should add data/in/some.tiff target as an argument for profile_make_clean instruction in the clean target (see the code below). 
```
# by default the clean target is set to serve an update of the OpenStreetMap planet dump during every run
clean: ## [FINAL] Cleans the worktree for next nightly run. Does not clean non-repeating targets.
	if [ -f data/planet-is-broken ]; then rm -rf data/planet-latest.osm.pbf ; fi
	rm -rf data/planet-is-broken
	profile_make_clean data/planet-latest-updated.osm.pbf data/in/some.tiff
```
It means that before each run make-profiler will remove data/in/some.tiff if it exists and rebuild the data and all the targets, that are in the list of dependencies 
(will check dependencies recursively).

If you do not want to rebuild this chain, just make sure that your chain doesn’t depend on targets from the clean target. This method can be useful when you have a large dataset that has not been updated recently and requires heavy and time-consuming pre-processing. In such a case, you'd probably want to prepare the data and load it to the database once not repeating this work without changing the input data.
But! Keep in mind, that dependencies are inherited recursively, even if you don’t put data/in/some.tiff in the data/out/output.geojson.gz dependencies list, it will be data/out/output.geojson.gz’s dependency. It means that these two lines are equivalent:
```
data/out/output.geojson.gz: db/table/table_from_csv
data/out/output.geojson.gz: data/in/some.tiff db/table/table_from_csv db/table/table_from_csv | data/out
```
You can read more about target's dependencies(prerequisites) in the official [GNU Make manual](https://www.gnu.org/software/make/manual/make.html#Prerequisite-Types)

### User schemas in database

User schemas can be used for a separate pipeline and dev data.
Run [scripts/create_geocint_user.sh](scripts/create_geocint_user.sh) to initialize the user schema.

`sudo scripts/create_geocint_user.sh [username]`

This is a script for adding user role and schema to geocint database. If no username is provided, it will be prompted. User roles
are added to the geocint_users group role. You need to add the following line to pg_hba.conf.

`local   gis +geocint_users  trust`

### How to analyse build time for tables

Logs for every build are stored in `/home/gis/geocint/logs`

This command can show lastN {*Total times in ms*} for some {*tablename*} ordered by date

```bash
find /home/gis/geocint/logs -type f -regex ".*/db/table/osm_admin_boundaries/log.txt" -mtime -50 -printf "%T+ %p; " -exec awk '/Time:/ {sum += $4} END {print sum/60000 " min"}' '{}' \; | sort
```

`-mtime -50` - collects every row from 50 days ago till now

`-regex ".*/db/table/osm_admin_boundaries/log.txt"` - change `osm_admin_boundaries` to your {*tablename*}


## Make-profiler

Make-profiler is used as a linter and preprocessor for Makefile that outputs a network diagram of what is getting built, when, and why. 
The output chart (by default make.svg) allows seeing what went wrong and quickly getting to logs. https://github.com/konturio/make-profiler

After the pipeline run, make_profiler will create a make.svg file and make_profile.db.
Make-profile features:
- SVG build overview;
- Critical Path is highlighted;
- Inline pictures-targets into build overview;
- Logs for each target are marked with timestamps;
- Distinguish a failed target execution from forgotten touch;
- Navigate to the last run's logs from each target directly from the call graph;
- Support of self-documented Makefiles according to http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html

Example usage
```shell
sudo apt install python3-pip graphviz gawk
sudo pip3 install https://github.com/konturio/make-profiler/archive/master.zip

cd your_project
profile_make -h                 # have a look at help

profile_make                    # generate an overview graph without profiling data
xdg-open make.svg               # have a look at the call graph

profile_make_clean target       # mark target with children as not yet executed

profile_make_lint               # validate Makefile to find orphan targets
profile_make -j -k target_name  # run a target, record execution times and logs
xdg-open make.svg               # have a look at the call graph with timing data

profile_make -a 2022-05-01      # generate an overview graph with the full target time only after the specified date
```

## Best practices of using

There are a few simple rules, follow them to avoid troubles during the creation of your own pipeline:
* Don’t create targets with a name that already exists in Makefile from geocint-runner repository, osm-make Makefile, from geocint-openstreetmap repository or in your own Makefile;
* Always add a short comment to your target (explain what it does) - it’s a requirement;
* Don’t use double quotes in comments (make-profile will be broken);
* Try to avoid views and materialized views;
* Complex python scripts should become less complex bash+sql scripts;
* Make sure you have source data always available. Do not store it locally on geocint - add a target to download data from S3 at least (you can still store data in a special folder - /static_data, but try to avoid storing important data without a remote backup);
* Try to run the pipeline at least once on your test branch, or create a simple short makefile for test_* tables in a separate folder and run it, avoiding the effect on running the pipeline;
* Make sure your scripts (especially bash, ansible) work as a part of Makefile, not only by themselves (inside of Makefile you should use $$ instead of $ to access a variable);
* Check idempotence: how will it run the first time? Second time? 100 times?;
* Be careful with the copying of non-existing yet files;
* Be careful with deleting or renaming functions and procedures, especially when you change the number or order of parameters;
* Try to use drop/alter database_object with IF EXIST option;
* Define: does your target need to be launched every day? Don’t forget to put it into the Clean one. Or make it manually (see Cache invalidation);
* If you replace one target with another one, make sure you deleted unused one everywhere;
* Updates on tables should be a part of the target, where these tables are created, for not updating something twice;
* When you add a new functionality and modify existing targets do cache invalidation: manual cleaning of currently updated but existing targets;
* Delete local/S3 files and DB objects that you don’t need anymore.
