# to install geocint just run 
# make install configuration_file=/path/to/your/config/file/config.inc.sh

export SLACK_CHANNEL = $(shell sed -n -e '/^SLACK_CHANNEL/p' ${configuration_file} | cut -d "=" -f 2)
export SLACK_BOT_NAME = $(shell sed -n -e '/^SLACK_BOT_NAME/p' ${configuration_file} | cut -d "=" -f 2)
export SLACK_BOT_EMOJI = $(shell sed -n -e '/^SLACK_BOT_EMOJI/p' ${configuration_file} | cut -d "=" -f 2)
export SLACK_KEY = $(shell sed -n -e '/^SLACK_KEY/p' ${configuration_file} | cut -d "=" -f 2)

export GEOCINT_WORK_DIRECTORY = $(shell sed -n -e '/^GEOCINT_WORK_DIRECTORY/p' ${configuration_file} | cut -d "=" -f 2)
export CUSTOM_PART_FOLDER_NAME = $(shell sed -n -e '/^CUSTOM_PART_FOLDER_NAME/p' ${configuration_file} | cut -d "=" -f 2)

echo 'export GEOCINT_WORK_DIRECTORY=${GEOCINT_WORK_DIRECTORY}' >> ${HOME}/.bashrc

# -------------------- PREPARATIONS BLOCK -----------------------------------

${GEOCINT_WORK_DIRECTORY}: ## create working directory
	mkdir -p $@

${GEOCINT_WORK_DIRECTORY}/geocint: | ${GEOCINT_WORK_DIRECTORY} ## create general_folder directory
	mkdir -p $@

${GEOCINT_WORK_DIRECTORY}/geocint/installation: | ${GEOCINT_WORK_DIRECTORY}/geocint ## create installation folder to store installation process marks
	mkdir -p $@

${GEOCINT_WORK_DIRECTORY}/geocint/installation/add_congig_file_path_to_bashrc: | ${GEOCINT_WORK_DIRECTORY}/geocint/installation ## write export variable to bashrc file
	sudo echo 'export GEOCINT_WORK_DIRECTORY=${GEOCINT_WORK_DIRECTORY}' >> ${HOME}/.bashrc
	touch $@

${GEOCINT_WORK_DIRECTORY}/geocint/installation/preparation_block_finished: ${GEOCINT_WORK_DIRECTORY}/geocint/installation/add_congig_file_path_to_bashrc ## send message that preparation step finished successfully
	echo "Preparation step finished successfully"
	touch $@


# -------------------- DEPENDENCIES INSTALLATIONS BLOCK ----------------------

${GEOCINT_WORK_DIRECTORY}/geocint/installation/runner_installer: ${GEOCINT_WORK_DIRECTORY}/geocint/installation/preparation_block_finished ## install dependencies of runner part 
	bash ${GEOCINT_WORK_DIRECTORY}/geocint-runner/runner-install.sh || echo 'runner-install.sh returned an error, check logs for more infornation'
	touch $@


${GEOCINT_WORK_DIRECTORY}/geocint/installation/private_installer: ${GEOCINT_WORK_DIRECTORY}/geocint/installation/runner_installer ## installs aws cli and system links to public html for the UI
bash ${GEOCINT_WORK_DIRECTORY}/${CUSTOM_PART_FOLDER_NAME}/install.sh || { echo "Error during installation: $(cat ${GEOCINT_WORK_DIRECTORY}/logs/install.log)"; exit 1; }
	bash ${GEOCINT_WORK_DIRECTORY}/${CUSTOM_PART_FOLDER_NAME}/install.sh || echo 'install.sh returned an error, check logs for more infornation'
	touch $@

${GEOCINT_WORK_DIRECTORY}/geocint/installation/installation_block_finished: ${GEOCINT_WORK_DIRECTORY}/geocint/installation/private_installer ## send message that installation step finished successfully
	echo "Installation step finished successfully"
	touch $@



# ------------------------ WEB Dashboard installation block ----------------------------

${GEOCINT_WORK_DIRECTORY}/geocint/installation/set_modes: ${GEOCINT_WORK_DIRECTORY}/geocint/installation/preparation_block_finished  ## create public_html folder and set access
	sudo usermod -aG adm ${USER}
	sudo usermod -aG ${USER} www-data
	sudo mkdir -p ${GEOCINT_WORK_DIRECTORY}/public_html
	sudo chown ${USER}:${USER} ${GEOCINT_WORK_DIRECTORY}/public_html
	sudo chmod 0750 ${GEOCINT_WORK_DIRECTORY}/public_html
	echo 'GEOCINT_WORK_DIRECTORY=${GEOCINT_WORK_DIRECTORY}' | sudo tee -a /etc/environment
	touch $@


${GEOCINT_WORK_DIRECTORY}/geocint/installation/web_dashboard_installation: ${GEOCINT_WORK_DIRECTORY}/geocint/installation/set_modes ${GEOCINT_WORK_DIRECTORY}/geocint/installation/runner_installer
	profile_make_init_viewer -o=${GEOCINT_WORK_DIRECTORY}/public_html
	ln -s ${GEOCINT_WORK_DIRECTORY}/geocint/report.json  ${GEOCINT_WORK_DIRECTORY}/public_html/report.json
	ln -s ${GEOCINT_WORK_DIRECTORY}/geocint/make.svg  ${GEOCINT_WORK_DIRECTORY}/public_html/make.svg
	ln -s ${GEOCINT_WORK_DIRECTORY}/geocint/logs  ${GEOCINT_WORK_DIRECTORY}/public_html/logs
	touch $@

${GEOCINT_WORK_DIRECTORY}/geocint/installation/web_dashboard_block_finished: ${GEOCINT_WORK_DIRECTORY}/geocint/installation/web_dashboard_installation  ## send message that web dashboard initialisation step finished successfully
	echo "web dashboard installation step finished successfully"
	touch $@


# ------------------------ MANAGE BLOCK ---------------------------------------

install: ${GEOCINT_WORK_DIRECTORY}/geocint/installation/web_dashboard_block_finished ## Target to run Geocint pipeline installation
	echo "Geocint pipeline successfully installed"
