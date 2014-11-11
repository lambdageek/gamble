# Prob


## Documentation

Read the documentation online here: http://rmculpepper.github.io/prob/prob/

Installing `prob` also builds its documentation on your system, and it is available via `raco docs prob` or Help, Racket Documentation in DrRacket.

## Prerequisites

Racket version 6.0 or later is required.

  * Get Racket here: http://racket-lang.org


## Installing from a snapshot

The following instructions assume you want to write programs using a specific snapshot of `prob` without updating to the latest available github version.

1. If you had already installed a previous version of `prob`, remove it.
  * command line: `raco pkg remove prob`
2. Extract the snapshot into a directory like 'prob-snapshot-vvvvvv" (where vvvvvv is the snapshot version).
  * command line: `tar xzf prob-snapshot-vvvvvvv.tar.gz`
3. Set the environment variable PLTADDONDIR to the directory that 
hosts the user-specific Racket configuration.
  * `export PLTADDONDIR=$ADDONDIR/.racket`
  * `mkdir $PLDADDONDIR`
3. Install the snapshot version of `prob` as a Racket package.
  * `raco pkg install --link prob-snapshot-vvvv/prob`

To run prob, ensure that PLTADDONDIR is set and star Racket.
