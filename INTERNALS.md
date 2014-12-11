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
then use that distribution as a primitive in an MH query.  We use the
intermingling technique for the solution of CP4.9, although in the
context of a rejection sampler instead of MH.



## What are you design goals for the PPS?

As a language in the Racket family, prob makes use of the Racket
syntax system to provide a uniform surface syntax for widely
varying inference engines and also to perform static analysis and
instrumentation of prob programs.

The instrumentation supports two features of prob: the addressing
scheme of random choices used by the MH framework and the
propagation of observations to sampling sites. Our addressing
scheme is a variation of the Bher (Wingate et al.) technique that
uses Racket's lightweight continuation annotations to avoid
disrupting interoperability with other Racket forms---or other
solvers, such as enumeration. Observations are propagated through
computation, replacing logic sampling with likelihood
weighting. Our instrumentation allows us to propagate
observations through known invertible primitive functions, like +
and cons.

## What trade-offs have you made in designing the PPS?

At the moment probabilistic programs are expressed as extended
Racket programs and dynamically represented as Racket thunks.
While this representation allowed us to make swift progress
on implementing prob, we have so far focused on "black-box"
techniques that require no understanding of the structure of the
underlying model. As our implementation matures, we will need to
either perform deeper analysis to uncover model structure or to
add language features constrained to expressing specialized forms
of models.
