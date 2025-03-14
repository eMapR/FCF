rm(list=ls())
###############
## libraries ##
library(sp)
library(spBayes)
library(MASS)

## load up synthetic data
load("/vol/v1/FCF/spatial-model-walkthrough/assets/synthetic-data.RData")

## load up fitted model
load("/vol/v1/FCF/spatial-model-walkthrough/assets/fitted-model.RData")

## predict using spPredict

## First we recover beta samples and w samples.
## We also burn in and thin in this step.
m.1 <- spRecover(m.1, start = 501, thin = 4)

## spPredict yells at us when we try to pass in observation locations as prediction locations.
## So we are going to do a little hack to trick Andy's function into working.

## We are going to move our observation locations stored in the model object a very tiny amount.
## We would not have to do this step if we didn't need to predict at observation locations.
m.1$coords[,1]  <-  m.1$coords[,1] + .000000000001

m.p <- spPredict(m.1, pred.coords = coords, pred.covars = cbind(1,x))

y.ppd <- m.p$p.y.predictive.samples^2 ## backtransform the samples

y.ppd.cred <- t(apply(y.ppd, 1, quantile, probs = c(.5,.025,.975)))
y.ppd.sd <- apply(y.ppd,1,sd)

## y.pred.sp <- data.frame('y.pred' = y.ppd.cred[,1], 'y.sd' = y.ppd.sd)
## coordinates(y.pred.sp) <- coords
## gridded(y.pred.sp) <- TRUE

## pdf("figures/y-pred-map.pdf", height = 6, width = 6)
## spplot(y.pred.sp['y.pred'])
## dev.off()

## pdf("figures/y-sd-map.pdf", height = 6, width = 6)
## spplot(y.pred.sp['y.sd'])
## dev.off()

## Running spPredict with joint = FALSE is great for mapping and getting grid cell level uncertainty estimates.
## However, when joint = FALSE, spPredict samples each grid cell independently rather than sampling all grid cells jointly.
## This means that posterior predictive samples from spPredict with joint = FALSE, cannot be used to get areal estimates (i.e.,
## no small area or large area estimation).

## running spPredict with joint=TRUE will take longer to run.
## It's not a huge difference here, but for larger datasets, it can be significant.
m.p.joint <- spPredict(m.1, pred.coords = coords, pred.covars = cbind(1,x), joint = TRUE)

y.joint.ppd <- m.p.joint$p.y.predictive.samples^2 ## backtransform the samples

y.joint.ppd.cred <- t(apply(y.joint.ppd, 1, quantile, probs = c(.5,.025,.975)))
y.joint.ppd.sd <- apply(y.joint.ppd,1,sd)

## y.joint.pred.sp <- data.frame('y.pred' = y.joint.ppd.cred[,1], 'y.sd' = y.joint.ppd.sd)
## coordinates(y.joint.pred.sp) <- coords
## gridded(y.joint.pred.sp) <- TRUE

## pdf("figures/y-joint-pred-map.pdf", height = 6, width = 6)
## spplot(y.joint.pred.sp['y.pred'])
## dev.off()

## pdf("figures/y-joint-sd-map.pdf", height = 6, width = 6)
## spplot(y.joint.pred.sp['y.sd'])
## dev.off()

## Now that we have samples from the joint posterior predictive distribution, we can make hay in terms of areal estimation.

## To get the posterior for the mean of y for the entire area we take the column means of y.joint.ppd

y.mn.ppd <- colMeans(y.joint.ppd)

## pdf("figures/y-mn-ppd.pdf", width = 6, height = 6)
## hist(y.mn.ppd)
## dev.off()

## and calculate the median and 95% credible interval.
quantile(y.mn.ppd, probs = c(.5,.025,.975))
sd(y.mn.ppd)

## see what happens we try to use spPredict output though,
y.mn.ppd2 <- colMeans(y.ppd)

pdf("/vol/v1/FCF/spatial-model-walkthrough/assest/y-mn-ppd2.pdf", width = 6, height = 6)
hist(y.mn.ppd2)
dev.off()

quantile(y.mn.ppd2, probs = c(.5,.025,.975))
sd(y.mn.ppd2)
## the uncertainty comes out way less and this is wrong.

## we can get using the joint ppd to get estimates for the mean of y for any area within the domain too
## plot(coords)
## points(coords[1:800,], pch = 19)

## so if we want an estimate for the southern half of the domain, we just use the y ppd that falls in that area.
y.bottom.mn.ppd <- colMeans(y.joint.ppd[1:800,])

## and the top half
y.top.mn.ppd <- colMeans(y.joint.ppd[801:1600,])

## pdf("figures/y-bottom-mn-ppd.pdf", height = 6, width = 6)
## hist(y.bottom.mn.ppd)
## dev.off()

## pdf("figures/y-top-mn-ppd.pdf", height = 6, width = 6)
## hist(y.top.mn.ppd)
## dev.off()

## looks like the mean of y for the top half is larger than the mean of y for the bottom half
## We can conduct a statistical test for this even.
y.mn.diff.ppd <- y.top.mn.ppd-y.bottom.mn.ppd

## pdf("figures/y-mn-diff-ppd.pdf", height = 6, width = 6)
## hist(y.mn.diff.ppd)
## dev.off()

quantile(y.mn.diff.ppd, probs = c(.5,.025,.975))
## since the 95% credible interval does not include zero, we can be 95% sure that the
## mean of y from the top half is larger than the mean of y for the bottom half

## Once we have that joint posterior, we can have a field day. 
