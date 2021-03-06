% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/visualization_utils.R
\name{visualizations}
\alias{visualizations}
\title{Write all relevant visualizations to pdf}
\usage{
visualizations(object, prefix, perplexity = 30, merge = FALSE)
}
\arguments{
\item{object}{A MetaboSet object}

\item{prefix}{character, a file path prefix added to the file paths}

\item{perplexity}{perplexity for t-SNE plots}

\item{merge}{logical, whether the files should be merged to a single PDF, see Details}
}
\description{
A wrapper around all the major visualization functions, used for visualizing data between
major steps of data preprocessing. Saves all visualizations as PDFs with a set prefix on filenames.
}
\details{
If \code{merge} is \code{TRUE}, then a file containing all the visualizations
named \code{prefix.pdf} will be created. NOTE: on Windows this requires installation of pdftk
(\url{https://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/}) and on Linux you need to have pdfunite installed.
Mac is not yet supported.
}
