#!/bin/bash

# it is the script, that runs the pipeline: it checks required packages, cleans and runs targets, posts info messages
# Set variables from the configuration file
. ~/config.inc.sh
export PATH_ARRAY GENERAL_FOLDER OPTIONAL_DIRECTORIES PRIVATE_REPO_NAME
export UPDATE_RUNNER UPDATE_OSM_LOGIC UPDATE_PRIVATE RUN_TARGETS
export SLACK_CHANNEL SLACK_BOT_NAME SLACK_BOT_EMOJI SLACK_KEY USER_NAME

# initialize the pipeline interrupt function for the case when the pipeline can't touch make.lock
cleanup() {
  rm -f ~/$GENERAL_FOLDER/make.lock
}

# execute installations and send a message with details if an error was returned
sh ~/geocint-runner/runner-install.sh || echo 'runner-install.sh returned an error, check logs for more infornation' | python scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI
sh ~/geocint-openstreetmap/openstreetmap-install.sh || echo 'openstreetmap-install.sh returned an error, check logs for more infornation' | python scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI
sh ~/$PRIVATE_REPO_NAME/install.sh || echo 'install.sh returned an error, check logs for more infornation' | python scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI

# create a working directory if it does not exist
mkdir -p ~/$GENERAL_FOLDER

# Terminate the script after failed command execution
set -e
PATH="$PATH_ARRAY"

# add optional directories to env
set -a
$OPTIONAL_DIRECTORIES
set +a

cd ~/$GENERAL_FOLDER

# send a message to the slack channel
echo "Geocint pipeline is starting nightly build!" | python ~/geocint-runner/scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI

# make.lock is a file that exists only while the pipeline is running
# if make.lock exists, the pipeline should not start running
# so the script exits with 1 code if make.lock file exists
if [ -e make.lock ]; then
  echo "Skip start: running pipeline is not done yet." | python ~/geocint-runner/scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI
  exit 1
fi

# exit if make.lock file cannot be touched
touch make.lock
trap 'cleanup' EXIT

# Update runner if updating is true in config 
if [ "$UPDATE_RUNNER" = "true" ]; then
  cd ~/geocint-runner; git pull --rebase --autostash || { git stash && git pull && echo 'git rebase autostash geocint-runner failed, stash and pull executed' | python scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI; }
fi

# Update osm logic if updating is true in config
if [ "$UPDATE_OSM_LOGIC" = "true" ]; then
  cd ~/geocint-openstreetmap; git pull --rebase --autostash || { git stash && git pull && echo 'git rebase autostash geocint-openstreetmap failed, stash and pull executed' | python scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI; }
fi

# Update private repo if updating is true in config
if [ "$UPDATE_PRIVATE" = "true" ]; then
  cd ~/$PRIVATE_REPO_NAME; git pull --rebase --autostash || { git stash && git pull && echo 'git rebase autostash $PRIVATE_REPO_NAME failed, stash and pull executed' | python scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI; }
fi

# Remove all files and folders except data, db, deploy and logs from the general folder 
find ~/$GENERAL_FOLDER/. -type d -not -name  "d*" -not -name '*.*' -not -name  "logs" -not -name  "reports" | xargs rm -rf
find ~/$GENERAL_FOLDER/ -maxdepth 1 -type f -delete

cd ~/
# Merge geocint-runner, geocint-openstreetmap and your private repo to one folder and check duplicated files
# This script uses IGNORE_EXISTED_FILE variable from confic.inc.sh (by default it ignores README.md and LICENSE files in a root of every repo)
copy_message="$(python geocint-runner/scripts/merge_repos_and_check_duplicates.py geocint-runner geocint-openstreetmap $PRIVATE_REPO_NAME)"

# This script sends 2 different messages. 
# check if the message starts with "Copy..". Then copying was successful. 
# if it does, send this message and continue. The message will say that the copying was completed nicely.
# if not, it sends the message starting with "Skip start: duplicate files were found". 
# then it may be a situation when there is no message at all. It requires investigation.
# if the message about duplicates is present, need to learn where are the duplicates. 
# after the message is sent at the negative case, exiting happens with 1 code
if [ "$(echo $copy_message | head -c 1)" = "C" ]
then
   echo $copy_message | python ~/geocint-runner/scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI
else
   echo $copy_message | python ~/geocint-runner/scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI
   exit 1
fi

# run clean target before pipeline running
cd ~/$GENERAL_FOLDER
profile_make clean

# Check the name of the current git branch
# the script goes into each folder and writes to the variable the name of the branch to which the repository is currently switched.
branch_runner="$(cd ~/geocint-runner; git rev-parse --abbrev-ref HEAD)"
branch_osm="$(cd ~/geocint-openstreetmap; git rev-parse --abbrev-ref HEAD)"
branch_private="$(cd ~/$PRIVATE_REPO_NAME; git rev-parse --abbrev-ref HEAD)"

# send a message to the slack channel with run information
echo "Geocint server: current geocint-runner branch is $branch_runner, geocint-openstreetmap branch is $branch_osm, $PRIVATE_REPO_NAME branch is $branch_private. Running $RUN_TARGETS targets." | python scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI
# run the pipeline
profile_make -j -k $RUN_TARGETS
make -k -q -n --debug=b $RUN_TARGETS 2>&1 | grep -v Trying | grep -v Rejecting | grep -v implicit | grep -v "Looking for" | grep -v "Successfully remade" | tail -n+10 | python scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI

# redraw the make.svg after the build is completed
profile_make
