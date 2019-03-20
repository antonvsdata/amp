
#' Summary statistics
#'
#' Computes chosen summary statistics for each feature,
#' possibly grouped by a factor
#'
#' @param object a MetaboSet object
#'
#' @return a data frame with the summary statistics
#'
#' @export
summary_statistics <- function(object, grouping_cols = group_col(object)) {

  data <- combined_data(object)
  features <- Biobase::featureNames(object)

  if (!is.na(grouping_cols[1])) {
    data <- data %>% dplyr::group_by_at(grouping_cols)
  }
  statistics <- foreach::foreach(i = seq_along(features), .combine = rbind,
                                 .export = c("finite_sd", "finite_mad", "finite_mean",
                                             "finite_median", "finite_quantile")) %dopar% {
    feature <- features[i]
    tmp <- data %>%
      dplyr::summarise_at(dplyr::vars(feature), .funs = list(mean = finite_mean,
                                               sd = finite_sd,
                                               median = finite_median,
                                               mad = finite_mad,
                                               Q25 = ~finite_quantile(., probs = 0.25),
                                               Q75 = ~finite_quantile(., probs = 0.75))) %>%
      dplyr::ungroup()
    for (grouping_col in grouping_cols) {
      tmp[grouping_col] <- paste0(grouping_col, "_",
                                  as.character(tmp[, grouping_col, drop = TRUE]))
    }
    tmp <- tmp %>%
      tidyr::unite("Factors", grouping_cols) %>%
      tidyr::gather("Statistic", "Value", -Factors) %>%
      tidyr::unite("Key", c("Factors", "Statistic")) %>%
      tidyr::spread(Key, Value)
    tmp <- data.frame(Feature_ID = feature, tmp)
                                             }

  statistics
}



#' Cohen's D
#'
#' Computes Cohen's D for each feature
#'
#' @param object a MetaboSet object
#' @param id character, name of the subject ID column
#' @param group character, name of the group column
#' @param time character, name of the time column
#'
#' @return data frame with Cohen's d for each feature
#'
#' @export
cohens_d <- function(object, id = subject_col(object), group = group_col(object),
                     time = time_col(object)) {

  data <- combined_data(object)
  data[time] <- ifelse(data[, time] == levels(data[, time])[1], "time1", "time2")
  data[group] <- ifelse(data[, group] == levels(data[, group])[1], "group1", "group2")

  features <- Biobase::featureNames(object)
  ds <- foreach::foreach(i = seq_along(features), .combine = rbind,
                         .packages = c("dplyr", "tidyr")) %dopar% {
    feature <- features[i]
    tmp <- data[c(id, group, time, feature)]
    colnames(tmp) <- c("ID", "group", "time", "feature")
    tmp <- tmp %>%
      spread(time, feature) %>%
      mutate(diff = time2 - time1) %>%
      group_by(group) %>%
      dplyr::summarise(mean_diff = mean(diff, na.rm = TRUE), sd_diff = sd(diff, na.rm = TRUE))

    d <- data.frame(Feature_ID = feature,
                    Cohen_d = (tmp$mean_diff[tmp$group == "group2"] - tmp$mean_diff[tmp$group == "group1"]) / mean(tmp$sd_diff))
    d
  }
  rownames(ds) <- ds$Feature_ID
  ds
}

#' Fold change
#'
#' Computes fold change between eeach group for each feature.
#'
#' @param object a MetaboSet object
#' @param group character, name of the group column
#'
#' @return data frame with fold changes for each feature
#'
#' @export
fold_change <- function(object, group = group_col(object)) {

  data <- combined_data(object)
  groups <- combn(levels(data[, group]), 2)

  features <- Biobase::featureNames(object)

  results <- foreach::foreach(i = seq_along(features), .combine = rbind) %dopar% {
    feature <- features[i]
    result_row <- rep(0, ncol(groups))
    # Calculate fold changes
    for(i in 1:ncol(groups)){
      group1 <- data[data[, group] == groups[1,i], feature]
      group2 <- data[data[, group] == groups[2,i], feature]
      result_row[i] <- mean(group2)/mean(group1)
    }
    result_row
  }

  # Create comparison labels for result column names
  comp_labels <- groups %>% t() %>% as.data.frame() %>% unite("Comparison", V2, V1, sep = "_vs_")
  comp_labels <- comp_labels[,1]
  results_df <- data.frame(features, results, stringsAsFactors = FALSE)
  colnames(results_df) <- c("Feature_ID", comp_labels)
  rownames(results_df) <- results_df$Feature_ID
  # Order the columns accordingly
  results_df[c("Feature_ID", comp_labels[order(comp_labels)])]
}

adjust_p_values <- function(x) {
  p_cols <- colnames(x)[grep("P$", colnames(x))]
  for (p_col in p_cols) {
    x[paste0(p_col, "_FDR")] <- p.adjust(x[, p_col], method = "BH")
  }
  x
}

#' Linear models
#'
#' Fits a linear model separately for each feature. Returns all relevant
#' statistics.
#'
#' @param object a MetaboSet object
#' @param formula_char character, the formula to be used in the linear model (see Details)
#' @param ci_level the confidence level used in constructing the confidence intervals
#' for regression coefficients
#' @param ... additional parameters passed to lm
#'
#' @return a data frame with one row per feature, with all the
#' relevant statistics of the linear model as columns
#'
#' @details The linear model is fit on combined_data(object). Thus, column names
#' in pData(object) can be specified. To make the formulas flexible, the word "Feature"
#' must be used to signal the role of the features in the formula. "Feature" will be replaced
#' by the actual Feature IDs during model fitting, see the example
#'
#' @examples
#' # A simple example without QC samples
#' # Features predicted by Group and Time
#' results <- perform_lm(drop_qcs(example_set), formula_char = "Feature ~ Group + Time")
#'
#' @seealso \code{\link[stats]{lm}}
perform_lm <- function(object, formula_char,  ci_level = 0.95, ...) {

  data <- combined_data(object)
  features <- Biobase::featureNames(object)

  results <- foreach::foreach(i = seq_along(features), .combine = rbind) %dopar% {
    feature <- features[i]
    # Replace "Feature" with the current feature name
    tmp_formula <- gsub("Feature", feature, formula_char)

    # Try to fit the linear model
    fit <- NULL
    tryCatch({
      fit <- lm(as.formula(tmp_formula), data = data, ...)
    }, error = function(e) print(e$message))
    if(is.null(fit) | sum(!is.na(data[, feature])) < 2){
      result_row <- NULL
    } else {
      # Gather coefficients and CIs to one data frame row
      coefs <- summary(fit)$coefficients
      confints <- confint(fit, level = ci_level)
      coefs <- data.frame(Variable = rownames(coefs), coefs, stringsAsFactors = FALSE)
      confints <- data.frame(Variable = rownames(confints), confints, stringsAsFactors = FALSE)

      result_row <- dplyr::left_join(coefs,confints, by = "Variable") %>%
        dplyr::rename("Std_Error" = "Std..Error", "t_value" ="t.value",
                      "P" = "Pr...t..", "LCI95" = "X2.5..", "UCI95" = "X97.5..") %>%
        tidyr::gather("Metric", "Value", -Variable) %>%
        tidyr::unite("Column", Variable, Metric, sep="_") %>%
        tidyr::spread(Column, Value)
      # Add R2 statistics and feature ID
      result_row$R2 <- summary(fit)$r.squared
      result_row$Adj_R2 <- summary(fit)$adj.r.squared
      result_row$Feature_ID <- feature
      rownames(result_row) <- feature

    }
    result_row

  }

  # FDR correction per column
  results <- adjust_p_values(results)

  # Set a good column order
  variables <- gsub("_P$", "", colnames(results)[grep("P$", colnames(results))])
  statistics <- c("Estimate", "LCI95", "UCI95", "Std_Error", "t_value", "P", "P_FDR")
  col_order <- expand.grid(statistics, variables, stringsAsFactors = FALSE) %>%
    tidyr::unite("Column", Var2, Var1)
  col_order <- c("Feature_ID", col_order$Column, c("R2", "Adj_R2"))

  results[col_order]
}


#' Linear mixed models
#'
#' Fits a linear mixed model separately for each feature. Returns all relevant
#' statistics.
#'
#' @param object a MetaboSet object
#' @param formula_char character, the formula to be used in the linear model (see Details)
#' @param ci_level the confidence level used in constructing the confidence intervals
#' for regression coefficients
#' @param ci_method The method for calculating th confidence intervals, see documentation
#' of confint below
#' @param test_random logical, whether tests for the significance of the random effects should be performed
#' @param ... additional parameters passed to lmer
#'
#' @return a data frame with one row per feature, with all the
#' relevant statistics of the linear mixed model as columns
#'
#' @details The model is fit on combined_data(object). Thus, column names
#' in pData(object) can be specified. To make the formulas flexible, the word "Feature"
#' must be used to signal the role of the features in the formula. "Feature" will be replaced
#' by the actual Feature IDs during model fitting, see the example
#'
#' @examples
#' # A simple example without QC samples
#' # Features predicted by Group and Time as fixed effects with Subject ID as a random effect
#' results <- perform_lmer(drop_qcs(example_set), formula_char = "Feature ~ Group + Time + (1 | Subject_ID)")
#'
#' @seealso \code{\link[lmerTest]{lmer}} for model scpecification and
#' \code{\link[lme4]{confint.merMod}} for the computation of confidence intervals
perform_lmer <- function(object, formula_char,  ci_level = 0.95,
                         ci_method = c("boot", "profile", "Wald"),
                         test_random = FALSE, ...) {

  if (!requireNamespace("lmerTest", quietly = TRUE)) {
    stop('package "lmerTest" required')
  }
  if (!requireNamespace("MuMIn", quietly = TRUE)) {
    stop('package "MuMIn" required')
  }

  # Check that ci_method is one of the accepted choices
  ci_method <- match.arg(ci_method)

  data <- combined_data(object)
  features <- Biobase::featureNames(object)

  results <- foreach::foreach(i = seq_along(features), .combine = rbind, .packages = "lmerTest") %dopar% {

    # Set seed, needed for some of the CI methods
    set.seed(38)

    feature <- features[i]
    # Replace "Feature" with the current feature name
    tmp_formula <- gsub("Feature", feature, formula_char)

    # Try to fit the linear model
    fit <- NULL
    tryCatch({
      fit <- lmer(as.formula(tmp_formula), data = data, ...)
    }, error = function(e) print(e$message))
    if(is.null(fit) | sum(!is.na(data[, feature])) < 2){
      result_row <- NULL
    } else {
      # Gather coefficients and CIs to one data frame row
      coefs <- summary(fit)$coefficients
      confints <- confint(fit, level = ci_level, nsim = 1000, method = ci_method, oldNames = FALSE)
      coefs <- data.frame(Variable = rownames(coefs), coefs, stringsAsFactors = FALSE)
      confints <- data.frame(Variable = rownames(confints), confints, stringsAsFactors = FALSE)

      result_row <- dplyr::left_join(coefs,confints, by = "Variable") %>%
        dplyr::rename("Std_Error" = "Std..Error", "t_value" ="t.value",
                      "P" = "Pr...t..", "LCI95" = "X2.5..", "UCI95" = "X97.5..") %>%
        tidyr::gather("Metric", "Value", -Variable) %>%
        tidyr::unite("Column", Variable, Metric, sep="_") %>%
        tidyr::spread(Column, Value)
      # Add R2 statistics
      R2s <- suppressWarnings(MuMIn::r.squaredGLMM(fit))
      result_row$Marginal_R2 <- R2s[1]
      result_row$Conditional_R2 <- R2s[2]

      # Add optional test results for the random effects
      if(test_random) {
        r_tests <- as.data.frame(ranova(fit))[-1,c(4,6)]
        r_tests$Variable <- rownames(r_tests) %>%
          gsub("[(]1 [|] ", "", .) %>% gsub("[)]", "", .)
        # Get confidence intervals for the standard deviations of the random effects
        confints$Variable <- confints$Variable  %>%
          gsub("sd_[(]Intercept[)][|]", "", .)
        # Get standard deviations of the random effects
        r_variances <- as.data.frame(summary(fit)$varcor)[c("grp", "sdcor")]
        # Join all the information together
        r_result_row <- dplyr::inner_join(r_variances, confints, by = c("grp" = "Variable")) %>%
          dplyr::left_join(r_tests,  by = c("grp" = "Variable")) %>%
          dplyr::rename(SD = sdcor, "LCI95" = "X2.5..", "UCI95" = "X97.5..", "P" = "Pr(>Chisq)") %>%
          tidyr::gather("Metric", "Value", -grp) %>%
          tidyr::unite("Column", grp, Metric, sep="_") %>%
          tidyr::spread(Column, Value)
        result_row <- cbind(result_row, r_result_row)
      }
      # Add feature ID
      result_row$Feature_ID <- feature
      rownames(result_row) <- feature

    }
    result_row
  }

  # FDR correction per column
  results <- adjust_p_values(results)

  # Set a good column order
  fixed_effects <- gsub("_Estimate$", "", colnames(results)[grep("Estimate$", colnames(results))])
  statistics <- c("Estimate", "LCI95", "UCI95", "Std_Error", "t_value", "P", "P_FDR")
  col_order <- expand.grid(statistics, fixed_effects, stringsAsFactors = FALSE) %>%
    tidyr::unite("Column", Var2, Var1)
  col_order <- c("Feature_ID", col_order$Column, c("Marginal_R2", "Conditional_R2"))

  if (test_random) {
    random_effects <- gsub("_SD$", "", colnames(results)[grep("SD$", colnames(results))])
    statistics <- c("SD", "LCI95", "UCI95", "LRT", "P", "P_FDR")
    random_effect_order <- expand.grid(statistics, random_effects, stringsAsFactors = FALSE) %>%
      tidyr::unite("Column", Var2, Var1)
    col_order <- c(col_order, random_effect_order$Column)
  }

  results[col_order]
}

