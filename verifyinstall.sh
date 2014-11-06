#! /bin/bash

# exit if any simple command returns non-0 exit code
set -e

if [ "z$ENGROOT" = "z" ]; then
   echo "ENGROOT is unset"
   exit 1
fi

echo "Running racket --version"
racket --version

echo "Running $ENGROOT/prob/examples/intro-enum.rkt (might take a while)"
racket $ENGROOT/prob/examples/intro-enum.rkt

echo "Running $ENGROOT/prob/examples/linear-regression-mh.rkt (might take a while)"
racket $ENGROOT/prob/examples/linear-regression-mh.rkt
