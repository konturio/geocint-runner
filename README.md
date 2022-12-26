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