% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/multivariate.R
\name{fit_rf}
\alias{fit_rf}
\title{Fit Random Forest}
\usage{
fit_rf(object, response, all_features = FALSE, importance = TRUE, ...)
}
\arguments{
\item{object}{a MetaboSet object}

\item{response}{character, column name of phenoData giving response}

\item{all_features}{should all features be included in the model? if FALSE, flagged features are left out}

\item{importance}{Should importance of features be assessed?}

\item{...}{other parameters passed to \code{randomForest::randomForest}}
}
\value{
An object of class randomForest
}
\description{
Fits a random forest, where given response column in pheno data is predicted using the features. Can be used
both for classification and regression. For more information, see the documentation of \code{randomForest::randomForest}.
After fitting the random forest, use rf_importance as a shortcut for getting the feature importance in random forest prediction.
}
\examples{
rf <- fit_rf(example_set, response = "Group")
rf
importance_rf(rf)

}
\seealso{
\code{\link[randomForest]{randomForest}}, \code{\link{rf_importance}}
}
