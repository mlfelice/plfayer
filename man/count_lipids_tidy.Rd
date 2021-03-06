% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/qc_funs.R
\name{count_lipids_tidy}
\alias{count_lipids_tidy}
\title{Calculate distribution of lipids}
\usage{
count_lipids_tidy(df)
}
\arguments{
\item{df}{Dataframe or tibble containing the following columns: Batch,
DataFileName, RetTimeSecs, MajorHeightnA, TotalPeakArea1, DisplayDelta1,
Name.}
}
\value{
A tibble in long format containing the original columns as well as
Count and LipidFrequency.
}
\description{
\code{count_lipids_tidy} tabulates the number of occurrences and frequency
of detection of each lipid and returns as a tibble.
}
\examples{

}
