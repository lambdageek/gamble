;; Copyright (c) 2014 Ryan Culpepper
;; See the file COPYRIGHT for details.

#lang scribble/manual
@(require scribble/manual
          scribble/basic
          (for-label racket/contract
                     prob))

@title{Prob: Probabilistic Programming}
@author[@author+email["Ryan Culpepper" "ryanc@racket-lang.org"]]

@defmodulelang[prob]

@(local-table-of-contents)

@bold{Development} Development of this library is hosted by
@hyperlink["http://github.com"]{GitHub} at the following project page:

@centered{@url{https://github.com/rmculpepper/prob}}

@bold{Acknowledgements} This library borrows from many
sources. 

@itemlist[

@item{Visualization and elementary probability distribution support
use Neil Toronto's excellent @racketmodname[plot] and
@racketmodname[math/distributions] libraries.}

@item{The @racket[enumerate] form uses techniques described in
@cite{EPP}.}

@item{The @racket[mh-sampler] form uses techniques described in
@cite{Bher}.}

]

@include-section["intro.scrbl"]
@include-section["features.scrbl"]
@include-section["solvers.scrbl"]
@include-section["util.scrbl"]
@include-section["viz.scrbl"]
@; @include-section["notes.scrbl"]

@;{----------------------------------------}

@bibliography[
#:tag "prob-bibliography"

@bib-entry[#:key "Church"
           #:title "Church: a language for generative models"
           #:author "Noah Goodman, Vikash Mansinghka, Daniel Roy, Keith Bonawitz, and Joshua Tenenbaum"
]

@bib-entry[#:key "Bher"
           #:title "Lightweight Imeplementations of Probabilistic Programming Languages Via Transformational Compilation"
           #:author "David Wingate, Andreas Stuhlüller, and Noah Goodman"
           #:location "Proc. of the 14th Artificial Intelligence and Statistics"
           #:url "http://stanford.edu/~ngoodman/papers/WSG-AIStats11.pdf"]

@bib-entry[#:key "EPP"
           #:title "Embedded Probabilistic Programming"
           #:author "Oleg Kiselyov and Chung-chieh Shan"
           #:location "Domain-Specific Languages, pp 360-384"
           #:url "http://dx.doi.org/10.1007/978-3-642-03034-5_17"]

]
