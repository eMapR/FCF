## run_spatial_model.R

rm(list = ls())
library(terra)
library(geoR)
library(spBayes)
library(yaml)
if (file.exists("plot.png")) {
  Sys.sleep(0.1)  # Brief delay for Windows file locking
  invisible(file.remove("plot.png"))
}
source("mod.R")
config_path <- Sys.getenv("FCF_CONFIG_PATH", unset = "config.yaml")
emit_status("Step 3: generating raster predictions.")
emit_status("Typical runtime: this can take hours or even days on large rasters.")
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
raster_coverage <- resolve_raster_coverage_settings(params)
asset_list <- load_assets(
  site,
  base_path = params$data_dir,
  raster_coverage_tolerance = raster_coverage$tolerance,
  strict_raster_coverage = raster_coverage$strict
)
pts <- asset_list$pts
carbon.map <- asset_list$carbon.map

model_data <- prepare_model_data(pts)

load(file.path(results_dir, "m.1.RData"))

# 4. Predict across raster and save
emit_status("Starting per-pixel prediction. This is usually the longest part.")
pred.rast <- predict_spatial(m.1, carbon.map, site, out_dir = params$output_dir, n.threads = params$n.threads)
emit_status("Per-pixel prediction finished. Writing pred.tif and m.1.pred.RData.")

# 5. Joint prediction (optional, coarser resolution)
emit_status("Starting joint prediction for aggregation-friendly uncertainty output.")
pred.rast.joint <- predict_joint(m.1, carbon.map, site, out_dir = params$output_dir, n.threads = params$n.threads)
emit_status("Joint prediction finished. Writing pred-joint.tif and m.1.pred.joint.RData.")

# 6. Plot results
png("plot.png", width = 1000, height = 700)
plot_predictions(pred.rast, carbon.map)
dev.off()


emit_status("Step 3 complete.")
emit_status("Both output styles were generated from this run.")
emit_status("STEP_COMPLETE: step3")
