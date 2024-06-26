#' Select which GWAS to run
#'
#' @description Given the type of input to the GWAS program, run either the
#'   continuous test or both of the discrete tests (Synchronous and PhyC).
#' @param args Object with all of the user provided inputs necessary to run the
#'   gwas.
#'
#' @noRd
select_test_type <- function(args){
  # Check inputs ---------------------------------------------------------------
  check_str_is_discrete_or_continuous(args$discrete_or_continuous)

  # Function -------------------------------------------------------------------
  if (args$discrete_or_continuous == "continuous") {
    run_continuous(args)
    print("[EDIT] Starting continuous test...")
  } else {
    if (args$test == "both") {
      run_synchronous(args)
      run_phyc(args)
      print("[EDIT] Starting synchronous test...")
      print("[EDIT] Starting phyc test...")
    }
    else if (args$test == "phyc") {
      run_phyc(args)
    }
    else if (args$test == "synchronous") {
      run_synchronous(args)
      print("[EDIT] Starting synchronous test...")
    }
  }
}
