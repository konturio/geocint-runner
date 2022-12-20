#!/bin/bash

# Set variables
. ~/config.inc.sh
export PATH_ARRAY GENERAL_FOLDER OPTIONAL_DIRECTORIES PRIVATE_REPO_NAME PRIVATE_MAKE_NAME OSM_MAKE_NAME 
export UPDATE_RUNNER UPDATE_OSM_LOGIC UPDATE_PRIVATE RUN_TARGETS
export SLACK_CHANNEL SLACK_BOT_NAME SLACK_BOT_EMOJI SLACK_KEY USER_NAME
export TARGET_TO_CLEAN RM_DIRECTORIES CLEAN_OPTIONALLY

cleanup() {
  rm -f ~/$GENERAL_FOLDER/make.lock
}

# execute installations and send message with details if error returned
sh ~/geocint-runner/runner-install.sh || echo 'runner-install.sh returned an error, check logs for more infornation' | python scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI
sh ~/geocint-openstreetmap/openstreetmap-install.sh || echo 'openstreetmap-install.sh returned an error, check logs for more infornation' | python scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI
sh ~/$PRIVATE_REPO_NAME/install.sh || echo 'install.sh returned an error, check logs for more infornation' | python scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI

mkdir -p ~/$GENERAL_FOLDER

# Terminate script after failed command execution
set -e
PATH="$PATH_ARRAY"

# add optional directories to env
set -a
$OPTIONAL_DIRECTORIES
set +a

cd ~/$GENERAL_FOLDER

echo "Geocint pipeline is starting nightly build!" | python ~/geocint-runner/scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI

# make.lock is a file which exists while pipeline running
# if make.lock exists, pipeline should not be started
if [ -e make.lock ]; then
  echo "Skip start: running pipeline is not done yet." | python ~/geocint-runner/scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI
  exit 1
fi

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

# Remove from general folder all files and folders except data, db, deploy and logs
find ~/$GENERAL_FOLDER/. -type d -not -name  "d*" -not -name '*.*' -not -name  "logs" -not -name  "reports" | xargs rm -rf
find ~/$GENERAL_FOLDER/ -maxdepth 1 -type f -delete

cd ~/
# Merge geocint-runner, geocint-openstreetmap and your private repo to one folder and check duplicated files
# This script use IGNORE_EXISTED_FILE variable from confic.inc.sh (by default ignore README.md and LICENSE files in root of every repo)
copy_message="$(python geocint-runner/scripts/merge_repos_and_check_duplicates.py geocint-runner geocint-openstreetmap $PRIVATE_REPO_NAME)"

# Chec if the message starts with "Copy.." in another case send message and exit
if [ "$(echo $copy_message | head -c 1)" = "C" ]
then
   echo $copy_message | python ~/geocint-runner/scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI
else
   echo $copy_message | python ~/geocint-runner/scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI
   exit 1
fi

# compose variables from configuration to clean target
echo "clean: ## [FINAL] Cleans the worktree for next nightly run. Does not clean non-repeating targets.
	if [ -f data/planet-is-broken ]; then rm -rf data/planet-latest.osm.pbf ; fi
	rm -rf $RM_DIRECTORIES
	profile_make_clean $TARGET_TO_CLEAN
	$CLEAN_OPTIONALLY" >> ~/$GENERAL_FOLDER/runner_make

# add empty line between clean and build targets	
echo -e "\n"

# run clean target before pipeline running
cd ~/$GENERAL_FOLDER
profile_make clean

# Check name of current git branch
branch_runner="$(cd ~/geocint-runner; git rev-parse --abbrev-ref HEAD)"
branch_osm="$(cd ~/geocint-openstreetmap; git rev-parse --abbrev-ref HEAD)"
branch_private="$(cd ~/$PRIVATE_REPO_NAME; git rev-parse --abbrev-ref HEAD)"

# send message with run information
echo "Geocint server: current geocint-runner branch is $branch_runner, geocint-openstreetmap branch is $branch_osm, $PRIVATE_REPO_NAME branch is $branch_private. Running $RUN_TARGETS targets." | python scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI
# run pipeline
profile_make -j -k build
make -k -q -n --debug=b build 2>&1 | grep -v Trying | grep -v Rejecting | grep -v implicit | grep -v "Looking for" | grep -v "Successfully remade" | tail -n+10 | python scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI

# redraw the make.svg after build
profile_make
