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
emit_status("Step 2: fitting the Bayesian spatial model.")
emit_status("Typical runtime: minutes to many hours, depending on raster size and sampling settings.")
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
y <- model_data$y
x <- model_data$x
#coords <- model_data$coords

# Remove duplicate coordinate rows
# Combine everything into one data frame
df <- data.frame(x = model_data$x,
                 y = model_data$y,
                 coord1 = model_data$coords[,1],
                 coord2 = model_data$coords[,2])

# Remove duplicate coordinate rows
df_unique <- df[!duplicated(df[, c("coord1", "coord2")]), ]

# Reassign variables
x <- df_unique$x
y <- df_unique$y
coords <- as.matrix(df_unique[, c("coord1", "coord2")])


# 3. Fit spatial model
params2 <- make_params(config_path)

emit_status("Starting MCMC sampling.")
m.1 <- fit_spatial_model(y, x, coords, params2)
save(m.1, file = file.path(results_dir, "m.1.RData"))

invisible(file.copy("plot.png", file.path(results_dir, "chainImg.png"), overwrite = TRUE))

emit_status("Spatial model saved to disk.")
emit_status("Step 2 complete.")
emit_status("STEP_COMPLETE: step2")
