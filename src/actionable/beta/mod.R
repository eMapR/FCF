## spatial_model_functions.R

load_data <- function(site, base_path = "/vol/v1/FCF/spatial-model-walkthrough/assets/test-bed-models/data/") {
  bnd_path <- file.path(base_path, site, "bnd/bnd.shp")
  dat_path <- file.path(base_path, site, "plots/plots.shp")
  carbon_map_path <- file.path(base_path, site, "carbon-map.tif")

  bnd <- vect(bnd_path)
  dat <- vect(dat_path)
  carbon.map <- rast(carbon_map_path)
  carbon.map <- mask(carbon.map, bnd)
  dat$carbon.map <- extract(carbon.map, dat)[,2]

  return(list(bnd = bnd, dat = dat, carbon.map = carbon.map))
}

prepare_model_data <- function(dat) {
  y <- dat$Total.Carb
  x <- dat$carbon.map
  coords <- crds(dat) / 1000  # convert to km
  return(list(y = y, x = x, coords = coords))
}

fit_lm_variogram <- function(y, x, coords, max.dist = 5) {
  mod <- lm(y ~ x)
  vario <- variog(data = resid(mod), coords = coords, max.dist = max.dist)
  plot(vario)
  return(list(model = mod, variogram = vario))
}

fit_spatial_model <- function(y, x, coords, n.samples = 25000, n.threads = 50) {
  p <- 2
  priors <- list("beta.Norm" = list(rep(0, p), diag(1000, p)),
                 "phi.Unif" = list(3/100, 3/.001),
                 "sigma.sq.IG" = list(2, 750),
                 "tau.sq.IG" = c(2, 750))
  starting <- list("phi" = 3/1.5, "sigma.sq" = 750, "tau.sq" = 750)
  tuning <- list("phi" = 0.06, "sigma.sq" = 0.06, "tau.sq" = 0.06)

  m.1 <- spSVC(y ~ x, coords = coords, starting = starting, tuning = tuning,
               n.omp.threads = n.threads, priors = priors,
               cov.model = "exponential", n.samples = n.samples)

  plot(m.1$p.theta.samples)
  m.1 <- spRecover(m.1, start = 5001, thin = 8, n.omp.threads = n.threads)
  return(m.1)
}

predict_spatial <- function(model, carbon.map, site, out_dir = "results", n.threads = 50) {
  dat.pred <- as.data.frame(carbon.map, xy = TRUE)
  x.pred <- cbind(1, dat.pred[,3])
  coords.pred <- dat.pred[,1:2] / 1000

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
