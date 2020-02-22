#! /bin/bash

# Simple wrapper around octolux.rb

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

run() {
  $DIR/octolux.rb >>$DIR/octolux.log 2>&1
}

# If octolux.rb quits with a non-zero status code, run it again.
# This catches occasional failures due to the inverter not responding etc.
run || run
