#! /bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

mkdir -p $DIR/logs

DATE=`date +%Y%m%d`
mv $DIR/octolux.log $DIR/logs/octolux.$DATE.log
