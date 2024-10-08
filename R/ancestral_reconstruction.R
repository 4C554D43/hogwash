#' Calculate ancestral reconstruciton with maximum likelihood approach
#'
#' @description Compute ancestral reconstruction from a continuous phenotype or
#'   discrete genotype or phenotype.
#'
#' @details Note on the marginal setting in the function ape::ace(). Marginal =
#'   FALSE means that the marginal is in fact calculated. Do not set marginal to
#'   TRUE, because this only does the condition (only downstream edges
#'   considered). Ace never calculates the joint distribution.
#'
#' @param tr Phylo. Rooted phylogenetic tree.
#' @param mat Matrix. Either the phenotype matrix or the genotype matrix. Dim:
#'   nrow = Ntip(tr) x ncol = {1 if phenotype or number of genotypes}.
#' @param num Numeric. Indicating the row of the matrix from which the ancestral
#'   reconstruction is to be built.
#' @param disc_cont Character. Either "discrete" or "continuous."
#'
#' @return Returns a list with multiple elements:
#'   \describe{
#'     \item{node_anc_rec}{Vector. Ancestral reconstruction for each node.
#'     Length = Nnode(tr).}
#'      \item{tip_and_node_rec_conf}{A vector with a 1 for each tip with the
#'      node ancestral reconstruction confidence appended. Length = Nnode(tr) +
#'      Ntip(tr).}
#'     \item{recon_edge_mat}{Matrix. Ancestral reconstruction configured into
#'     the edge matrix. Dim: nrow = Nedge(tr) x ncol = 2. 1st column == parent
#'     node. 2nd column == child node.}
#'     \item{tip_and_node_recon}{A vector with the tip values followed by the
#'     node ancestral reconstruction. Length == Ntip(tr) + Nnode(tr).}
#'   }
#'
#' @noRd
ancestral_reconstruction_by_ML <- function(tr, mat, num, disc_cont){
  # Check input ----------------------------------------------------------------
  check_is_string(disc_cont)
  check_for_root_and_bootstrap(tr)
  check_tree_is_valid(tr)
  check_is_number(num)
  check_class(mat, "matrix")
  check_str_is_discrete_or_continuous(disc_cont)

  # Function -------------------------------------------------------------------
  # Compute ancestral reconstruction
  ML_significance_threshold <- .875 # ML literature suggests that a ratio of 7:1
                                    # suggests a high confidence ancestral
                                    # reconstruction per node .875/.125 = 7.

  if (disc_cont == "continuous") {
    # RECONSTRUCTION
    recon_method <- "REML" # REML as per ape::ace documentation recommendations

    cont_results <- continuous_ancestral_reconstruction(tr,
                                                        mat,
                                                        num,
                                                        disc_cont,
                                                        recon_method)
    ML_anc_rec <- cont_results$ML_anc_rec
    tip_and_node_recon <- cont_results$tip_and_node_recon

    # CONFIDENCE IN RECONSTRUCTION
    tip_and_node_anc_rec_conf <-
      continuous_get_recon_confidence(tip_and_node_recon)

  } else {
    # This is always the choice for genotypes and discrete phenotypes
    # RECONSTRUCTION
    recon_method <- "ML" # ML as per ape::ace documentation recommendations

    discrete_results <-
      discrete_ancestral_reconstruction(tr, mat, num, disc_cont, recon_method)
    ML_anc_rec <- discrete_results$ML_anc_rec
    tip_and_node_recon <- discrete_results$tip_and_node_recon

    # CONFIDENCE IN RECONSTRUCTION
    tip_and_node_anc_rec_conf <-
      discrete_get_recon_confidence(discrete_results$reconstruction,
                                    tr,
                                    ML_significance_threshold)
  }
  reconstruction_as_edge_mat <- convert_to_edge_mat(tr, tip_and_node_recon)

  # Return outputs -------------------------------------------------------------
  results <- list("node_anc_rec" = ML_anc_rec,
                  "tip_and_node_rec_conf" = tip_and_node_anc_rec_conf,
                  "recon_edge_mat" = reconstruction_as_edge_mat,
                  "tip_and_node_recon" = tip_and_node_recon)
  return(results)
}

#' Perform ancestral reconstruction for continuous data
#'
#' @description Perform ancestral state reconstruction using ape::ace() function
#'   on continuous phenotype.
#'
#' @param tr Phylo.
#' @param mat Matrix. Continuous phenotype. Dim: nrow = Ntip(tr) x ncol = 1.
#' @param num  Number. Column index for matrix.
#' @param disc_cont Character string. Must be "continuous."
#' @param recon_method Character string. Either "ML", "REML", "pic", or "GLS."
#'
#' @return List of two elements:
#'   \describe{
#'     \item{ML_anc_rec}{Reconstruction values for each node.}
#'     \item{tip_and_node_recon}{Vector. Phenotype values for each tip followed
#'     by the ancestral reconstruction at each node. Length = Ntip(tr) +
#'     Nnode(tr).}
#'   }
#'
#' @noRd
continuous_ancestral_reconstruction <- function(tr,
                                                mat,
                                                num,
                                                disc_cont,
                                                recon_method){
  # Check inputs ---------------------------------------------------------------
  check_anc_rec_compatible(recon_method)
  check_is_string(disc_cont)
  check_str_is_discrete_or_continuous(disc_cont)
  check_for_root_and_bootstrap(tr)
  check_tree_is_valid(tr)
  check_is_number(num)
  check_dimensions(mat,
                   exact_rows = ape::Ntip(tr),
                   min_rows = ape::Ntip(tr),
                   exact_cols = 1,
                   min_cols = 1)

  # Function -------------------------------------------------------------------
  set.seed(1)
  reconstruction <- suppressWarnings(ape::ace(mat[, num, drop = TRUE],
                                              tr,
                                              model = "BM",
                                              type = disc_cont,
                                              method = recon_method,
                                              marginal = FALSE))

  # Vector containing reconstruction data for all internal nodes N+ where tips
  # are 1-N.
  ML_anc_rec <- reconstruction$ace
  tip_and_node_recon <- c(mat[, num, drop = TRUE], ML_anc_rec)
  names(tip_and_node_recon) <- c(1:sum(ape::Ntip(tr), ape::Nnode(tr)))

  # Return output --------------------------------------------------------------
  return(list("ML_anc_rec" = ML_anc_rec,
              "tip_and_node_recon" = tip_and_node_recon))
} # end continuous_ancestral_reconstruction()

#' Create a confidence vector for the continuous trait reconstruction
#'
#' @description Given a vector of a continuous trait reconstruction, generate a
#'   dummy confidence vector. Ancestral reconstruction for continuous values
#'   only gives back a 95% CI. We can't use any of this information to decide
#'   which nodes are low confidence so treat all reconstructed values as high
#'   confidence, which is stored as a value 1.fv
#'
#' @param recon_vector Numeric vector. Values of the reconstruction. Length ==
#'   Ntip(tr) + Nnode(tr).
#'
#' @return tip_and_node_anc_rec_conf: Vector of all 1s, indicating 'high'
#'   confidence. Length == Ntip(tr) + Nnode(tr). Tips folowed by nodes.
#'
#' @noRd
continuous_get_recon_confidence <- function(recon_vector){
  # Check input ----------------------------------------------------------------
  if (!is.vector(recon_vector)) {
    stop("input must be a vector")
  }
  check_is_number(recon_vector[1])

  # Function -------------------------------------------------------------------
  tip_and_node_anc_rec_conf <- rep(1, length(recon_vector))

  # Return output --------------------------------------------------------------
  return(tip_and_node_anc_rec_conf)
}

#' Convert a vector to an edge matrix
#'
#' @description Convert the reconstruction to be in the same format as
#'   tree$edge, where each row is an edge. This format will make it much easier
#'   to calculate the phenotype change on each edge for continuous phenotypes.
#'
#' @param tr Phylo.
#' @param tip_and_node_reconstruction Vector. Ordered by tips then by nodes.
#'   Length = Ntip(tr) = Nnode(tr). Observed values at each tip and ancestral
#'   reconstruction values at each node.
#'
#' @return reconstruction_as_edge_mat. Matrix. Dim = nrow = Ntip(tr) x ncol = 2.
#'   1st column = parent node. 2nd column = child node. Ancestral reconstruction
#'   values for each node.
#'
#' @noRd
convert_to_edge_mat <- function(tr, tip_and_node_reconstruction){
  # Check inputs ---------------------------------------------------------------
  check_tree_is_valid(tr)
  check_for_root_and_bootstrap(tr)
  check_equal(length(tip_and_node_reconstruction),
              ape::Nnode(tr) + ape::Ntip(tr))

  # Function -------------------------------------------------------------------
  reconstruction_as_edge_mat <- tr$edge
  for (k in 1:nrow(reconstruction_as_edge_mat)) {
    reconstruction_as_edge_mat[k, 1] <-
      tip_and_node_reconstruction[tr$edge[k, 1]]
    reconstruction_as_edge_mat[k, 2] <-
      tip_and_node_reconstruction[tr$edge[k, 2]]
  }

  # Return output --------------------------------------------------------------
  return(reconstruction_as_edge_mat)
}

#' Perform ancestral reconstruction of discrete data
#'
#' @description Perform ancestral state reconstruction using ape::ace() function
#'   on discrete phenotype or genotype. The best model to describe the
#'   probabilities of state changes is decided by the subfunction:
#'   build_better_reconstruction(), which chooses either "'"ARD", all rates
#'   different, or "ER", equal rates and returns the better of the two
#'   reconstructions.
#'
#' @param tr Phylo.
#' @param mat Matrix. Genotype or discrete phenotype matrix.
#' @param num Number. Column index for matrix.
#' @param disc_cont Character. Should always be "discrete."
#' @param recon_method Character string. Either "ML", "REML", "pic", or "GLS."
#'
#' @return List with multiple elements:
#'   \describe{
#'     \item{ML_anc_rec}{Vector. Reconstruction (numeric) at node values only.
#'     Length = Nnode(tr).}
#'     \item{tip_and_node_recon}{A vector with the tip values followed by the
#'     node ancestral reconstruction. Length = Nnode(tr) + Ntip(tr).}
#'     \item{reconstruction}{Ape::ace() object. Contains multiple pieces of
#'       information. Class = "ace." Type = "list".
#'       \describe{
#'         \item{loglik}{Number. Log likelihood of the ancestral
#'         reconstruction.}
#'         \item{rates}{Number.}
#'         \item{se}{Number. Standard error.}
#'         \item{index.matrix}{Matrix.}
#'         \item{lik.anc}{Matrix. Likelihood for each state at each tree node}
#'         \item{call}{Record of the `ace()` call. Class = "call."}
#'       }
#'     }
#'   }
#'
#' @noRd
discrete_ancestral_reconstruction <- function(tr,
                                              mat,
                                              num,
                                              disc_cont,
                                              recon_method){
  # Check inputs ---------------------------------------------------------------
  check_anc_rec_compatible(recon_method)
  check_is_string(disc_cont)
  check_str_is_discrete_or_continuous(disc_cont)
  check_for_root_and_bootstrap(tr)
  check_tree_is_valid(tr)
  check_is_number(num)
  check_class(mat, "matrix")
  if (disc_cont != "discrete") {
    stop("Discrete ancestral reconstruction only")
  }

  # Function -------------------------------------------------------------------
  set.seed(1)
  reconstruction <-
    build_better_reconstruction(mat, tr, disc_cont, num, recon_method)
   cat("build_better_reconstruction() PASSED.")
  cat(mat)
  cat(tr)
  cat(disc_cont)
  cat(num)
  cat(recon_method)
  # Extract the mostly likely character state using which.max
  ML_anc_rec <-
    as.numeric(colnames(reconstruction$lik.anc)[apply(reconstruction$lik.anc,
                                                      1,
                                                      which.max)])
  names(ML_anc_rec) <- c( (ape::Ntip(tr) + 1):(ape::Ntip(tr) + ape::Nnode(tr)))
  tip_and_node_recon <- c(mat[, num, drop = TRUE], ML_anc_rec)
  names(tip_and_node_recon) <- c(1:sum(ape::Ntip(tr), ape::Nnode(tr)))

  # Return outputs -------------------------------------------------------------
  return(list("tip_and_node_recon" = tip_and_node_recon,
              "ML_anc_rec" = ML_anc_rec,
              "reconstruction" = reconstruction))
}

#' Identify high confidence ancestral reconstruction nodes
#'
#' @description Given the ancestral reconstruction identify which nodes are high
#'   confidence based on the maximum likelihood of the reconstruction and the
#'   confidence treshold (0.875; a ratio of about 7:1; based on ML literature).
#'   Confidence at the tips is assigned 1 because these values were measured and
#'   therefore have total confidence in the value.
#'
#' @param recon Ape::ace() object. Contains multiple pieces of information.
#'   Class = "ace." Type = "list." Ancestral reconstruction.
#'   \describe{
#'     \item{loglik}{Number. Log likelihood of the ancestral
#'     reconstruction.}
#'     \item{rates}{Number.}
#'     \item{se}{Number. Standard error.}
#'     \item{index.matrix}{Matrix.}
#'     \item{lik.anc}{Matrix. Likelihood for each state at each tree node}
#'     \item{call}{Record of the `ace()` call. Class = "call."}
#'   }
#' @param tr Phylo.
#' @param ML_cutoff Number between 0 and 1. If the maximum likelihood of the
#'   reconstruction is above this number it's considered a high confidence
#'   reconstruction, otherwise it's a low confidence reconstruction.
#'
#' @noRd
discrete_get_recon_confidence <- function(recon, tr, ML_cutoff){
  # Check input ----------------------------------------------------------------
  check_for_root_and_bootstrap(tr)
  check_tree_is_valid(tr)
  check_num_between_0_and_1(ML_cutoff)
  # Function -------------------------------------------------------------------

  # Get the highest confidence value at each node
  anc_rec_confidence <- apply(recon$lik.anc, 1, max)

  # Count all tips as high confidence
  tip_and_node_anc_rec_conf <- c(rep(1, ape::Ntip(tr)), anc_rec_confidence)

  # Count anything lower than threshold as low confidence
  tip_and_node_anc_rec_conf <-
    discretize_conf_with_cutoff(tip_and_node_anc_rec_conf, ML_cutoff)

  # Return output --------------------------------------------------------------
  return(tip_and_node_anc_rec_conf)
}

#' Reconstruct discrete data and return reconstruction built with the better
#' model
#'
#' @description Given a discrete genotype or phenotype, build an ancestral
#'   reconstruction using an equal rates model ("ER") and then repeat with an
#'   all rates different model ("ARD"). Choose the best model based on p-value
#'   from likelihood ratio test and difference in AIC. Return the better
#'   reconstruction.
#'
#' @param mat Matrix. Genotype or phenotype binary matrix. (Only discrete
#'   phenotype). Dim: genotype: ncol = ntip(tree) x nrow = number of genotypes.
#'   phenotype: ncol = ntip(tree) x nrow = 1.
#' @param tr Phylo.
#' @param disc_cont String. "discrete" or "continuous."
#' @param num Number. Column index for matrix.
#' @param recon_method String. Either "ML", "REML", "pic", or "GLS".
#'
#' @return Reconstruction of class `ace` from `ape`.
#'
#' @noRd
build_better_reconstruction <- function(mat, tr, disc_cont, num, recon_method){
  # Check input ----------------------------------------------------------------
  check_tree_is_valid(tr)
  check_if_binary_matrix(mat)
  check_is_string(disc_cont)
  check_is_number(num)
  check_is_string(recon_method)
  check_anc_rec_compatible(recon_method)
  cat("build_better_reconstruction() checks PASSED.")
  if (disc_cont != "discrete") {
    stop("Only pick recon model for discrete. Continuous must use BM.")
  }
  if (num > ncol(mat)) {
    stop("Index must be 1 <= index <= ncol(matrix)")
  }
  check_dimensions(mat = mat,
                   exact_rows = ape::Ntip(tr),
                   min_rows = ape::Ntip(tr),
                   exact_cols = NULL,
                   min_cols = 1)
  cat("build_better_reconstruction.check_dimensions() PASSEDTEST.")
  # Function -------------------------------------------------------------------
  # Note, SYMreconstruction removed because SYM == ER for binary inputs.
  # Use this function to choose the best model for reconstruction.
  cat("CODE FAILS HERE\n")
  # Cutoffs for comparing the ER and ARD:
  alpha <- 0.05 # For likelihood test
  significant_difference_in_AIC <- 10

  # Reference for model testing:
  # https://www.r-phylo.org/wiki/HowTo/Ancestral_State_Reconstruction &
  # http://blog.phytools.org/2017/07/comparing-fitted-discrete-character.html
  # Test ER vs ARD
  set.seed(1)
  cat("CODE FAILS HERE\n")
  ERreconstruction  <- ape::ace(mat[, num, drop = TRUE],
                                        tr,
                                        type = disc_cont,
                                        method = recon_method,
                                        marginal = FALSE,
                                        model = "ER") #remove suppresswarnings
  cat("build_better_reconstruction.ERreconstruction() PASSED.")
  # Some ARD models don't work well with the data and given a warning message
  # like:  "In sqrt(diag(solve(h))) : NaNs produced".  To ensure the ER model is
  # preferred in this case use the following warning catching:
  error_msg <- "ARD_bad_fit"
  set.seed(1)
  ARDreconstruction <- tryCatch(ape::ace(mat[, num, drop = TRUE],
                                    tr,
                                    type = disc_cont,
                                    method = recon_method,
                                    marginal = FALSE,
                                    model = "ARD"),
                                warning = function(x) {
    error_msg
    }
  )
    cat("build_better_reconstruction.ARDreconstruction) PASSED.")
  # If ARD gave a warning, pick ER
  best_model <- "ER"
  if (length(ARDreconstruction) == 1) {
    best_model <- "ER"
  } else {
    # Pick best of ER and ARD
    p_ER_ARD <-
      1 - stats::pchisq(
        2 * abs(ERreconstruction$loglik - ARDreconstruction$loglik), 1)
    if (p_ER_ARD < alpha &
        stats::AIC(ERreconstruction) >
        (significant_difference_in_AIC + stats::AIC(ARDreconstruction))) {
      best_model <- "ARD"
    }
  }

  # Given best model, return best ancestral reconstruction
  best_reconstruction <- ERreconstruction
  if (best_model == "ARD") {
    best_reconstruction <- ARDreconstruction
  }

  # Return output --------------------------------------------------------------
  cat("end build_better_reconstruction")
  return(best_reconstruction)
}

#' prepare_ancestral_reconstructions
#'
#' @description Run ancestral reconstructions for phenotype and genotypes.
#'   Return ancestral reconstruction values at each tip, edge, and node in the
#'   tree for both the genotype(s) and phenotype. Additionally, for genotype(s)
#'   and binary phenotypes identify each edge in the tree as either a transition
#'   (values at edge-defining nodes unequal) or not a transition (values at
#'   edge-defining nodes equal).
#'
#' @param tr Phylo.
#' @param pheno Matrix. Dim: nrow = Ntip(tr) x ncol = 1.
#' @param geno Matrix. Binary. Dim: nrow = Ntip(tr) x ncol = number of genotypes.
#' @param disc_cont Character string. Either "discrete" or "continuous."
#'
#' @return List of lists:
#'   \describe{
#'     \item{pheno_recon_and_conf}{List of multiple objects.
#'       \describe{
#'         \item{node_anc_rec}{The values of the ancestral reconstruction of the
#'          phenotype at each internal node. Length = Nnode(tr).}
#'         \item{tip_and_node_rec_conf}{A binary numeric vector. Each entry
#'         corresponds to a tip or node in the tree. 1 indicates high confidence
#'         in the ancestral reconstruction of the phenotype, while 0 incidates
#'         low confidence. Length = Ntip(tr) + Nnode(tr). Ordered by tips then
#'         by nodes.}
#'         \item{recon_edge_mat}{Matrix. Dim: nrow = Nedge(tr) x ncol = 2.
#'         Parent (older) node is 1st column. Child (younger) node is the 2nd
#'         column. Ancestral reconstruction value of each node.}
#'         \item{tip_and_node_recon}{Numeric vector. Observed value at each tip
#'         followed ancestral reconstruction value at each tree node. Length =
#'         Ntip(tr) + Nnode(tr).}
#'       }
#'     }
#'     \item{geno_recon_and_conf}{List of lists. 1 list per genotype in the genotype
#'      matrix. Each sublist has the same four objects as pheno_recon_and_conf
#'      above: $node_anc_rec, $tip_and_node_rec_conf, $recon_edge_mat, and
#'      $tip_and_node_recon.
#'        \describe{
#'          \item{geno_trans}{List of vectors. One list entry for each genotype.
#'          Each list entry has two vectors.
#'            \describe{
#'              \item{transition}{Length = Nedge(tr). Binary, numeric vector. 0
#'              indicates no transition (parent and child node equal). 1
#'              indicates a transition across the edge (parent node != child
#'              node).}
#'              \item{trans_dir}{Length = Nedge(tr). Numeric vector. Values
#'              should be -1, 0, or 1. -1 0 indicate no transition and therefore
#'              no direction of the transition. 1 indicates the parent is less
#'              than the child (discrete case: parent == 0 & child == 1). 0
#'              indicates the parent is greater thanthe child (discrete case:
#'              parent == 1 & child == 0).}
#'            }
#'          }
#'        }
#'     }
#'   }
#'
#' @noRd
prepare_ancestral_reconstructions <- function(tr, pheno, geno, disc_cont){
  # Check input ----------------------------------------------------------------
  check_for_root_and_bootstrap(tr)
  check_str_is_discrete_or_continuous(disc_cont)
  check_dimensions(pheno,
                   exact_rows = ape::Ntip(tr),
                   min_rows = ape::Ntip(tr),
                   min_cols = 1,
                   exact_cols = 1)
  check_dimensions(geno,
                   exact_rows = ape::Ntip(tr),
                   min_rows = ape::Ntip(tr),
                   min_cols = 1)
  check_if_binary_matrix(geno)

  # Function -------------------------------------------------------------------
  pheno_recon_and_conf <-
    ancestral_reconstruction_by_ML(tr, pheno, 1, disc_cont)
  geno_recon_and_conf <- geno_trans <- rep(list(0), ncol(geno))
  for (k in 1:ncol(geno)) {
    geno_recon_and_conf[[k]] <-
      ancestral_reconstruction_by_ML(tr, geno, k, "discrete")
  }

  twenty_five_percent_finished <- floor(ncol(geno) / 4)
  fifty_percent_finished <- floor(ncol(geno) / 2)
  seventy_five_percent_finished <- floor(ncol(geno) * 3 / 4)

  for (k in 1:ncol(geno)) {
    if (k == twenty_five_percent_finished) {
      print(paste0("Ancestral reconstruction 25% complete: ", Sys.time()))
    }
    if (k == fifty_percent_finished) {
      print(paste0("Ancestral reconstruction 50% complete: ", Sys.time()))
    }
    if (k == seventy_five_percent_finished) {
      print(paste0("Ancestral reconstruction 75% complete: ", Sys.time()))
    }
    geno_trans[[k]] <-
      identify_transition_edges(tr,
                                geno,
                                k,
                                geno_recon_and_conf[[k]]$node_anc_rec,
                                "discrete")
  }

  # Return output --------------------------------------------------------------
  results <- list("pheno_recon_and_conf" = pheno_recon_and_conf,
                  "geno_recon_and_conf" = geno_recon_and_conf,
                  "geno_trans" = geno_trans)
  return(results)
}
