#!/bin/bash

# Set variables
. ~/config.inc.sh
export PATH_ARRAY GENERAL_FOLDER OPTIONAL_DIRECTORIES PRIVATE_REPO_NAME PRIVATE_MAKE_NAME OSM_MAKE_NAME 
export UPDATE_RUNNER UPDATE_OSM_LOGIC UPDATE_PRIVATE ALL_TARGETS RUN_TARGETS
export SLACK_CHANNEL SLACK_BOT_NAME SLACK_BOT_EMOJI PGDATABASE TO_INSTALL
export TARGET_TO_CLEAN RM_DIRECTORIES CLEAN_OPTIONALLY

cleanup() {
  rm -f ~/$GENERAL_FOLDER/make.lock
}

# Compose makefiles to one pipeline
echo "$TO_INSTALL" >> ~/$GENERAL_FOLDER/Makefile
sh ~/geocint-runner/install.sh

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
  echo "Skip start: running pipeline is not done yet." | python3 scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI
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

# Update privat repo if updating is true in config
if [ "$UPDATE_PRIVATE" = "true" ]; then
  cd ~/$PRIVATE_REPO_NAME; git pull --rebase --autostash || { git stash && git pull && echo 'git rebase autostash $PRIVATE_REPO_NAME failed, stash and pull executed' | python3 scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI; }
fi

# Remove from general folder all files and folders except data and db
rm -fr ~/$GENERAL_FOLDER/!(d*)/
find ~/$GENERAL_FOLDER/ -maxdepth 1 -type f -delete

# Copy files from repositories to general folder
cp -r ~/geocint-runner/* ~/$GENERAL_FOLDER
cp -r ~/geocint-openstreetmap/* ~/$GENERAL_FOLDER
cp -r ~/$PRIVATE_REPO_NAME/* ~/$GENERAL_FOLDER

# Compose makefiles to one pipeline
echo "clean: ## [FINAL] Cleans the worktree for next nightly run. Does not clean non-repeating targets.
	if [ -f data/planet-is-broken ]; then rm -rf data/planet-latest.osm.pbf ; fi
	rm -rf $RM_DIRECTORIES
	profile_make_clean $TARGET_TO_CLEAN
	$CLEAN_OPTIONALLY" >> ~/$GENERAL_FOLDER/Makefile
echo "include $OSM_MAKE_NAME $PRIVATE_MAKE_NAME" >> ~/$GENERAL_FOLDER/Makefile


# Include targets into all tagret dependencies
sed -i "1s/.*/export PGDATABASE = $PGDATABASE/" ~/$GENERAL_FOLDER/Makefile
sed -i "4s/.*/all\: $ALL_TARGETS \#\# final target/" ~/$GENERAL_FOLDER/Makefile

profile_make clean

# Check name of current git branch
branch_runner="$(cd ~/geocint-runner; git rev-parse --abbrev-ref HEAD)"
branch_osm="$(cd ~/geocint-openstreetmap; git rev-parse --abbrev-ref HEAD)"
branch_private="$(cd ~/$PRIVATE_REPO_NAME; git rev-parse --abbrev-ref HEAD)"

echo "Geocint server: current geocint-runner branch is $branch_runner, geocint-openstreetmap branch is $branch_osm, $PRIVATE_REPO_NAME branch is $branch_private. Running $RUN_TARGETS targets." | python3 scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI
profile_make -j -k $RUN_TARGETS
make -k -q -n --debug=b $RUN_TARGETS 2>&1 | grep -v Trying | grep -v Rejecting | grep -v implicit | grep -v "Looking for" | grep -v "Successfully remade" | tail -n+10 | python3 scripts/slack_message.py $SLACK_CHANNEL "$SLACK_BOT_NAME" $SLACK_BOT_EMOJI

# redraw the make.svg after build
profile_make

