#!/bin/bash -e

sudo apt-mark hold docker-ce gitlab-ci-multi-runner && \
sudo apt-get -y update && \
sudo apt-get -y upgrade && \
sudo apt-get -y dist-upgrade && \
sudo apt-get -y autoremove && \
git -C ~/devops checkout master && git -C ~/devops pull
