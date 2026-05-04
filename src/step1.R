## run_spatial_model.R

rm(list = ls())
library(terra)
library(geoR)
library(spBayes)
library(yaml)

source("mod.R")
config_path <- Sys.getenv("FCF_CONFIG_PATH", unset = "config.yaml")
emit_status("Step 1: fitting the non-spatial model and computing the variogram.")
emit_status("Typical runtime: seconds to a few minutes.")
emit_status(sprintf("Using config file: %s", config_path))

# check yaml file path exists
check_yaml_exists_and_valid(config_path)

# Load parameters from YAML file
params <- yaml::read_yaml(config_path)

# check yaml format 
if (!validate_config(params)) {
  stop("Configuration validation failed.")
}

# Extract parameters
site <- params$site

# make and generate output directory 
results_dir <- file.path(params$output_dir, site)
if (!dir.exists(results_dir)) dir.create(results_dir, recursive = TRUE)

# 1. Load and prepare data assets
asset_list <- load_assets(site, base_path = params$data_dir)
pts <- asset_list$pts
carbon.map <- asset_list$carbon.map

model_data <- prepare_model_data(pts)
y <- model_data$y
x <- model_data$x
coords <- model_data$coords


# 2. Fit linear model and check variogram
result <- fit_lm_variogram(y, x, coords, max.dist = params$max.dist)

invisible(file.copy("plot.png", file.path(results_dir, "semivariogram.png"), overwrite = TRUE))


vario <- result$variogram

# Estimate directly:
nugget_estimate <- vario$v[1]
fitted_sill <- result$fitted_sill
emit_status(sprintf("Estimated Nugget: %.6f", nugget_estimate))
emit_status(sprintf("Fitted Sill: %.6f", fitted_sill))

emit_status("Step 1 complete.")
emit_status("STEP_COMPLETE: step1")
