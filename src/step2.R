## run_spatial_model.R

rm(list = ls())
library(terra)
library(geoR)
library(spBayes)
library(yaml)
file.remove("plot.png")

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

# 1. Load and prepare data assets
asset_list <- load_assets(site, base_path = params$data_dir)
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
params2 <- make_params("config.yaml")

m.1 <- fit_spatial_model(y, x, coords, params2)
save(m.1, file = file.path(results_dir, "m.1.RData"))

file.copy("plot.png", file.path(results_dir,"chainImg.png"))

print("Complete!")
