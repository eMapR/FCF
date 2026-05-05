## run_spatial_model.R

rm(list = ls())
library(terra)
library(geoR)
library(spBayes)
library(yaml)

source("mod.R")

config_path <- Sys.getenv("FCF_CONFIG_PATH", unset = "config.yaml")
emit_status("Step 0: validating inputs and loading assets.")
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

data_dir <- normalizePath(file.path(params$data_dir, site), mustWork = FALSE)
bnd_path <- normalizePath(file.path(data_dir, "bnd", "bnd.shp"), mustWork = FALSE)
dat_path <- normalizePath(file.path(data_dir, "plots", "plots.shp"), mustWork = FALSE)
carbon_map_path <- normalizePath(file.path(data_dir, "carbon-map.tif"), mustWork = FALSE)


# Check base directory
check_dir_exist(data_dir)

# Check shapefile 1 existence
check_shapefile_exist(bnd_path)

# Check shapefile 2 existence
check_shapefile_exist(dat_path)

# Check shapefile 1 for features
check_shapefile_for_features(bnd_path)

# Check shapefile 2 for features
check_shapefile_for_features(dat_path)

# Check shapefile 2 for required field
check_shapefile_for_field(dat_path, "Total.Carb")

# Check raster file existence
check_raster_exist(carbon_map_path)

# Check raster for expected bands
check_raster_for_band(carbon_map_path)

# Check CRS consistency across inputs
check_crs_match(bnd_path, dat_path, carbon_map_path)

# Check raster coverage over boundary
raster_coverage_tolerance <- params$raster.coverage.tolerance
if (is.null(raster_coverage_tolerance)) {
  raster_coverage_tolerance <- 0
}

strict_raster_coverage <- params$strict.raster.coverage
if (is.null(strict_raster_coverage)) {
  strict_raster_coverage <- TRUE
}

check_raster_covers_boundary(
  bnd_path,
  carbon_map_path,
  tolerance = raster_coverage_tolerance,
  strict = strict_raster_coverage
)



# 1. Load and prepare data assets
asset_list <- load_assets(site, base_path = params$data_dir)
pts <- asset_list$pts
carbon.map <- asset_list$carbon.map

model_data <- prepare_model_data(pts)
y <- model_data$y
x <- model_data$x
coords <- model_data$coords

# Plot the scatterplot
#plot(x, y, main = "Scatterplot of y vs x",
#     xlab = "x", ylab = "y", pch = 19, col = "blue")

# Save the plot as a PNG file
#png("plot.png", width = 800, height = 600)
#plot(x, y, main = "Scatterplot of y vs x",
#     xlab = "x", ylab = "y", pch = 19, col = "blue")
#dev.off()

# Create histogram of y
#hist(y, main = "Histogram of y",
#     xlab = "y", col = "steelblue", border = "white")

# Save histogram to PNG
#png("plot.png", width = 800, height = 600)
#hist(y, main = "Histogram of y",
#     xlab = "y", col = "steelblue", border = "white")
#dev.off()

emit_status("Input validation complete.")
emit_status("STEP_COMPLETE: step0")
