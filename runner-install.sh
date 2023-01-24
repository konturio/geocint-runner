#!/bin/bash

# Installing make-profiler
sudo apt install -y python3-pip graphviz gawk
pip3 install slack slackclient
sudo pip3 install https://github.com/konturio/make-profiler/archive/master.zip
sudo apt-get install -y cmake
sudo apt install -y unzip
sudo apt-get -y install python3-boto3 python3-botocore # amazon.aws.aws_s3
sudo apt-get install -y cron

# python-is-python3 is a convenient way to set up a symlink for /usr/bin/python, pointing to /usr/bin/python3
sudo apt install -y python-is-python3

