#!/bin/bash

IMAGE_TAG="pitrho/emqtt"

# Custom die function.
#
die() { echo >&2 -e "\nRUN ERROR: $@\n"; exit 1; }

# Parse the command line flags.
#
while getopts "t:" opt; do
  case $opt in
    t)
      IMAGE_TAG=${OPTARG}
      ;;

    \?)
      die "Invalid option: -$OPTARG"
      ;;
  esac
done

docker build -t="${IMAGE_TAG}" .
