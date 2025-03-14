# Clear the environment by removing all existing objects
rm(list=ls())

###############
## Load Libraries ##
library(sp)       # Spatial data handling
library(spBayes)  # Bayesian spatial analysis
library(MASS)     # Functions for multivariate normal distributions

#####################################################################
# Set the random seed for reproducibility
set.seed(2)  # Ensures that any random number generation is consistent across runs

#####################################################################
# Generate a 40x40 grid of coordinates within [0,1] x [0,1]
coords <- as.matrix(expand.grid(seq(0,1,length.out = 40), seq(0,1,length.out = 40))) 
# `coords` is a 1600 × 2 matrix where each row represents a coordinate pair

#####################################################################
# Get the number of rows in `coords`, which represents the total grid points
N <- nrow(coords)  # N = 1600

#####################################################################
# Compute the Euclidean distance matrix for the given coordinates
# This stores the pairwise distances between all locations

dmat <- iDist(coords) 

#####################################################################
## Generate an x covariate ##

# Define variance for `x`
x.sigma.sq <- 2  # Controls the spatial variance of `x`

# Define the spatial decay parameter for `x`
x.phi <- 3 / 0.15  # Controls how quickly correlation decreases with distance

# Define the mean vector for `x`, setting all values to 5
x.mu <- rep(5, N)  # Expected value of `x` is 5 at all locations

# Construct the spatial covariance matrix for `x`
# This follows an exponential decay function based on distance
decay_matrix_x <- exp(-x.phi * dmat)
x.cov <- x.sigma.sq * decay_matrix_x 

# Generate a spatially correlated covariate `x` from a multivariate normal distribution
x <- mvrnorm(1, x.mu, x.cov) 

#####################################################################
## Uncomment the following code to visualize the spatial field of `x` ##
# x.sp <- data.frame("x" = x)
# coordinates(x.sp) <- coords
# gridded(x.sp) <- TRUE
# pdf("figures/synthetic-x.pdf", width = 6, height = 6)
# spplot(x.sp)
# dev.off()

#####################################################################
## Generate `y`, another spatially correlated variable ##

# Define variance for `w`
w.sigma.sq <- 7  # Variance parameter for `w`

# Define spatial decay for `w`
w.phi <- 3 / 0.25  # Controls spatial correlation decay for `w`

# Construct spatial covariance matrix for `w`
decay_matrix_w <- exp(-w.phi * dmat)
w.cov <- w.sigma.sq * decay_matrix_w 

# Generate spatially correlated random variable `w`
w <- mvrnorm(1, rep(0, N), w.cov)

#####################################################################
## Generate `y` based on a spatial regression model ##

beta.0 <- 1  # Intercept
beta.1 <- 3  # Coefficient for `x`
tau.sq <- 2  # Variance of independent error term

# Compute the expected mean of `y`
y.mu <- beta.0 + x * beta.1 + w

# Generate response variable `y`, adding independent Gaussian noise
y <- rnorm(N, y.mu, sqrt(tau.sq))^2  # Squaring ensures non-negative values

# Fit a linear model for `y` against `x` and display the summary
summary(lm(sqrt(y) ~ x))

#####################################################################
## Uncomment the following code to visualize the spatial field of `y` ##
# y.sp <- data.frame("y" = y)
# coordinates(y.sp) <- coords
# gridded(y.sp) <- TRUE
# pdf("figures/synthetic-y.pdf", width = 6, height = 6)
# spplot(y.sp)
# dev.off()

#####################################################################
## Save generated synthetic data to an .RData file ##
save(x, y, coords, file = "/vol/v1/FCF/spatial-model-walkthrough/assets/synthetic-data.RData")

