
# Check that objects have same special columns
#
# Used to check that the special columns of pheno data parts of MetaboSet objects
# match when merging, called by check_match
#
# @param x,y MetaboSet objects
# @param fun the function to apply, usually one of group_col, time_col or subject_col
check_column_match <- function(x, y, fun, name) {
  check <- fun(x) == fun(y)
  if (is.na(check)) {
    check <- is.na(fun(x)) & is.na(fun(y))
  }
  if (!check) {
    stop(paste(name, "returns different column names"))
  }
  if (!is.na(fun(x))) {
    if(!identical(pData(x)[, fun(x)], pData(y)[, fun(y)])) {
      stop(paste(name, "columns contain different elements"))
    }
  }
}

# Check that two MetaboSet object can be combined
#
# Checks many matching criteria, basically pheno data needs to have similar special columns,
# the number of samples needs to be the same and feature data and results need to have the
# same columns names. Throws an error if any of the criteria is not fulfilled.
#
# @param x,y MetaboSet objects
check_match <- function(x, y) {
  # Lots of checks to ensure that everything goes smoothly

  # Amount of samples must be equal
  if (nrow(pData(x)) != nrow(pData(y))) {
    stop("Unequal amount of samples")
  }
  # Resulting feature ID must be unique
  feature_id <- c(fData(x)$Feature_ID, fData(y)$Feature_ID)
  if (!all_unique(feature_id)) {
    stop("Merge would result in duplicated feature ID")
  }
  # group_col, time_col, subject_col need to match
  funs <- list("group_col" = group_col, "time_col" = time_col, "subject_col" = subject_col)
  for (i in seq_along(funs)) {
    check_column_match(x, y, funs[[i]], names(funs)[i])
  }

  if (!identical(pData(x)$Injection_order, pData(y)$Injection_order)) {
    stop("Injection orders are not identical")
  }
  if (!identical(pData(x)$Sample_ID, pData(y)$Sample_ID)) {
    stop("Sample IDs are not identical")
  }


  overlap_cols <- intersect(colnames(pData(x)), colnames(pData(y))) %>%
    setdiff(c("Sample_ID", "Injection_order", group_col(x), time_col(x), subject_col(x)))

  if (length(overlap_cols)) {
    for (overlap_col in overlap_cols) {
      if (!identical(pData(x)[overlap_col], pData(y)[overlap_col])) {
        stop(paste("Columns named", overlap_col, "in pheno data have different content"))
      }
    }
  }

  if (!identical(colnames(fData(x)), colnames(fData(y)))) {
    stop("fData have different column names")
  }

  if (!identical(colnames(exprs(x)), colnames(exprs(y)))) {
    stop("exprs have different column names")
  }

  if (!identical(colnames(results(x)), colnames(results(y)))) {
    stop("results have different column names")
  }

}

# Merge two MetaboSet objects together
merge_helper <- function(x, y) {
  # Check that the match is ok
  check_match(x,y)

  merged_pdata <- dplyr::left_join(pData(x), pData(y), by =
                                     intersect(colnames(pData(x)), colnames(pData(y)))) %>%
    Biobase::AnnotatedDataFrame()
  rownames(merged_pdata) <- rownames(pData(x))
  merged_exprs <- rbind(exprs(x), exprs(y))
  merged_fdata <- rbind(fData(x), fData(y)) %>%
    Biobase::AnnotatedDataFrame()
  merged_results <- rbind(results(x), results(y))

  merged_group_col <- ifelse(!is.na(group_col(x)), group_col(x), group_col(y))
  merged_time_col <- ifelse(!is.na(time_col(x)), time_col(x), time_col(y))
  merged_subject_col <- ifelse(!is.na(subject_col(x)), subject_col(x), subject_col(y))

  merged_object <- MetaboSet(exprs = merged_exprs,
                             phenoData = merged_pdata,
                             featureData = merged_fdata,
                             group_col = merged_group_col,
                             time_col = merged_time_col,
                             subject_col = merged_subject_col,
                             results = merged_results)

  merged_object
}

#' Merge MetaboSet objects together
#'
#' @param ... MetaboSet objects or a list of Metaboset objects
#'
#' @return A merged MetaboSet object
#'
#' @examples
#' merged <- merge_metabosets(hilic_neg_sample, hilic_pos_sample,
#'                            rp_neg_sample, rp_pos_sample)
#'
#' @export
merge_metabosets <- function(...) {

  # Combine the objects to a list
  objects <- list(...)
  # If a list is given in the first place, it should move to top level
  if (length(objects) == 1) {
    if (class(objects[[1]]) == "list") {
      objects <- objects[[1]]
    }
  }
  # Class check
  if (!all(sapply(objects, class) == "MetaboSet")) {
    stop("The arguments should only contain MetaboSet objects")
  }

  # Merge objects together one by one
  merged <- NULL
  for (object in objects) {
    if (is.null(merged)) {
      merged <- object
    } else {
      merged <- merge_helper(merged, object)
    }
  }

  merged
}


fdata_batch_helper <- function(fx, fy) {

  if (!identical(colnames(fx), colnames(fy))) {
    stop("fData have different column names")
  }

  # Combine common features: all NAs in fx are replaced by a value from fy
  common_features <- intersect(fx$Feature_ID, fy$Feature_ID)
  for (cf in common_features) {
    na_idx <- is.na(fx[cf, ])
    fx[cf, na_idx] <- fy[cf, na_idx]
  }
  new_features <- setdiff(fy$Feature_ID, fx$Feature_ID)

  rbind(fx, fy[new_features, ])
}


merge_batch_helper <- function(x, y) {

  merged_pdata <- rbind(pData(x), pData(y))
  merged_pdata$Sample_ID[grepl("QC", merged_pdata$Sample_ID)] <- paste0("QC_", seq_len(sum(grepl("QC", merged_pdata$Sample_ID))))
  merged_pdata$Sample_ID[grepl("Ref", merged_pdata$Sample_ID)] <- paste0("Ref_", seq_len(sum(grepl("Ref", merged_pdata$Sample_ID))))
  rownames(merged_pdata) <- merged_pdata$Sample_ID
  merged_pdata <- merged_pdata %>%
    Biobase::AnnotatedDataFrame()

  merged_exprs <- dplyr::bind_rows(as.data.frame(t(exprs(x))), as.data.frame(t(exprs(y)))) %>% t()
  colnames(merged_exprs) <- rownames(merged_pdata)

  merged_fdata <- fdata_batch_helper(fData(x), fData(y)) %>%
    Biobase::AnnotatedDataFrame()
  merged_results <- dplyr::left_join(results(x), results(y))
  rownames(merged_results) <- merged_results$Feature_ID

  merged_group_col <- ifelse(!is.na(group_col(x)), group_col(x), group_col(y))
  merged_time_col <- ifelse(!is.na(time_col(x)), time_col(x), time_col(y))
  merged_subject_col <- ifelse(!is.na(subject_col(x)), subject_col(x), subject_col(y))

  merged_object <- MetaboSet(exprs = merged_exprs,
                             phenoData = merged_pdata,
                             featureData = merged_fdata,
                             group_col = merged_group_col,
                             time_col = merged_time_col,
                             subject_col = merged_subject_col,
                             results = merged_results)

  merged_object
}


#' Merge MetaboSet objects of batches together
#'
#' @param ... MetaboSet objects or a list of Metaboset objects
#'
#' @return A merged MetaboSet object
#'
#' @examples
#' batch1 <- merged_sample[, merged_sample$Batch == 1]
#' batch2 <- merged_sample[, merged_sample$Batch == 2]
#' merged <- merge_batches(batch1, batch2)
#'
#' @export
merge_batches <- function(...) {

  # Combine the objects to a list
  objects <- list(...)
  # If a list is given in the first place, it should move to top level
  if (length(objects) == 1) {
    if (class(objects[[1]]) == "list") {
      objects <- objects[[1]]
    }
  }
  # Class check
  if (!all(sapply(objects, class) == "MetaboSet")) {
    stop("The arguments should only contain MetaboSet objects")
  }

  # Merge objects together one by one
  merged <- NULL
  for (object in objects) {
    if (is.null(merged)) {
      merged <- object
    } else {
      merged <- merge_batch_helper(merged, object)
    }
  }

  merged
}





