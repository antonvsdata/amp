% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/qc_visualizations.R
\name{plot_quality}
\alias{plot_quality}
\title{Plot quality metrics}
\usage{
plot_quality(object, all_features = FALSE)
}
\arguments{
\item{object}{a MetaboSet object}

\item{all_features}{logical, should all features be used? If FALSE (the default),
flagged features are removed before visualization.}
}
\value{
a ggplot object
}
\description{
Plots distribution of each quality metric, and a distribution of the flags.
}
\examples{
plot_quality(example_set)

}
