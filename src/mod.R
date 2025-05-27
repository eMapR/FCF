## spatial_model_functions.R

check_yaml_exists_and_valid <- function(path) {
  if (!file.exists(path)) {
    message(sprintf("? File '%s' does not exist.", path))
  }
  
  tryCatch({
    config <- yaml::read_yaml(path)
    message(">>YAML file exists and is valid<<")
    #return(config)
  }, error = function(e) {
    message(sprintf(">>>Failed to read YAML file: %s<<<", e$message))
  })
}

validate_config <- function(cfg) {
  required_fields <- list(
    site = "character",
    data_dir = "character",
    output_dir = "character",
    n.samples = "numeric",
    n.threads = "numeric",
    
    max.effective.range = "numeric",
    min.effective.range = "numeric",
    
    spatial.variance.scale = "numeric",
    
    nugget.variance.scale = "numeric",
    
    starting.decay.rate = "numeric",
    starting.spatial.variance = "numeric",
    starting.nugget.variance = "numeric",
    
    decay.rate.tuning = "numeric",
    spatial.variance.tuning = "numeric",
    nugget.variance.tuning = "numeric",
    
    discard_offset = "numeric",
    chain_sample = "numeric"
  )
  
  for (key in names(required_fields)) {
    if (!key %in% names(cfg)) {
      message(sprintf(">>>Missing required field: '%s'<<<", key))
    }
    expected_type <- required_fields[[key]]
    actual_value <- cfg[[key]]
    if (expected_type == "numeric" && !is.numeric(actual_value)) {
      message(sprintf(">>>Field '%s' should be numeric but is %s<<<", key, class(actual_value)))
    }
    if (expected_type == "character" && !is.character(actual_value)) {
      message(sprintf(">>>Field '%s' should be character but is %s<<<", key, class(actual_value)))
    }
  }
  
  if (cfg$discard_offset >= cfg$n.samples) {
    message(">>>'discard_offset' must be less than 'n.samples'<<<")
  }
  
  message(">>Config is valid<<")
}


check_dir_exist <- function(path) {
  # Check if directory exists
  if (dir.exists(path)) {
    message("Directory exists: ", path)
  } else {
    stop("Directory does not exist: ", path, 
         "\nCheck directory path and file name.")
  }
}

check_shapefile_exist <- function(shp_path) {
  # Check if shapefile exists
  if (file.exists(shp_path)) {
    message("Shapefile exists: ", shp_path)
  } else {
    stop("Shapefile does not exist: ", shp_path,
         "\nCheck directory path and file name.")
  }
}

check_shapefile_for_features <- function(shp_path) {
  shp <- vect(shp_path)
  # Check the number of features
  num_features <- nrow(shp)
  
  if (num_features > 0) {
    message(sprintf("Shapefile has %d feature(s): %s", num_features, shp_path))
  } else {
    stop("Shapefile has NO features: ", shp_path)
  }
}

check_shapefile_for_field <- function(shp_path, field_name) {
  # Read the shapefile using terra
  shp <- vect(shp_path)
  
  # Get field names
  field_names <- names(shp)
  
  # Check if the field exists
  if (field_name %in% field_names) {
    message(sprintf("Field '%s' exists in shapefile: %s", field_name, shp_path))
  } else {
    stop(sprintf("Field '%s' does NOT exist in shapefile: %s", field_name, shp_path))
  }
}

check_raster_exist <- function(ras_path) {
  # Check if shapefile exists
  if (file.exists(ras_path)) {
    message("Rasterfile exists: ", ras_path)
  } else {
    stop("Raster does not exist: ", ras_path,
         "\nCheck file name.")
  }
}

check_raster_for_band <- function(raster_path) {
  # Try to read the raster
  rast_obj <- rast(raster_path)
  
  # Check the number of bands (layers)
  num_bands <- nlyr(rast_obj)
  
  if (num_bands > 0) {
    message(sprintf("Raster has band(s) %d.", num_bands))
  } else {
    stop("Raster has NO bands.")
  }
}


load_assets <- function(site, base_path = "/vol/v1/FCF/spatial-model-walkthrough/assets/test-bed-models/data/") {
  bnd_path <- file.path(base_path, site, "bnd/bnd.shp")
  dat_path <- file.path(base_path, site, "plots/plots.shp")
  carbon_map_path <- file.path(base_path, site, "carbon-map.tif")

  bnd <- vect(bnd_path)
  dat <- vect(dat_path)
  carbon.map <- rast(carbon_map_path)
  carbon.map <- mask(carbon.map, bnd)
  dat$carbon.map <- extract(carbon.map, dat)[,2]

  return(list(bnd = bnd, pts = dat, carbon.map = carbon.map))
}



make_params <- function(config_path = NULL) {
  # Default values
  defaults <- list(
    n.samples = 25000,
    n.threads = 50,
    #phi.Unif.a.n = 3,
    max.effective.range = 100,
    #phi.Unif.b.n = 3,
    min.effective.range = 0.001,
    #sigma.sq.a = 2,
    spatial.variance.scale = 750,
    #tau.sq.a = 2,
    nugget.variance.scale = 750,
    #phi.s.n = 3,
    starting.decay.rate = 1.5,
    starting.spatial.variance = 750,
    starting.nugget.variance = 750,
    decay.rate.tuning = 0.06,
    spatial.variance.tuning = 0.06,
    nugget.variance.tuning = 0.06,
    discard_offset=5001,
    chain_sample=8
  )

  config_values <- yaml::read_yaml(config_path)
  # Filter config to only known keys
  valid_config <- config_values[names(config_values) %in% names(defaults)]
  # Merge only known values
  param <- modifyList(defaults, valid_config)
  str(param)
  return(param)
}

prepare_model_data <- function(obs) {
  y <- obs$Total.Carb
  x <- obs$carbon.map
  coords <- crds(obs) / 1000  # convert to km
  return(list(y = y, x = x, coords = coords))
}

#old
ffit_lm_variogram <- function(y, x, coords, max.dist = 5) {
  mod <- lm(y ~ x)
  vario <- variog(data = resid(mod), coords = coords, max.dist = max.dist)
  png("plot.png", width = 800, height = 600)
  plot(vario)
  dev.off()
  return(list(model = mod, variogram = vario))
}


fit_lm_variogram <- function(y, x, coords, max.dist = 5) {
  
  mod <- lm(y ~ x)
  vario <- variog(data = resid(mod), coords = coords, max.dist = max.dist)
  
  # Basic estimates
  nugget_estimate <- vario$v[1]
  partial_sill_estimate <- max(vario$v) - nugget_estimate
  range_estimate <- max(vario$u) * 0.5  # Rough guess: half of maximum distance

  # Fit a theoretical model (e.g., exponential) using initial values
  fit <- variofit(vario, cov.model = "exponential", weights = "equal",
                  ini.cov.pars = c(partial_sill_estimate, range_estimate),
                  nugget = nugget_estimate)

  nugget_fit <- fit$nugget
  partial_sill_fit <- fit$cov.pars[1]
  total_sill_fit <- nugget_fit + partial_sill_fit
  
  # Plot
  png("plot.png", width = 800, height = 600)
  plot(vario, main = "Semivariogram with Nugget and Sill")
  lines(fit, col = "blue")  # overlay fitted model
  
  # Add horizontal lines
  abline(h = nugget_estimate, col = "red", lty = 2, lwd = 2)   # Estimated nugget line
#  abline(h = sill_estimate, col = "darkgreen", lty = 2, lwd = 2) # Estimated sill line
  
  # Add fitted sill if you want
  abline(h = total_sill_fit, col = "darkgreen", lty = 2, lwd = 2) # Fitted sill
  
  # Add a simple legend
  legend("bottomright", legend = c("Empirical Nugget", "Fitted Sill"),
         col = c("red", "darkgreen"), lty = c(2,2), lwd = 2, bg = "white")
  
  dev.off()
  
  return(list(
    model = mod,
    variogram = vario,
    nugget_estimate = nugget_estimate,
    #sill_estimate = sill_estimate,
    #fitted_nugget = nugget_fit,
    fitted_sill = total_sill_fit
  ))
}


fit_spatial_model <- function(y, x, coords, par) {
  p <- 2
  priors <- list("beta.Norm" = list(rep(0, p), diag(1000, p)),
                 "phi.Unif" = list(3/par$max.effective.range, 3/par$min.effective.range),
                 "sigma.sq.IG" = list(2, par$spatial.variance.scale),
                 "tau.sq.IG" = c(2, par$nugget.variance.scale))

  starting <- list("phi" = 3/par$starting.decay.rate, "sigma.sq" = par$starting.spatial.variance, "tau.sq" = par$starting.nugget.variance)
  tuning <- list("phi" = par$decay.rate.tuning, "sigma.sq" = par$spatial.variance.tuning, "tau.sq"=par$nugget.variance.tuning)
  m.1 <- spSVC(y ~ x, coords = coords, starting = starting, tuning = tuning,
               n.omp.threads = par$n.threads, priors = priors,
               cov.model = "exponential", n.samples = par$n.samples)
    
  png("plot.png", width = 800, height = 600)
  plot(m.1$p.theta.samples)
  dev.off()
  m.1 <- spRecover(m.1, start = par$discard_offset, thin = par$chain_sample, n.omp.threads = par$n.threads)
  return(m.1)
}

predict_spatial <- function(model, carbon.map, site, out_dir = "results", n.threads = 50) {
  dat.pred <- as.data.frame(carbon.map, xy = TRUE)
  x.pred <- cbind(1, dat.pred[,3])
  coords.pred <- dat.pred[,1:2] / 1000
  dim(coords.pred)
  str(coords.pred)
  dim(x.pred)
  str(x.pred)

  pred <- spPredict(model, pred.coords = coords.pred, pred.covars = x.pred, n.omp.threads = n.threads)

  mn.ppd <- rowMeans(pred$p.y.predictive.samples)
  sd.ppd <- apply(pred$p.y.predictive.samples, 1, sd)
  pred.df <- data.frame(x = coords.pred[,1]*1000, y = coords.pred[,2]*1000,
                        carbon_mn = mn.ppd, carbon_sd = sd.ppd)
  pred.rast <- rast(pred.df, type = "xyz", crs = crs(carbon.map))

  save(pred, file = file.path(out_dir, site, "m.1.pred.RData"))
  writeRaster(pred.rast, filename = file.path(out_dir, site, "pred.tif"))
  return(pred.rast)
}

predict_joint <- function(model, carbon.map, site, out_dir = "results", n.threads = 50) {
  carbon.map.agg <- aggregate(carbon.map, 2)
  dat.pred <- as.data.frame(carbon.map.agg, xy = TRUE)
  x.pred <- cbind(1, dat.pred[,3])
  coords.pred <- dat.pred[,1:2] / 1000

  pred <- spPredict(model, pred.coords = coords.pred, pred.covars = x.pred, joint = TRUE, n.omp.threads = n.threads)

  save(pred, file = file.path(out_dir, site, "m.1.pred.joint.RData"))
  pred.df <- as.data.frame(cbind(coords.pred * 1000, pred$p.y.predictive.samples))
  pred.rast <- rast(pred.df, type = "xyz", crs = crs(carbon.map))
  writeRaster(pred.rast, filename = file.path(out_dir, site, "pred-joint.tif"))
  return(pred.rast)
}

plot_predictions <- function(pred.rast, carbon.map) {
  pred.mn <- rast(as.data.frame(cbind(crds(pred.rast, na.rm = FALSE),
                                      rowMeans(values(pred.rast)))),
                  type = "xyz", crs = crs(carbon.map))
  plot(pred.mn)

  par(mfrow = c(1, 2))
  for(i in 1:nlyr(pred.rast)){
    plot(pred.mn, col = map.pal("grass", 50), type = "cont")
    plot(pred.rast, i, col = map.pal("grass", 50),
         breaks = seq(-140, 300, length.out = 51), type = "cont")
  }
  par(mfrow = c(1, 1))
}
