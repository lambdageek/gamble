# Rationale

## What problem domain is well suited for the PPS?

It is too early to tell which problem domains may benefit the most
from prob, however prob's strengths include its integration with
Racket, so applications that require manipulation of sophisticated
data structures, or close commingling of deterministic and
probabilistic computation may benefit.

Among the solvers included with prob are enumeration of discrete
probability distributions and MH over program execution traces. One
programming paradigm that we have found to be particularly fruitful is
the intermingling of both of these solvers.  For example using
enumeration to summarize a discrete distribution from a subproblem and
then use that distribution as a primitive in an MH query.

## What are you design goals for the PPS?

As a language in the Racket family, prob makes use of Racket macros
and of lightweight dynamic instrumentation of continuations to provide
both a uniform surface syntax and a uniform internal interface for
widely varying inference engines (in particular enumeration via
delimited continuations and MH over program execution traces).

We also instrument observations -- a crucial aspect of the Bayesian
approach to learning posterior distributions -- in order to
dynamically discover simplification opportunities.  In future
releases, we hope to use a similar combination of static analysis and
dynamic instrumentation to treat other properties of models such as
conjugacy and exchangeability.

## What trade-offs have you made in designing the PPS?

At the moment the runtime representation of a probabilistic program
exists as a native Racket thunk and a database of random choices.
While this is a lightweight representation that allowed us to make
swift progress on implementing prob, it denies the opportunity to do
exploration of the program structure at runtime (for example by
throwing away unnecessary recomputation).  As our implementation
matures, we may need to represent the probabilistic model as a less
opaque data structure.
