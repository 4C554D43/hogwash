#' Check format of user provided data
#'
#' @description Check that all of the inputs into hogwash are in the valid
#'   format.
#' @param pheno Matrix. Phenotype matrix row.names should be the same as the
#'   tr$tip.label and exactly 1 column. Phenotype rownames should be in the same
#'   order as the tr$tip.label.
#' @param tr Phylo. Tree.
#' @param geno Matrix. Genotype matrix should have same rows as tr$tip.label, at
#'   least 2 genotypes in the columns. Genotype rownames should be in the same
#'   order as the tr$tip.label.
#' @param name Character. Output name (prefix).
#' @param dir Character. Output path.
#' @param perm Number. Times to shuffle the data on the tree to create a null
#'   distribution for the permutation test.
#' @param fdr Number. False discovery rate. Between 0 and 1.
#' @param bootstrap Number. Confidence threshold for tree bootstrap values.
#' @param group_genotype_key Either NULL or a matrix. Dimenions: nrow = number
#'   of unique genotypes, ncol = 2.
#' @param grouping_method Character. Either "pre-ar" or "post-ar". Default =
#'   "post_ar". Determines which grouping method is used if and only if a
#'   group_genotype_key is provided; if no key is provided this argument is
#'   ignored.
#' @param test Character. Default = "both". User can supply three options:
#'   "both", "phyc", or "synchronous". Determines which test is run for binary
#'   data.
#' @param tr_type Characer. Default = "phylogram". User can supply either:
#'   "phylogram" or "fan." Determines how the trees are plotted in the output.
#' @param strain_key Matrix. Row names = samples in tree$tip order. 1 column.
#'   Used in output tree plots to color code tree tips with user-supplied strain
#'   names. Strain names (or whatever category schema user desires) are supplied
#'   as character strings in matrix. Default = NULL.
#' @return discrete_or_continuous. Character. Either "discrete" or "continuous".
#'   Describes the input phenotype.
#' @noRd
check_input_format <- function(pheno,
                               tr,
                               geno,
                               name,
                               dir,
                               perm,
                               fdr,
                               bootstrap,
                               group_genotype_key,
                               group_method,
                               test,
                               tr_type,
                               strain_key){
  # Check input ----------------------------------------------------------------

  #edit
  print(paste("[EDIT]: phenotype matrix has ", nrow(pheno), " rows and ", ncol(pheno) ," columns "))
  print(paste("[EDIT]: genotype matrix has ", nrow(geno), " rows and ", ncol(geno) ," columns "))
  #end edit
  
  check_dimensions(geno, ape::Ntip(tr), 2, NULL, 2)
  check_dimensions(pheno, ape::Ntip(tr), 2, 1, 1)
  check_rownames(geno, tr)
  check_rownames(pheno, tr)
  check_for_NA_and_inf(geno)
  check_for_NA_and_inf(pheno)
  check_if_binary_matrix(geno)
  check_is_string(name)
  check_if_dir_exists(dir)
  check_if_permutation_num_valid(perm)
  check_num_between_0_and_1(fdr)
  check_num_between_0_and_1(bootstrap)
  if (!is.null(group_genotype_key)) {
    check_class(group_genotype_key, "matrix")
    check_dimensions(group_genotype_key,
                     min_rows = 1,
                     exact_cols = 2,
                     min_cols = 2)
    check_for_NA_and_inf(group_genotype_key)
  }
  if (ape::Ntip(tr) < 7) {
    stop("Tree must have at least 7 tips")
  }
  check_is_string(test)
  if (!test %in% c("both", "phyc", "synchronous")) {
    stop("If providing a binary test choice select either: both, phyc, or synchronous")
  }
  check_is_string(group_method)
  if (!group_method %in% c("post-ar", "pre-ar")) {
    stop("If grouping the genotype please select either: post-ar or pre-ar")
  }
  check_is_string(tr_type)
  if (!tr_type %in% c("phylogram", "fan")) {
    stop("Select either: phylogram or fan for tree_type")
  }
  if (!is.null(strain_key)) {
    check_class(strain_key, "matrix")
    check_dimensions(strain_key,
                     min_rows = 1,
                     exact_cols = 1,
                     min_cols = 1)
    check_for_NA_and_inf(strain_key)
  }
  # Function -------------------------------------------------------------------
  discrete_or_continuous <- assign_pheno_type(pheno)

  # Check and return output ----------------------------------------------------
  check_is_string(discrete_or_continuous)
  return(discrete_or_continuous)
}
