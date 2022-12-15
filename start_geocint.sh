#!/bin/bash

# Set variables
. ~/config.inc.sh
export PATH_ARRAY GENERAL_FOLDER OPTIONAL_DIRECTORIES PRIVATE_REPO_NAME PRIVATE_MAKE_NAME OSM_MAKE_NAME 
export UPDATE_RUNNER UPDATE_OSM_LOGIC UPDATE_PRIVATE ALL_TARGETS RUN_TARGETS
export SLACK_CHANNEL SLACK_BOT_NAME SLACK_BOT_EMOJI PGDATABASE
export TARGET_TO_CLEAN RM_DIRECTORIES CLEAN_OPTIONALLY

cleanup() {
  rm -f ~/$GENERAL_FOLDER/make.lock
}

# execute installations and send message with details if error returned
sh ~/geocint-runner/runner-install.sh || echo 'runner-install.sh returned an error, check logs for more infornation' | python3 scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI
sh ~/geocint-openstreetmap/openstreetmap-install.sh || echo 'openstreetmap-install.sh returned an error, check logs for more infornation' | python3 scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI
sh ~/$PRIVATE_REPO_NAME/install.sh || echo 'install.sh returned an error, check logs for more infornation' | python3 scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI

mkdir -p ~/$GENERAL_FOLDER

# Terminate script after failed command execution
set -e
PATH="$PATH_ARRAY"

# add optional directories to env
set -a
$OPTIONAL_DIRECTORIES
set +a

cd ~/$GENERAL_FOLDER

echo "Geocint pipeline is starting nightly build!" | python3 ~/geocint-runner/scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI

# make.lock is a file which exists while pipeline running
# if make.lock exists, pipeline should not be started
if [ -e make.lock ]; then
  echo "Skip start: running pipeline is not done yet." | python3 ~/geocint-runner/scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI
  exit 1
fi

touch make.lock
trap 'cleanup' EXIT

# Update runner if updating is true in config 
if [ "$UPDATE_RUNNER" = "true" ]; then
  cd ~/geocint-runner; git pull --rebase --autostash || { git stash && git pull && echo 'git rebase autostash geocint-runner failed, stash and pull executed' | python3 scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI; }
fi

# Update osm logic if updating is true in config
if [ "$UPDATE_OSM_LOGIC" = "true" ]; then
  cd ~/geocint-openstreetmap; git pull --rebase --autostash || { git stash && git pull && echo 'git rebase autostash geocint-openstreetmap failed, stash and pull executed' | python3 scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI; }
fi

# Update private repo if updating is true in config
if [ "$UPDATE_PRIVATE" = "true" ]; then
  cd ~/$PRIVATE_REPO_NAME; git pull --rebase --autostash || { git stash && git pull && echo 'git rebase autostash $PRIVATE_REPO_NAME failed, stash and pull executed' | python3 scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI; }
fi

# Remove from general folder all files and folders except data, db, deploy and logs
find ~/$GENERAL_FOLDER/. -type d -not -name  "d*" -not -name '*.*' -not -name  "logs" | xargs rm -rf
find ~/$GENERAL_FOLDER/ -maxdepth 1 -type f -delete

# Copy files from repositories to general folder
# move readme files to temporary dir to exclude them from copying process
mkdir -p ~/files_shouldnt_be_copy
mv ~/geocint-openstreetmap/README.md ~/files_shouldnt_be_copy/osm_readme.md
mv ~/$PRIVATE_REPO_NAME/README.md ~/files_shouldnt_be_copy/private_readme.md
mv ~/geocint-openstreetmap/LICENSE ~/files_shouldnt_be_copy/osm_LICENSE.md

# use nohup to make cp return error when target file already exists
rm -f ~/nohup.out
nohup cp -ia ~/geocint-runner/* ~/$GENERAL_FOLDER 2>>~/nohup.out &
nohup cp -ia ~/geocint-openstreetmap/* ~/$GENERAL_FOLDER 2>>~/nohup.out &
nohup cp -ia ~/$PRIVATE_REPO_NAME/* ~/$GENERAL_FOLDER 2>>~/nohup.out &

# move readme back after copying process
mv ~/files_shouldnt_be_copy/osm_readme.md ~/geocint-openstreetmap/README.md 
mv ~/files_shouldnt_be_copy/private_readme.md ~/$PRIVATE_REPO_NAME/README.md
mv ~/files_shouldnt_be_copy/osm_LICENSE.md ~/geocint-openstreetmap/LICENSE
rm -r ~/files_shouldnt_be_copy

# count number of copy conflicts
nohup_length="$(cat ~/nohup.out | grep 'overwrite' | wc -l)"

# if number of copy conflicts more than 0  - exit and send message with details to slack channel
if [ $nohup_length -eq 0 ]
then
  echo "Copy from geocint-runner, geocint-openstreetmap and $PRIVATE_REPO_NAME to geocint folder completed successfully" | python3 ~/geocint-runner/scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI
else
  echo "Skip start: duplicate files were found while copying files to a geocint folder: $(cat ~/nohup.out)" | python3 ~/geocint-runner/scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI
  exit 1
fi

# compose variables from configuration to clean target
echo "clean: ## [FINAL] Cleans the worktree for next nightly run. Does not clean non-repeating targets.
	if [ -f data/planet-is-broken ]; then rm -rf data/planet-latest.osm.pbf ; fi
	rm -rf $RM_DIRECTORIES
	profile_make_clean $TARGET_TO_CLEAN
	$CLEAN_OPTIONALLY" >> ~/$GENERAL_FOLDER/Makefile
	
#add clean target to Makefile
echo "include $OSM_MAKE_NAME $PRIVATE_MAKE_NAME" >> ~/$GENERAL_FOLDER/Makefile

cd ~/$GENERAL_FOLDER

# Include targets into all tagret dependencies
sed -i "1s/.*/export PGDATABASE = $PGDATABASE/" ~/$GENERAL_FOLDER/Makefile
sed -i "4s/.*/all\: $ALL_TARGETS \#\# final target/" ~/$GENERAL_FOLDER/Makefile

# run clean target before pipeline running
profile_make clean

# Check name of current git branch
branch_runner="$(cd ~/geocint-runner; git rev-parse --abbrev-ref HEAD)"
branch_osm="$(cd ~/geocint-openstreetmap; git rev-parse --abbrev-ref HEAD)"
branch_private="$(cd ~/$PRIVATE_REPO_NAME; git rev-parse --abbrev-ref HEAD)"

# send message with run information
echo "Geocint server: current geocint-runner branch is $branch_runner, geocint-openstreetmap branch is $branch_osm, $PRIVATE_REPO_NAME branch is $branch_private. Running $RUN_TARGETS targets." | python3 scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI
# run pipeline
profile_make -j -k $RUN_TARGETS
make -k -q -n --debug=b $RUN_TARGETS 2>&1 | grep -v Trying | grep -v Rejecting | grep -v implicit | grep -v "Looking for" | grep -v "Successfully remade" | tail -n+10 | python3 scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI

# redraw the make.svg after build
profile_make

