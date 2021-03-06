% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/class_constructor.R, R/quality_metrics.R
\docType{class}
\name{MetaboSet-class}
\alias{MetaboSet-class}
\alias{MetaboSet}
\alias{combined_data,MetaboSet-method}
\alias{group_col,MetaboSet-method}
\alias{time_col,MetaboSet-method}
\alias{subject_col,MetaboSet-method}
\alias{results,MetaboSet-method}
\alias{flag,MetaboSet-method}
\alias{join_results,MetaboSet,data.frame-method}
\alias{join_fData,MetaboSet,data.frame-method}
\alias{quality,MetaboSet-method}
\alias{assess_quality,MetaboSet-method}
\alias{flag_quality,MetaboSet-method}
\alias{flag_detection,MetaboSet-method}
\title{An S4 class used to represent LC-MS datasets}
\usage{
\S4method{combined_data}{MetaboSet}(object)

\S4method{group_col}{MetaboSet}(object)

\S4method{time_col}{MetaboSet}(object)

\S4method{subject_col}{MetaboSet}(object)

\S4method{results}{MetaboSet}(object)

\S4method{flag}{MetaboSet}(object)

\S4method{join_results}{MetaboSet,data.frame}(object, dframe)

\S4method{join_fData}{MetaboSet,data.frame}(object, dframe)

\S4method{quality}{MetaboSet}(object)

\S4method{assess_quality}{MetaboSet}(object)

\S4method{flag_quality}{MetaboSet}(object,
  condition = "(RSD_r < 0.2 & D_ratio_r < 0.4) |\\n                                (RSD < 0.1 & RSD_r < 0.1 & D_ratio < 0.1)")

\S4method{flag_detection}{MetaboSet}(object, qc_limit = 0.7,
  group_limit = 0.8, group = group_col(object))
}
\description{
MetaboSet is the main class used to represent data in the amp package.
It is built upon the \code{\link[Biobase]{ExpressionSet}} class from the Biobase
package. For more information, read the MetaboSet utility vignette.
In addition to the slots inherited from \code{\link[Biobase]{ExpressionSet}},
\code{MetaboSet} has four slots of its own. The first three slots hold special
column names that are stored purely for convenience, as many functions use these as
defaults. The fourth slot is a data frame with one row per feature that holds all
relevant results from the analyses.
}
\section{Methods (by generic)}{
\itemize{
\item \code{combined_data}: sample information and features combined to a single data frame, one row per sample

\item \code{group_col}: access and set group_col

\item \code{time_col}: access and set time_col

\item \code{subject_col}: access and set subject_col

\item \code{results}: access and set results

\item \code{flag}: access and set results

\item \code{join_results}: join new information to results

\item \code{join_fData}: join new information to fData

\item \code{quality}: extract quality information of features

\item \code{assess_quality}: compute quality metrics

\item \code{flag_quality}: flag low-quality features

\item \code{flag_detection}: flag features with low detection rate
}}

\section{Slots}{

\describe{
\item{\code{group_col}}{character, name of the column holding group information}

\item{\code{time_col}}{character, name of the column holding time points}

\item{\code{subject_col}}{character, name of the column holding subject identifiers}

\item{\code{results}}{data frame, holds results of analyses}
}}

