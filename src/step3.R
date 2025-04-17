## run_spatial_model.R

rm(list = ls())
library(terra)
library(geoR)
library(spBayes)
library(yaml)

source("mod.R")

# check yaml file path exists
check_yaml_exists_and_valid("config.yaml")

# Load parameters from YAML file
params <- yaml::read_yaml("config.yaml")

# check yaml format 
validate_config(params)

# Extract parameters
site <- params$site

# make and generate output directory 
results_dir <- file.path(params$output_dir, site, "results")
if (!dir.exists(results_dir)) dir.create(results_dir, recursive = TRUE)

# 1. Load and prepare data assets
asset_list <- load_assets(site, base_path = params$data_dir)
pts <- asset_list$pts
carbon.map <- asset_list$carbon.map

model_data <- prepare_model_data(pts)

load(file.path(results_dir, "m.1.RData"))

# 4. Predict across raster and save
pred.rast <- predict_spatial(m.1, carbon.map, site, out_dir = params$output_dir, n.threads = params$n.threads)

# 5. Joint prediction (optional, coarser resolution)
pred.rast.joint <- predict_joint(m.1, carbon.map, site, out_dir = params$output_dir, n.threads = params$n.threads)

# 6. Plot resultsx
plot_predictions(pred.rast, carbon.map)
