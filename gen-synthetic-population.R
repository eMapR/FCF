rm(list=ls())
###############
## libraries ##
library(sp)
library(spBayes)
library(MASS)

set.seed(2)

coords <- as.matrix(expand.grid(seq(0,1,length.out = 40),seq(0,1,length.out = 40)))
N <- nrow(coords)

dmat <- iDist(coords)

## generate an x covariate.
x.sigma.sq <- 2
x.phi <- 3/.15
x.mu <- rep(5,N)

x.cov <- x.sigma.sq*exp(-x.phi*dmat)

x <- mvrnorm(1,x.mu,x.cov)

## uncomment code below to see a map of x
## x.sp <- data.frame("x" = x)
## coordinates(x.sp) <- coords
## gridded(x.sp) <- TRUE

## pdf("figures/synthetic-x.pdf", width = 6, height = 6)
## spplot(x.sp)
## dev.off()

## Generate y

w.sigma.sq <- 7
w.phi <- 3/.25

w.cov <- w.sigma.sq*exp(-w.phi*dmat)

w <- mvrnorm(1,rep(0,N),w.cov)

beta.0 <- 1
beta.1 <- 3
tau.sq <- 2

y.mu <- beta.0 + x*beta.1 + w

y <- rnorm(N,y.mu, sqrt(tau.sq))^2

summary(lm(sqrt(y) ~ x))

## uncomment code below to see a map of y
## y.sp <- data.frame("y" = y)
## coordinates(y.sp) <- coords
## gridded(y.sp) <- TRUE

## pdf("figures/synthetic-y.pdf", width = 6, height = 6)
## spplot(y.sp)
## dev.off()

save(x,y,coords, file = "synthetic-data.RData")
