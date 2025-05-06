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
y <- model_data$y
x <- model_data$x
coords <- model_data$coords

# Plot the scatterplot
plot(x, y, main = "Scatterplot of y vs x",
     xlab = "x", ylab = "y", pch = 19, col = "blue")

# Save the plot as a PNG file
png("plot.png", width = 800, height = 600)
plot(x, y, main = "Scatterplot of y vs x",
     xlab = "x", ylab = "y", pch = 19, col = "blue")
dev.off()

# Create histogram of y
hist(y, main = "Histogram of y",
     xlab = "y", col = "steelblue", border = "white")

# Save histogram to PNG
png("plot.png", width = 800, height = 600)
hist(y, main = "Histogram of y",
     xlab = "y", col = "steelblue", border = "white")
dev.off()

print('Complete!')
