# to install geocint just run 
# make install configuration_file=/path/to/your/config/file/config.inc.sh

# Add here export for every varible from configuration file that you are going to use in targets
export PGDATABASE = $(shell sed -n -e '/^PGDATABASE/p' ${configuration_file} | cut -d "=" -f 2)
export PGUSER = $(shell sed -n -e '/^PGUSER/p' ${configuration_file} | cut -d "=" -f 2)
export PGPASSWORD = $(shell sed -n -e '/^PGPASSWORD/p' ${configuration_file} | cut -d "=" -f 2)
export INSTALL_POSTGRESQL_EXTENSIONS = $(shell sed -n -e '/^INSTALL_POSTGRESQL_EXTENSIONS/p' ${configuration_file} | cut -d "=" -f 2)
export SLACK_CHANNEL = $(shell sed -n -e '/^SLACK_CHANNEL/p' ${configuration_file} | cut -d "=" -f 2)
export SLACK_BOT_NAME = $(shell sed -n -e '/^SLACK_BOT_NAME/p' ${configuration_file} | cut -d "=" -f 2)
export SLACK_BOT_EMOJI = $(shell sed -n -e '/^SLACK_BOT_EMOJI/p' ${configuration_file} | cut -d "=" -f 2)
export SLACK_BOT_KEY = $(shell sed -n -e '/^SLACK_BOT_KEY/p' ${configuration_file} | cut -d "=" -f 2)

export GEOCINT_WORK_DIRECTORY = $(shell sed -n -e '/^GEOCINT_WORK_DIRECTORY/p' ${configuration_file} | cut -d "=" -f 2)
export CUSTOM_PART_FOLDER_NAME = $(shell sed -n -e '/^CUSTOM_PART_FOLDER_NAME/p' ${configuration_file} | cut -d "=" -f 2)

PG_EXTENSIONS_LIST = $(shell echo "${INSTALL_POSTGRESQL_EXTENSIONS}" | tr "," "\n")

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

${GEOCINT_WORK_DIRECTORY}/geocint/installation/openstreetmap_installer: ${GEOCINT_WORK_DIRECTORY}/geocint/installation/runner_installer ## install dependencies of openstreetmap part
	bash ${GEOCINT_WORK_DIRECTORY}/geocint-openstreetmap/openstreetmap-install.sh || echo 'openstreetmap-install.sh returned an error, check logs for more infornation'
	touch $@

${GEOCINT_WORK_DIRECTORY}/geocint/installation/h3_pg_installation: ${GEOCINT_WORK_DIRECTORY}/geocint/installation/openstreetmap_installer ## install h3_pg
	sudo pgxn install h3
	touch $@

${GEOCINT_WORK_DIRECTORY}/geocint/installation/private_installer: ${GEOCINT_WORK_DIRECTORY}/geocint/installation/h3_pg_installation ## install dependencies of openstreetmap part
	bash ${GEOCINT_WORK_DIRECTORY}/${CUSTOM_PART_FOLDER_NAME}/install.sh || echo 'install.sh returned an error, check logs for more infornation'
	touch $@

${GEOCINT_WORK_DIRECTORY}/geocint/installation/set_modes: ${GEOCINT_WORK_DIRECTORY}/geocint/installation/private_installer ## create public_html folder and set access
	sudo usermod -aG adm ${USER}
	sudo usermod -aG ${USER} www-data
	sudo mkdir -p ${GEOCINT_WORK_DIRECTORY}/public_html
	sudo chown ${USER}:${USER} ${GEOCINT_WORK_DIRECTORY}/public_html
	sudo chmod 0750 ${GEOCINT_WORK_DIRECTORY}/public_html
	sudo echo 'export PATH=$$PATH:/usr/local/pgsql/bin' >> ${HOME}/.bashrc
	echo 'GEOCINT_WORK_DIRECTORY=${GEOCINT_WORK_DIRECTORY}' | sudo tee -a /etc/environment
	touch $@

${GEOCINT_WORK_DIRECTORY}/geocint/installation/installation_block_finished: ${GEOCINT_WORK_DIRECTORY}/geocint/installation/set_modes ## send message that installation step finished successfully
	echo "Installation step finished successfully"
	touch $@


# ------------------------ DB configuration block ----------------------------

${GEOCINT_WORK_DIRECTORY}/geocint/installation/create_user: ${GEOCINT_WORK_DIRECTORY}/geocint/installation/installation_block_finished ## create postgresql user
	rm -f USER_COUNT
	sudo -u postgres psql -q -X -t -c "select count(*) from pg_roles WHERE rolname = '${PGUSER}'" | xargs echo > USER_COUNT
	if [ $$(cat USER_COUNT) -lt 1 ]; then sudo -u postgres psql -c "CREATE ROLE ${PGUSER} WITH SUPERUSER LOGIN ENCRYPTED PASSWORD '${PGPASSWORD}';"; fi
	if [ 0 -lt $$(cat USER_COUNT) ]; then echo "role ${PGUSER} already exists. Skip creation."; fi
	rm -f USER_COUNT
	touch $@
	
${GEOCINT_WORK_DIRECTORY}/geocint/installation/create_database: ${GEOCINT_WORK_DIRECTORY}/geocint/installation/create_user ## create postgresql db
	rm -f DB_COUNT
	sudo -u postgres psql -q -X -t -c "select count(*) FROM pg_database WHERE datname = '${PGDATABASE}'" | xargs echo > DB_COUNT
	if [ $$(cat DB_COUNT) -lt 1 ]; then sudo -u postgres psql -c "CREATE DATABASE ${PGDATABASE} WITH OWNER ${PGUSER};"; fi
	if [ 0 -lt $$(cat DB_COUNT) ]; then echo "database ${PGDATABASE} already exists. Skip creation."; fi
	rm -f DB_COUNT
	touch $@
	
${GEOCINT_WORK_DIRECTORY}/geocint/installation/create_extensions: ${GEOCINT_WORK_DIRECTORY}/geocint/installation/create_database ## create postgresql extensions
	echo "Create PostgreSQL extensions:"
	echo ${PG_EXTENSIONS_LIST}	
	for i in $(PG_EXTENSIONS_LIST); do \
		psql -c "CREATE EXTENSION IF NOT EXISTS $$i ;"; \
	done
	touch $@

${GEOCINT_WORK_DIRECTORY}/geocint/installation/database_block_finished: ${GEOCINT_WORK_DIRECTORY}/geocint/installation/create_extensions ## send message that database initialisation step finished successfully
	echo "Database initialisation step finished successfully"
	touch $@


# ------------------------ MANAGE BLOCK ---------------------------------------

install: ${GEOCINT_WORK_DIRECTORY}/geocint/installation/database_block_finished ## Target to run Geocint pipeline installation
	echo "Geocint pipeline successfully installed"
