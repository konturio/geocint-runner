export PGDATABASE = gis
current_date:=$(shell date '+%Y%m%d')

all: db/table db/function data/in data/mid data/out ## [FINAL] Meta-target on top of all other targets, or targets on parking.

data: ## file based datasets.
	mkdir -p $@

data/in: | data  ## Input data.
	mkdir -p $@	

data/in/raster: | data/in ## Directory for all the mega-terabyte geotiffs!
	mkdir -p $@

data/mid: | data  ## Intermediate data.
	mkdir -p $@

data/out: | data ## Generated final data.
	mkdir -p $@
	
db: ## Directory for storing database objects creation footprints.
	mkdir -p $@
	
db/function: | db ## Directory for storing database functions footprints.
	mkdir -p $@
	
db/procedure: | db ## Directory for storing database procedures footprints.
	mkdir -p $@

db/table: | db ## Directory for storing database tables footprints.
	mkdir -p $@

db/index: | db ## Directory for storing database indexes footprints.
	mkdir -p $@

deploy:  ## Directory for deployment targets footprints.
	mkdir -p $@
	
deploy/s3: | deploy ## Target-created directory for deployments on S3.
	mkdir -p $@
	
## clean and build targets will be attached automatically when autostart_geocint.sh will run
