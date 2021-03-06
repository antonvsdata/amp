% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/batch_correction.R
\name{align_batches}
\alias{align_batches}
\title{Align features between batches}
\usage{
align_batches(object_na, object_fill, batch, mz, rt, mzdiff, rtdiff,
  plot_folder = NULL)
}
\arguments{
\item{object_na}{a MetaboSet object with missing values as NA}

\item{object_fill}{a similar MetaboSet object with imputed values
(used to compute distances between features, can contain missing values as well)}

\item{batch}{character, column name of pData with batch labels}

\item{mz, rt}{column names of m/z and retention time columns in fData}

\item{mzdiff, rtdiff}{the windows for m/z and retention time for aligning features}

\item{plot_folder}{path to the location where the plots should be saved, if NULL, no plots are saved}
}
\value{
a MetaboSet object with the aligned features
}
\description{
Aligns features with m/z or retention time shift between batches using alignBatches from batchCorr package.
See more details in the help file and the original paper.
}
