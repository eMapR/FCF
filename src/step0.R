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
results_dir <- file.path(params$output_dir, site)
if (!dir.exists(results_dir)) dir.create(results_dir, recursive = TRUE)

data_dir <- file.path(params$data_dir, site)
bnd_path <- file.path(data_dir, "bnd/bnd.shp")
dat_path <- file.path(data_dir, "plots/plots.shp")
carbon_map_path <- file.path(data_dir, "carbon-map.tif")


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

print('Complete!')
