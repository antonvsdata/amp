% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/transformations.R
\name{exponential}
\alias{exponential}
\title{Exponential function}
\usage{
exponential(object, base = exp(1))
}
\arguments{
\item{object}{a MetaboSet object}

\item{base}{base of the exponential}
}
\value{
a MetaboSet object with altered feature abundances
}
\description{
Apply the exponential function to feature abundances (exprs)
}
