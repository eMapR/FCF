## spatial_model_functions.R

check_yaml_exists_and_valid <- function(path) {
  if (!file.exists(path)) {
    stop(sprintf("? File '%s' does not exist.", path))
  }
  
  tryCatch({
    config <- yaml::read_yaml(path)
    message("? YAML file exists and is valid.")
    #return(config)
  }, error = function(e) {
    stop(sprintf("? Failed to read YAML file: %s", e$message))
  })
}

validate_config <- function(cfg) {
  required_fields <- list(
    site = "character",
    data_dir = "character",
    output_dir = "character",
    n.samples = "numeric",
    n.threads = "numeric",
    max.dist = "numeric",
    
    phi.Unif.a.n = "numeric",
    phi.Unif.a.d = "numeric",
    phi.Unif.b.n = "numeric",
    phi.Unif.b.d = "numeric",
    
    sigma.sq.a = "numeric",
    sigma.sq.b = "numeric",
    
    tau.sq.a = "numeric",
    tau.sq.b = "numeric",
    
    phi.s.n = "numeric",
    phi.s.d = "numeric",
    sigma.sq.s = "numeric",
    tau.sq.s = "numeric",
    
    phi.t = "numeric",
    sigma.sq.t = "numeric",
    tau.sq.t = "numeric",
    
    discard_offset = "numeric",
    chain_sample = "numeric"
  )
  
  for (key in names(required_fields)) {
    if (!key %in% names(cfg)) {
      stop(sprintf("Missing required field: '%s'", key))
    }
    expected_type <- required_fields[[key]]
    actual_value <- cfg[[key]]
    if (expected_type == "numeric" && !is.numeric(actual_value)) {
      stop(sprintf("Field '%s' should be numeric but is %s", key, class(actual_value)))
    }
    if (expected_type == "character" && !is.character(actual_value)) {
      stop(sprintf("Field '%s' should be character but is %s", key, class(actual_value)))
    }
  }
  
  if (cfg$discard_offset >= cfg$n.samples) {
    stop("'discard_offset' must be less than 'n.samples'")
  }
  
  message("? Config is valid")
}


check_shapefile_for_features <- function(shp_path) {
  # Read the shapefile
  shp <- vect(shp_path)
  
  # Check the number of features
  num_features <- nrow(shp)
  
  if (num_features > 0) {
    message(sprintf("Shapefile has %d feature(s).", num_features))
    return(TRUE)
  } else {
    message("Shapefile has NO features.")
    return(FALSE)
  }
}

check_shapefile_for_feild <- function(shp_path, field_name) {
  # Read the shapefile using terra
  shp <- vect(shp_path)
  
  # Get field names
  field_names <- names(shp)
  
  # Check if the field exists
  if (field_name %in% field_names) {
    message(sprintf("Field '%s' exists in the shapefile.", field_name))
    return(TRUE)
  } else {
    message(sprintf("Field '%s' does NOT exist in the shapefile.", field_name))
    return(FALSE)
  }
}


check_raster_for_band <- function(raster_path) {
  # Try to read the raster
  rast_obj <- rast(raster_path)
  
  # Check the number of bands (layers)
  num_bands <- nlyr(rast_obj)
  
  if (num_bands > 0) {
    message(sprintf("Raster has %d band(s).", num_bands))
    return(TRUE)
  } else {
    message("Raster has NO bands.")
    return(FALSE)
  }
}


load_assets <- function(site, base_path = "/vol/v1/FCF/spatial-model-walkthrough/assets/test-bed-models/data/") {
  bnd_path <- file.path(base_path, site, "bnd/bnd.shp")
  dat_path <- file.path(base_path, site, "plots/plots.shp")
  carbon_map_path <- file.path(base_path, site, "carbon-map.tif")


  str(dat_path)
  check_shapefile_for_features(bnd_path)
  check_shapefile_for_features(dat_path)
  check_shapefile_for_feild(dat_path,"Total.Carb")
  check_raster_for_band(carbon_map_path)

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
    phi.Unif.a.n = 3,
    phi.Unif.a.d = 100,
    phi.Unif.b.n = 3,
    phi.Unif.b.d = 0.001,
    sigma.sq.a = 2,
    sigma.sq.b = 750,
    tau.sq.a = 2,
    tau.sq.b = 750,
    phi.s.n = 3,
    phi.s.d = 1.5,
    sigma.sq.s = 750,
    tau.sq.s = 750,
    phi.t = 0.06,
    sigma.sq.t = 0.06,
    tau.sq.t = 0.06,
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

fit_lm_variogram <- function(y, x, coords, max.dist = 5) {
  mod <- lm(y ~ x)
  vario <- variog(data = resid(mod), coords = coords, max.dist = max.dist)
  png("plot.png", width = 800, height = 600)
  plot(vario)
  dev.off()
  return(list(model = mod, variogram = vario))
}

fit_spatial_model <- function(y, x, coords, par) {
  p <- 2
  priors <- list("beta.Norm" = list(rep(0, p), diag(1000, p)),
                 "phi.Unif" = list(par$phi.Unif.a.n/par$phi.Unif.a.d, par$phi.Unif.b.n/par$phi.Unif.b.d),
                 "sigma.sq.IG" = list(par$sigma.sq.a, par$sigma.sq.b),
                 "tau.sq.IG" = c(par$tau.sq.a, par$tau.sq.b))

  starting <- list("phi" = par$phi.s.n/par$phi.s.d, "sigma.sq" = par$sigma.sq.s, "tau.sq" = par$tau.sq.s)
  tuning <- list("phi" = par$phi.t, "sigma.sq" = par$sigma.sq.t, "tau.sq"=par$tau.sq.t)
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
