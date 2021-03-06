#' Batch correction
#'
#' "Basic" batch correction by median? from BatchCorrMetabolomics::doBC
#'
#' @param object a MetaboSet object
#' @param batch the column name for batch labels
#' @param ref the column name for reference sample labels
#' @param ref_label the label for reference samples
#' @param ... other parameters pased to doBC
#'
#' @return a MetaboSet object with the corrected abundances
#'
#' @examples
#' batch_corrected <- dobc(merged_sample, batch = "Batch", ref = "QC", ref_label = "QC")
#' # Evaluate batch correction
#' pca_bhattacharyya_dist(merged_sample, batch = "Batch")
#' pca_bhattacharyya_dist(batch_corrected, batch = "Batch")
#' @export
dobc <- function(object, batch, ref, ref_label, ...) {

  if (!requireNamespace("BatchCorrMetabolomics", quietly = TRUE)) {
      stop("Package \"BatchCorrMetabolomics\" needed for this function to work. Please install it.",
           call. = FALSE)
  }

  ref_idx <- which(pData(object)[, ref] == ref_label)
  seq_idx <- object$Injection_order
  batch_idx <- pData(object)[, batch]

  batch_corrected <- foreach::foreach(feature = featureNames(object), .combine = rbind) %dopar% {
    tmp <- BatchCorrMetabolomics::doBC(Xvec = exprs(object)[feature, ],
         ref.idx = ref_idx,
         batch.idx = batch_idx,
         seq.idx = seq_idx,
         minBsamp = 1,
         method = "lm",
         correctionFormula = "X ~ B")
    matrix(tmp, nrow = 1, dimnames = list(feature, names(tmp)))
  }

  exprs(object) <- batch_corrected

  object
}

#' Remove Unwanted Variation
#'
#' An interface for the RUVs method in RUVSeq package.
#'
#' @param object a MetaboSet object
#' @param batch the column name for batch labels
#' @param replicates list of numeric vectors, indexes of replicates
#' @param k The number of factors of unwanted variation to be estimated from the data.
#' @param ... other parameters passed to RUVSeq::RUVs
#'
#' @return a MetaboSet object with the normalized data
#'
#' @examples
#' # Batch correction
#' replicates <- list(which(merged_sample$QC == "QC"))
#' batch_corrected <- ruvs_qc(merged_sample, batch = "Batch", replicates = replicates)
#' # Evaluate batch correction
#' pca_bhattacharyya_dist(merged_sample, batch = "Batch")
#' pca_bhattacharyya_dist(batch_corrected, batch = "Batch")
#' @export
ruvs_qc <- function(object, batch, replicates, k = 3, ...) {

  if (!requireNamespace("RUVSeq", quietly = TRUE)) {
    stop("Bioconductor package RUVSeq needed for this function to work. Please install it.",
         call. = FALSE)
  }

  # Transform data to pseudo counts for RUVs
  exprs(object)[exprs(object) == 0] <- 1
  exprs(object) <- round(exprs(object))

  # Pad each replicate vector with -1 and transform to matrix
  max_len <- max(sapply(replicates, length))
  scIdx <- matrix(-1, nrow = length(replicates), ncol = max_len)
  for (i in seq_along(replicates)) {
    scIdx[i, seq_along(replicates[[i]])] <- replicates[[i]]
  }

  ruv_results <- RUVSeq::RUVs(x = exprs(object), cIdx = featureNames(object),
                              k = k, scIdx = scIdx, ...)

  exprs(object) <- ruv_results$normalizedCounts
  pData(object) <- cbind(pData(object), ruv_results$W)
  object
}


#' Bhattacharyya distance between bathces in PCA space
#'
#' Computes Bhattacharyya distance between all pairs of batches after
#' projecting the samples into PCA space with pcaMethods::pca
#'
#' @param object a MetaboSet object
#' @param batch column name of pData givinh the batch labels
#'
#' @return matrix of Bhattacharyya distances between batches
#'
#' @examples
#' # Batch correction
#' batch_corrected <- normalize_batches(merged_sample, batch = "Batch", group = "QC", ref_label = "QC")
#' # Evaluate batch correction
#' pca_bhattacharyya_dist(merged_sample, batch = "Batch")
#' pca_bhattacharyya_dist(batch_corrected, batch = "Batch")
#'
#' @export
pca_bhattacharyya_dist <- function(object, batch, all_features = FALSE, center = TRUE, scale = "uv", nPcs = 3, ...) {

  if (!requireNamespace("fpc", quietly = TRUE)) {
    stop("Package \"fpc\" needed for this function to work. Please install it.",
         call. = FALSE)
  }
  if (!requireNamespace("pcaMethods", quietly = TRUE)) {
      stop("Package \"pcaMethods\" needed for this function to work. Please install it.",
           call. = FALSE)
  }
  # Drop flagged features if not told otherwise
  object <- drop_flagged(object, all_features)

  # PCA to 2 dimenstions
  pca_res <- pcaMethods::pca(object, center = center, scale = scale, nPcs = nPcs, ...)
  pca_scores <- pcaMethods::scores(pca_res)

  # Split to batches
  batches <- list()
  for (b in unique(pData(object)[, batch])) {
    batches[[b]] <- pca_scores[pData(object)[, batch] == b, ]
  }

  # Compute means and covariance matrices for Bhattacharyya distance
  muarray <- sapply(batches, colMeans)
  sigmaarray <- array(sapply(batches, cov), dim = c(nPcs, nPcs, length(batches)))

  fpc::bhattacharyya.matrix(muarray,sigmaarray,ipairs="all", misclassification.bound = FALSE)
}


pooled_variance <- function(x, group) {
  # Remove missing values
  group <- group[!is.na(x)]
  x <- x[!is.na(x)]
  # Split to groups
  group_list <- split(x, group)
  n_1 <- sapply(group_list, length) - 1 # n - 1
  # Pooled variance
  sum(n_1 * sapply(group_list, var)) / sum(n_1)
}

between_variance <- function(x, group) {
  # Remove missing values
  group <- group[!is.na(x)]
  x <- x[!is.na(x)]
  # Split to groups
  group_list <- split(x, group)
  n <- sapply(group_list, length)
  means <- sapply(group_list, mean)
  k_1 <- length(unique(group)) - 1
  # Between group variance formula
  sum(n * (means - mean(x))^2) / k_1
}

repeatability <- function(x, group) {
  pv <- pooled_variance(x, group)
  bv <- between_variance(x, group)
  bv / (bv + pv)
}


#' Compute repeatability measures
#'
#' Computes repeatability for each feature with the following formula:
#' \deqn{\frac{\sigma^2_{between}}{\sigma^2_{between} + \sigma^2_{within}}}
#' The repeatability ranges from 0 to 1. Higher repeatability depicts less
#' variation between batches.
#'
#'
#' @param object a MetaboSet object
#' @param group column name of pData givinh the group labels
#'
#' @return data frame with one row per feature with the repeatability measure
#'
#' @examples
#' # Batch correction
#' batch_corrected <- normalize_batches(merged_sample, batch = "Batch", group = "QC", ref_label = "QC")
#' # Evaluate batch correction
#' rep_orig <- perform_repeatability(merged_sample, group = "Group")
#' mean(rep_orig$Repeatability)
#' rep_corr <- perform_repeatability(batch_corrected, group = "Group")
#' mean(rep_corr$Repeatability)
#'
#' @export
perform_repeatability <- function(object, group) {

  group <- pData(object)[, group]
  repeatabilities <- foreach::foreach(feature = featureNames(object), .combine = rbind) %dopar% {
    result_row <- data.frame(Feature_ID = feature,
                             Repeatability = repeatability(exprs(object)[feature, ], group))
  }
  repeatabilities
}

#' Align features between batches
#'
#' Aligns features with m/z or retention time shift between batches using alignBatches from batchCorr package.
#' See more details in the help file and the original paper.
#'
#' @param object_na a MetaboSet object with missing values as NA
#' @param object_fill a similar MetaboSet object with imputed values
#' (used to compute distances between features, can contain missing values as well)
#' @param batch character, column name of pData with batch labels
#' @param mz,rt column names of m/z and retention time columns in fData
#' @param mzdiff,rtdiff the windows for m/z and retention time for aligning features
#' @param plot_folder path to the location where the plots should be saved, if NULL, no plots are saved
#'
#' @return a MetaboSet object with the aligned features
align_batches <- function(object_na, object_fill, batch, mz, rt, mzdiff, rtdiff, plot_folder = NULL) {

  if (!requireNamespace("batchCorr", quietly = TRUE)) {
    stop("Package \"batchCorr\" needed for this function to work. Please install it.",
         call. = FALSE)
  }

  # Set working directory for plotting (the bathCorr functions saves plots in the current working directory...)
  if (!is.null(plot_folder)) {
    old_wd <- getwd()
    setwd(plot_folder)
    report <- TRUE
  } else {
    report <- FALSE
  }


  # Extract peak mz and rt information
  pInfo <- as.matrix(fData(object_na)[, c(mz, rt)])
  colnames(pInfo) <- c("mz", "rt")

  # Align batches based on the QCs
  aligned <- batchCorr::alignBatches(peakInfo = pInfo, PeakTabNoFill = t(exprs(object_na)), PeakTabFilled = t(exprs(object_fill)),
                                     batches = pData(object_na)[, batch], sampleGroups = object_na$QC, selectGroup = "QC",
                                     mzdiff = mzdiff, rtdiff = rtdiff, report = report)

  # Reset working directory
  if (!is.null(plot_folder)) {
    setwd(old_wd)
  }

  # Attach aligned features
  exprs(object_fill) <- t(aligned$PTalign)
  object_fill
}


#' Normalize batches
#'
#' Normalize bathces by either reference samples of population median.
#' Uses normalizeBatches function from the batchCorr package
#'
#' @param object a MetaboSet object
#' @param batch,group character, column names of pData with batch labels and group labels
#' @param ref_label the label of the reference group i.e. the group that is constant through batches
#' @param ... additional parameters passed to batchCorr::normalizeBatches
#'
#' @return list, the object with normalized features and information on which
#' features were corrected by ref samples in each batch.
#'
#' @examples
#' # Batch correction
#' batch_corrected <- normalize_batches(merged_sample, batch = "Batch", group = "QC", ref_label = "QC")
#' # Evaluate batch correction
#' pca_bhattacharyya_dist(merged_sample, batch = "Batch")
#' pca_bhattacharyya_dist(batch_corrected, batch = "Batch")
#' @export
normalize_batches <- function(object, batch, group, ref_label, ...) {

  if (!requireNamespace("batchCorr", quietly = TRUE)) {
      stop("Package \"batchCorr\" needed for this function to work. Please install it.",
           call. = FALSE)
  }

  normData <- batchCorr::normalizeBatches(peakTable = t(exprs(object)), batches = pData(object)[, batch],
                                          sampleGroup = pData(object)[, group], refGroup = ref_label, ...)

  exprs(object) <- t(normData$peakTable)
  ref_corrected <- as.data.frame(t(normData$refCorrected))
  colnames(ref_corrected) <- paste0("Ref_corrected_", seq_len(ncol(ref_corrected)))
  ref_corrected$Feature_ID <- featureNames(object)
  object <- join_results(object, ref_corrected)
}

#' Save batch correction plots
#'
#' Saves plots of each feature showing the effect of batch correction.
#' Plots show QC samples and regular samples inside each batch, plus the
#' batch mean for biological samples and QC samples as a horizontal line.
#' The dashed line represents QC mean, the filled line represents biological
#' sample mean.
#' NOTE: if you change the shape variable, be sure to set a shape scale as well,
#' the default scale only has 2 values, so it can only accomodate 2 shapes.
#'
#' @param orig,corrected MetaboSet objects before and after batch effect correction
#' @param file path to the PDF file where the plots will be saved
#' @param batch,color,shape column names of pData for batch labels,
#' and column used for coloring and shaping points (by default batch and QC)
#' @param color_scale,shape_scale scales for color and scale as returned by ggplot functions.
#'
#' @examples
#' \dontrun{
#' # Batch correction
#' batch_corrected <- normalize_batches(merged_sample, batch = "Batch", group = "QC", ref_label = "QC")
#' # Plots of each features
#' save_batch_plots(orig = merged_sample, corrected = batch_corrected,
#'                  file = "batch_plots.pdf")
#' }
#' @export
save_batch_plots <- function(orig, corrected, file, width = 14, height = 10,
                             batch = "Batch", color = "Batch", shape = "QC",
                             color_scale = NULL, shape_scale = NULL) {

  color_scale <- color_scale %||% getOption("amp.color_scale_dis")
  shape_scale <- shape_scale %||% scale_shape_manual(values = c(15, 21))

  data_orig <- combined_data(orig)
  data_corr <- combined_data(corrected)

  batch_injections <- data_orig %>%
    dplyr::group_by(!! sym(batch)) %>%
    dplyr::summarise(start = min(Injection_order), end = max(Injection_order))

  batch_mean_helper <- function(data) {
    data %>%
      dplyr::group_by(!! sym(batch)) %>%
      dplyr::summarise_at(featureNames(orig), finite_mean) %>%
      dplyr::left_join(batch_injections, ., by = batch)
  }

  get_batch_means <- function(data) {
    batch_means <- batch_mean_helper(data) %>%
      dplyr::mutate(QC = "Sample")
    batch_means_qc <- data %>%
      dplyr::filter(QC == "QC") %>%
      batch_mean_helper() %>%
      dplyr::mutate(QC = "QC")

    rbind(batch_means, batch_means_qc)
  }

  batch_means_orig <- get_batch_means(data_orig)


  batch_means_corr <- get_batch_means(data_corr)


  batch_plot_helper <- function(data, fname, batch_means) {
    p <- ggplot() +
      geom_point(data = data, mapping = aes_string(x = "Injection_order", y = fname,
                                                   color = color, shape = shape)) +
      theme_bw() +
      theme(panel.grid = element_blank()) +
      color_scale +
      shape_scale

    p <- p +
      geom_segment(data = batch_means, mapping = aes_string(x = "start", xend = "end",
                                                            y = fname, yend = fname,
                                                            color = color, linetype = "QC"),
                   size = 1) +
      scale_linetype(guide = FALSE)
    p
  }

  pdf(file, width = width, height = height)

  for (feature in featureNames(orig)) {
    p1 <- batch_plot_helper(data_orig, feature, batch_means_orig)

    p2 <- batch_plot_helper(data_corr, feature, batch_means_corr)

    p <- cowplot::plot_grid(p1, p2, nrow = 2)
    plot(p)
  }

  dev.off()
}
