## ---- include = FALSE---------------------------------------------------------
knitr::opts_chunk$set(comment = NA,
                      eval = greta:::check_tf_version("message"),
                      cache = TRUE)

## ----setup--------------------------------------------------------------------
library(greta.dynamics)
greta_sitrep()

## -----------------------------------------------------------------------------
# replicate the Lotka-Volterra example from deSolve
library(deSolve)
LVmod <- function(Time, State, Pars) {
  with(as.list(c(State, Pars)), {
    Ingestion <- rIng * Prey * Predator
    GrowthPrey <- rGrow * Prey * (1 - Prey / K)
    MortPredator <- rMort * Predator
    
    dPrey <- GrowthPrey - Ingestion
    dPredator <- Ingestion * assEff - MortPredator
    
    return(list(c(dPrey, dPredator)))
  })
}

pars <- c(
  rIng = 0.2, # /day, rate of ingestion
  rGrow = 1.0, # /day, growth rate of prey
  rMort = 0.2, # /day, mortality rate of predator
  assEff = 0.5, # -, assimilation efficiency
  K = 10
) # mmol/m3, carrying capacity

yini <- c(Prey = 1, Predator = 2)
times <- seq(0, 30, by = 1)
out <- ode(yini, times, LVmod, pars)

# simulate observations
jitter <- rnorm(2 * length(times), 0, 0.1)
y_obs <- out[, -1] + matrix(jitter, ncol = 2)

## -----------------------------------------------------------------------------
# fit a greta model to infer the parameters from this simulated data

# greta version of the function
lotka_volterra <- function(y, t, rIng, rGrow, rMort, assEff, K) {
  Prey <- y[1, 1]
  Predator <- y[1, 2]
  
  Ingestion <- rIng * Prey * Predator
  GrowthPrey <- rGrow * Prey * (1 - Prey / K)
  MortPredator <- rMort * Predator
  
  dPrey <- GrowthPrey - Ingestion
  dPredator <- Ingestion * assEff - MortPredator
  
  cbind(dPrey, dPredator)
}

# priors for the parameters
rIng <- uniform(0, 2) # /day, rate of ingestion
rGrow <- uniform(0, 3) # /day, growth rate of prey
rMort <- uniform(0, 1) # /day, mortality rate of predator
assEff <- uniform(0, 1) # -, assimilation efficiency
K <- uniform(0, 30) # mmol/m3, carrying capacity

# initial values and observation error
y0 <- uniform(0, 5, dim = c(1, 2))
obs_sd <- uniform(0, 1)

# solution to the ODE
y <- ode_solve(lotka_volterra, y0, times, rIng, rGrow, rMort, assEff, K)

# sampling statement/observation model
distribution(y_obs) <- normal(y, obs_sd)

## -----------------------------------------------------------------------------
# we can use greta to solve directly, for a fixed set of parameters (the true
# ones in this case)
values <- c(
  list(y0 = t(1:2)),
  as.list(pars)
)
vals <- calculate(y, values = values)[[1]]
plot(vals[, 1] ~ times, type = "l", ylim = range(vals))
lines(vals[, 2] ~ times, lty = 2)
points(y_obs[, 1] ~ times)
points(y_obs[, 2] ~ times, pch = 2)

## -----------------------------------------------------------------------------
# or we can do inference on the parameters:

# build the model (takes a few seconds to define the tensorflow graph)
m <- model(rIng, rGrow, rMort, assEff, K, obs_sd)

# compute MAP estimate
o <- opt(m)
o

