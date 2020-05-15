setwd("~/HVLF")
rm(list = ls())
source("aux-functions.r")
source("simulations-lorenz/Lorenz-aux.r")
source("scores.r")
resultsDir = "simulations-lorenz"
library(VEnKF)
library(Matrix)
library(GPvecchia)
library(foreach)
library(iterators)
library(parallel)
library(doParallel)
registerDoParallel(cores=5)



######### set parameters #########
set.seed(1988)
n = 960
m = 50
frac.obs = 0.1
Tmax = 20



## evolution function ##
Force = 10
K = 32
dt = 0.005
M = 5
b = 0.2
evolFun = function(X) b*Lorenz04M2Sim(as.numeric(X)/b, Force, K, dt, M, iter = 1, burn = 0, order = 4)
max.iter = getDoParWorkers()



## covariance function
sig2 = 0.1; range = .15; smooth = 0.5; 
covparms = c(sig2,range,smooth)
covfun = function(locs) GPvecchia::MaternFun(fields::rdist(locs),covparms)


## likelihood settings
me.var = 0.1;
args = commandArgs(trailingOnly = TRUE)
if (length(args) == 1) {
  if (!(args[1] %in% c("gauss", "poisson", "logistic", "gamma"))) {
    stop("One of the models has to be passed as argument")
  } else {
    data.model = args[1]
  }
} else {
  data.model = "gauss"
}
lik.params = list(data.model = data.model, sigma = sqrt(me.var), alpha=2)



## generate grid of pred.locs
grid.oneside = seq(0,1,length = round(n))
locs = matrix(grid.oneside, ncol = 1)


## set initial state
cat("Loading the moments of the long-run Lorenz\n")
moments = getLRMuCovariance(n, Force, dt, K)
Sig0 = (b**2)*moments[["Sigma"]] + diag(1e-10, n)
mu = b*moments[["mu"]]
x0 = b*getX0(n, Force, K, dt)
Sigt = sig2*Sig0
#Sigt = sig2*covfun(locs)


## define Vecchia approximation
cat("Calculating the approximations\n")
mra = GPvecchia::vecchia_specify(locs, m, conditioning = 'mra', ordering = 'maxmin')
exact = GPvecchia::vecchia_specify(locs, nrow(locs) - 1, ordering = 'maxmin', conditioning = 'firstm')
low.rank = GPvecchia::vecchia_specify(locs, ncol(mra$U.prep$revNNarray) - 1, ordering = 'maxmin', conditioning = 'firstm')
approximations = list(mra = mra, low.rank = low.rank, exact = exact)


scores = foreach( iter=1:max.iter) %dopar% {

    cat("Simulating data\n")
    XY = simulate.xy(x0, evolFun, Sigt, frac.obs, lik.params, Tmax)
   
    cat(paste("iteration: ", iter, ", exact", "\n", sep = ""))
    start = proc.time()
    predsE = filter('exact', XY)
    d = as.numeric(proc.time() - start)
    cat(paste("Exact filtering took ", d[3], "s\n", sep = ""))

    cat(paste("iteration: ", iter, ", MRA", "\n", sep = ""))
    start = proc.time()
    predsMRA = filter('mra', XY)
    d = as.numeric(proc.time() - start)
    cat(paste("MRA filtering took ", d[3], "s\n", sep = ""))

    cat(paste("iteration: ", iter, ", LR", "\n", sep = ""))
    start = proc.time()
    predsLR  = filter('low.rank', XY)
    d = as.numeric(proc.time() - start)
    cat(paste("Low-rank filtering took ", d[3], "s\n", sep = ""))

    RRMSPE = calculateRRMSPE(predsMRA, predsLR, predsE, XY$x)
    LogSc = calculateLSs(predsMRA, predsLR, predsE, XY$x)
    write.csv(RRMSPE, file = paste(resultsDir, "/", data.model, "/RRMSPE.", iter, sep = ""))
    write.csv(LogSc, file = paste(resultsDir, "/", data.model, "/LogSc.", iter, sep = ""))

    print(RRMSPE)
    print(LogSc)
    if(iter==1){
      plotResults(XY, predsE, predsMRA, predsLR, resultsDir)
    }
    list(RRMSPE, LogSc)
}


avgRRMSPE = Reduce("+", lapply(scores, `[[`, 1))/length(scores)
avgdLS = Reduce("+", lapply(scores, `[[`, 2))/length(scores)
cat("===== avg. RRMSPE: ====\n")
print(avgRRMSPE)
cat("==== avg. dLS ====\n")
print(avgdLS)

