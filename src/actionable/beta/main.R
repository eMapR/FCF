## run_spatial_model.R

rm(list = ls())
library(terra)
library(geoR)
library(spBayes)
library(yaml)

source("mod.R")

# Load parameters from YAML file
params <- yaml::read_yaml("config.yml")

# Extract parameters
site <- params$site
results_dir <- file.path(params$output_dir, site, "results")

if (!dir.exists(results_dir)) dir.create(results_dir, recursive = TRUE)

# 1. Load and prepare data
data_list <- load_data(site, base_path = params$data_dir)
dat <- data_list$dat
carbon.map <- data_list$carbon.map

model_data <- prepare_model_data(dat)
y <- model_data$y
x <- model_data$x
coords <- model_data$coords

# 2. Fit linear model and check variogram
fit_lm_variogram(y, x, coords, max.dist = params$max_dist)


# 3. Fit spatial model
m.1 <- fit_spatial_model(y, x, coords, params$n_samples,params$n_threads)
save(m.1, file = file.path(results_dir, "m.1.RData"))
q(save = "no", status = 0)

# 4. Predict across raster and save
pred.rast <- predict_spatial(m.1, carbon.map, site, out_dir = params$output_dir, n.threads = params$n_threads)

# 5. Joint prediction (optional, coarser resolution)
pred.rast.joint <- predict_joint(m.1, carbon.map, site, out_dir = params$output_dir, n.threads = params$n_threads)

# 6. Plot results
plot_predictions(pred.rast, carbon.map)
