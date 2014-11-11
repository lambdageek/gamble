#! /bin/bash

# exit if any simple command returns non-0 exit code
set -e

if [ "z$ENGROOT" = "z" ]; then
   echo "ENGROOT is unset"
   exit 1
fi

if [ "z$PLTADDONDIR" = "z" ]; then
    PLTADDONDIR=$ENGROOT/.Racket
    echo "PLTADDONDIR environment variable not set; assuming $PLTADDONDIR"
fi
mkdir -p $PLTADDONDIR
export PLTADDONDIR

echo "Running racket --version"
racket --version

if [ ! -f ./prob/examples/intro-enum.rkt ]; then
    echo "Please run the verifyinstall.sh script from the directory containing the prob/examples/ directory"
    exit 1
fi

echo "Running ./examples/intro-enum.rkt (might take a while)"
racket ./prob/examples/intro-enum.rkt

echo "Running ./examples/linear-regression-mh.rkt (might take a while)"
racket ./prob/examples/linear-regression-mh.rkt
