rm(list=ls())
###############
## libraries ##
library(sp)
library(spBayes)
library(geoR)

load("synthetic-data.RData")

## first we are going select 100 grid cells to be our 'plots'
## where we have measured y.

set.seed(3)

n <- 250 ## number of plots we want to imagine we collected
sub <- sample(1:nrow(coords), n)
y <- y[sub]
x <- x[sub]
coords <- coords[sub,]

n.samples <- 5000

p <- 2

## fit a semi-variogram to the residuals of the non-spatial model
## to inform prior selection and starting values for MCMC sampler

m.0 <- lm(sqrt(y) ~ x)
vario <- variog(data = resid(m.0), coords = coords, max.dist = .5)
vario.mod <- variofit(vario, cov.model = "exponential")

## pdf("figures/variogram.pdf", width = 6, height = 6)
## plot(vario)
## lines(vario.mod)
## dev.off()

priors <- list("beta.Norm"=list(rep(0,p), diag(1000,p)),
               "phi.Unif"=list(3/1, 3/.001),
               "sigma.sq.IG"=list(2, 6),
               "tau.sq.IG"=c(2, 2))

starting <- list("phi"=3/.25, "sigma.sq"=6, "tau.sq"=2)

tuning <- list("phi"=0.04, "sigma.sq"=0.04, "tau.sq"=0.04)

m.1 <- spSVC(sqrt(y) ~ x,coords=coords,starting=starting,tuning=tuning,priors=priors,cov.model="exponential",n.samples=n.samples)

## pdf("figures/chains.pdf", width = 9, height = 6)
## plot(m.1$p.theta.samples)
## dev.off()

save(m.1, file = "fitted-model.RData")
