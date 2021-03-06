# simsDesign1-sLBdown25.R
# Copyright 2018 Nicholas J. Seewald
#
# This file is part of rmSMARTsize.
# 
# rmSMARTsize is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# rmSMARTsize is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with rmSMARTsize.  If not, see <https://www.gnu.org/licenses/>.

### --------------------------------------------- ###
###            Simulations for Design 1           ###
### Violation of Conditional Variation Assumption ###
###   Response Variance 75% of Lower Threshold    ###
### --------------------------------------------- ###

library(here)

notify <- TRUE
seed <- 1001
source(here("init.R"), echo = FALSE)

##### Simulation Setup #####

times <- c(0, 1, 2)
spltime <- 1

niter <- 3000
maxiter.solver <- 1000
tol <- 1e-8

sigma <- 6

# Generate a grid of simulation scenarios
simGrid <- expand.grid(
  list(
    sharp = c(FALSE, TRUE),
    r0 = c(.4, .6),
    r1 = c(.4, .6),
    corr = c(0, .3, .6, .8),
    oldModel = c(FALSE, TRUE),
    respFunction = list(
      "indep" = "response.indep",
      "beta" = "response.beta",
      "oneT" = "response.oneT",
      "twoT" = "response.twoT"
    ),
    respDirection = c("high", "low")
  ),
  stringsAsFactors = F
)

simGrid$corr.r1 <- simGrid$corr.r0 <- simGrid$corr

# Ignore duplicate simulations from expand.grid
simGrid <- subset(simGrid, !(respFunction == "response.oneT" & r0 != r1))
simGrid <- subset(simGrid, !(corr == 0 & sharp == T))
simGrid <- subset(simGrid, !(oldModel & respFunction != "response.indep") |
                    respFunction == "response.indep")
rownames(simGrid) <- 1:nrow(simGrid)

# Send initial notification that simulations are about to start
if(notify) {
  startString <- paste("All systems go so far!\nRunning on", nWorkers, "cores.")
  slackr_bot(startString)
  rm(startString)
}

##### Effect size: 0.3 #####

gammas <- c(35, -4, 2.2, -1.6, -1.3, 0.4, -0.4, 0.4, 0.4)
lambdas <- c(0.3, 0.4)

simGrid.delta3 <- computeVarGrid(simGrid, times, spltime, gammas,
                                 sigma, corstr = "exch", design = 1,
                                 varCombine = function(x)
                                   x[1] - 0.25 * abs(x[1] - x[2]))

# Construct string to name simulation results
simGrid.delta3$simName <- sapply(1:nrow(simGrid.delta3), function(i) {
  x <- simGrid.delta3[i, ]
  rdir <- as.character(x$respDirection)
  paste0("d1_delta3.",
         ifelse(x$r0 == x$r1, paste0("r", x$r0* 10),
                paste0("r0_", x$r0*10, ".r1_", x$r1*10)),
         ".exch", x$corr * 10, ".",
         x$respFunction, 
         paste0(toupper(substr(rdir, 1, 1)), substr(rdir, 2, nchar(rdir))),
         ifelse(x$oldModel, ".old", ""),
         ifelse(x$sharp, ".sharp", ""))
})

# Check validity of scenarios before trying to simulate them
# and remove any "invalid" ones
invalidSims.delta3 <- checkVarGridValidity(simGrid.delta3)
simGrid.delta3 <- simGrid.delta3[!is.element(simGrid.delta3$simName, 
                                             invalidSims.delta3$simName), ]
rownames(simGrid.delta3) <- 1:nrow(simGrid.delta3)

save(file = here("Results", "simsDesign1-delta3-sLBdown25.RData"),
     list = c("sigma", "simGrid.delta3", "invalidSims.delta3",
              "gammas", "lambdas", "seed", "times", "spltime"))

for (scenario in 1:nrow(simGrid.delta3)) {
  # Extract simulation conditions from simGrid.delta3
  r0 <- simGrid.delta3$r0[scenario]
  r1 <- simGrid.delta3$r1[scenario]
  sharp <- simGrid.delta3$sharp[scenario]
  corr <- c(simGrid.delta3$corr[scenario], simGrid.delta3$corr.r1[scenario],
            simGrid.delta3$corr.r0[scenario])
  respFunc.name <- simGrid.delta3$respFunction[scenario]
  respDir <- simGrid.delta3$respDirection[scenario]
  old <- simGrid.delta3$oldModel[scenario]
  
  # Extract variances from simGrid
  sigma.r0 <- simGrid.delta3$sigma.r00[scenario]
  sigma.r1 <- simGrid.delta3$sigma.r11[scenario]
  vars <- simGrid.delta3[scenario, 
                         c(grep("^sigma.nr[0-9].", names(simGrid.delta3)),
                           grep("^v2\\.", names(simGrid.delta3)))]
  
  # Recompute r0 if necessary
  if(respFunc.name == "response.oneT"){
    upsilon <- qnorm(r1, as.numeric(sum(gammas[1:3])), sigma,
                     lower.tail = FALSE)
    r0 <- pnorm(upsilon, sum(gammas[1:2]) - gammas[3], sigma,
                lower.tail = FALSE)
  }
  
  postID <- paste0(
    "Scenario ", scenario, " of ", nrow(simGrid.delta3), "\n",
    "sLBdown25 simulation setup\n",
    "Effect size: 0.3\n",
    "Response function:",
    respFunc.name,
    " ", respDir, "\n",
    ifelse(sharp, "sharp n",
           "conservative n")
  )
  
  if ((simGrid.delta3$sigma.r00[scenario] >
       simGrid.delta3$sigma.r0.UB[scenario]) |
      (simGrid.delta3$sigma.r11[scenario] >
       simGrid.delta3$sigma.r1.UB[scenario])) {
    designText <- paste0("Design 1\n",
                         postID,
                         "delta = 0.3\n",
                         "true corstr = exchangeable(", corr[1], ")\n",
                         "r0 = ", round(r0, 3), ", r1 = ", round(r1, 3))
    if (notify) slackr_bot(designText)
    warnText <- paste("The maximum allowable sigma.rXX (11 or 00) is less than",
                      "the chosen value of sigma.r.",
                      "Skipping for now...")
    assign(simGrid.delta3$simName[scenario], warnText)
    if (notify) slackr_bot(warnText)
    next
  }
  
  # Set the seed for every unique simulation
  set.seed(seed)
  
  # Simulate
  if (notify) slackr_bot(simGrid.delta3$simName[scenario])
  assign(simGrid.delta3$simName[scenario],
         try(simulateSMART(
           gammas = gammas,
           lambdas = lambdas,
           r1 = r1,
           r0 = r0,
           times = times,
           spltime = spltime,
           alpha = .05,
           power = .8,
           delta = 0.3,
           design = 1,
           conservative = !sharp,
           sigma = sigma,
           sigma.r1 = sigma.r1,
           sigma.r0 = sigma.r0,
           variances = vars,
           pool.time = TRUE,
           L = c(0, 0, 2, 0, 2, 2, 2, 0, 0),
           corstr = "exch",
           rho = corr[1],
           rho.r1 = corr[2],
           rho.r0 = corr[3],
           respFunction = get(unlist(respFunc.name)),
           respDirection = respDir,
           niter = niter,
           notify = notify,
           old = old,
           postIdentifier = postID
         )),
         envir = .GlobalEnv)
  
  # Save the result
  save(file = here("Results", "simsDesign1-delta3-sLBdown25.RData"),
       list = c(grep("d1_delta3", ls(), value = T), "sigma",
                "gammas", "lambdas", "seed", "times", "spltime",
                "simGrid.delta3", "invalidSims.delta3"),
       precheck = TRUE)
}

if (notify) {
  x <- paste("All simulations are complete for Design 1,", 
             "effect size 0.3\n for sLBdown25 scenarios.")
  slackr_bot(x)
  rm(x)
}

rm(list = grep("d1_delta3", ls(), value = T))


##### Effect size: 0.5 #####

gammas <- c(35, -4, 2.2, -1.6, -0.7, 0.4, -0.4, 0.4, 0.4)
lambdas <- c(0.3, 0.4)

simGrid.delta5 <- computeVarGrid(simGrid, times, spltime, gammas,
                                 sigma, corstr = "exch", design = 1,
                                 varCombine = function(x)
                                   x[1] - 0.25 * abs(x[1] - x[2]))

# Construct string to name simulation results
simGrid.delta5$simName <- sapply(1:nrow(simGrid.delta5), function(i) {
  x <- simGrid.delta5[i, ]
  rdir <- as.character(x$respDirection)
  paste0("d1_delta5.",
         ifelse(x$r0 == x$r1, paste0("r", x$r0* 10),
                paste0("r0_", x$r0*10, ".r1_", x$r1*10)),
         ".exch", x$corr * 10, ".",
         x$respFunction, 
         paste0(toupper(substr(rdir, 1, 1)), substr(rdir, 2, nchar(rdir))),
         ifelse(x$oldModel, ".old", ""),
         ifelse(x$sharp, ".sharp", ""))
})

# Check validity of scenarios before trying to simulate them
# and remove any "invalid" ones
invalidSims.delta5 <- checkVarGridValidity(simGrid.delta5)
simGrid.delta5 <- simGrid.delta5[!is.element(simGrid.delta5$simName, 
                                             invalidSims.delta5$simName), ]
rownames(simGrid.delta5) <- 1:nrow(simGrid.delta5)

save(file = here("Results", "simsDesign1-delta5-sLBdown25.RData"),
     list = c("sigma", "simGrid.delta5", "invalidSims.delta5",
              "gammas", "lambdas", "seed", "times", "spltime"))

for (scenario in 1:nrow(simGrid.delta5)) {
  # Extract simulation conditions from simGrid.delta5
  r0 <- simGrid.delta5$r0[scenario]
  r1 <- simGrid.delta5$r1[scenario]
  sharp <- simGrid.delta5$sharp[scenario]
  corr <- c(simGrid.delta5$corr[scenario], simGrid.delta5$corr.r1[scenario],
            simGrid.delta5$corr.r0[scenario])
  respFunc.name <- simGrid.delta5$respFunction[scenario]
  respDir <- simGrid.delta5$respDirection[scenario]
  old <- simGrid.delta5$oldModel[scenario]
  
  # Extract variances from simGrid
  sigma.r0 <- simGrid.delta5$sigma.r00[scenario]
  sigma.r1 <- simGrid.delta5$sigma.r11[scenario]
  vars <- simGrid.delta5[scenario, 
                         c(grep("^sigma.nr[0-9].", names(simGrid.delta5)),
                           grep("^v2\\.", names(simGrid.delta5)))]
  
  if(respFunc.name == "response.oneT"){
    upsilon <- qnorm(r1, as.numeric(sum(gammas[1:3])), sigma,
                     lower.tail = FALSE)
    r0 <- pnorm(upsilon, sum(gammas[1:2]) - gammas[3], sigma,
                lower.tail = FALSE)
  }
  
  postID <- paste0(
    "Scenario ", scenario, " of ", nrow(simGrid.delta5), "\n",
    "sLBdown25 simulation setup\n",
    "Effect size: 0.5\n",
    "Response function:",
    respFunc.name,
    " ", respDir, "\n",
    ifelse(sharp, "sharp n",
           "conservative n")
  )
  
  if ((simGrid.delta5$sigma.r00[scenario] >
       simGrid.delta5$sigma.r0.UB[scenario]) |
      (simGrid.delta5$sigma.r11[scenario] >
       simGrid.delta5$sigma.r1.UB[scenario])) {
    designText <- paste0("Design 1\n",
                         postID,
                         "delta = 0.5\n",
                         "true corstr = exchangeable(", corr[1], ")\n",
                         "r0 = ", round(r0, 3), ", r1 = ", round(r1, 3))
    if (notify) slackr_bot(designText)
    warnText <- paste("The maximum allowable sigma.rXX (11 or 00) is less than",
                      "the chosen value of sigma.r.",
                      "Skipping for now...")
    assign(simGrid.delta5$simName[scenario], warnText)
    if (notify) slackr_bot(warnText)
    next
  }
  
  # Set the seed for every unique simulation
  set.seed(seed)
  
  assign(simGrid.delta5$simName[scenario],
         try(
           simulateSMART(
             gammas = gammas,
             lambdas = lambdas,
             r1 = r1,
             r0 = r0,
             times = times,
             spltime = spltime,
             alpha = .05,
             power = .8,
             delta = 0.5,
             design = 1,
             conservative = !sharp,
             sigma = sigma,
             sigma.r1 = sigma.r1,
             sigma.r0 = sigma.r0,
             variances = vars,
             pool.time = TRUE,
             L = c(0, 0, 2, 0, 2, 2, 2, 0, 0),
             corstr = "exch",
             rho = corr[1],
             rho.r1 = corr[2],
             rho.r0 = corr[3],
             respFunction = get(unlist(respFunc.name)),
             respDirection = respDir,
             niter = niter,
             notify = notify,
             old = old,
             postIdentifier = postID
           )),
         envir = .GlobalEnv)
  
  save(file = here("Results", "simsDesign1-delta5-sLBdown25.RData"),
       list = c(grep("d1_delta5", ls(), value = T), "sigma",
                "gammas", "lambdas", "seed", "times", "spltime", 
                "simGrid.delta5", "invalidSims.delta5"),
       precheck = TRUE)
}

if (notify) {
  x <- paste("All simulations are complete for Design 1,", 
             "effect size 0.5\n for sLBdown25 scenarios.")
  slackr_bot(x)
  rm(x)
}

rm(list = grep("d1_delta5", ls(), value = T))


##### Effect size: 0.8 #####

gammas <- c(35, -4, 2.2, -1.6, 0.2, 0.4, -0.4, 0.4, 0.4)
lambdas <- c(0.3, 0.4)

simGrid.delta8 <- computeVarGrid(simGrid, times, spltime, gammas,
                                 sigma, corstr = "exch", design = 1,
                                 varCombine = function(x)
                                   x[1] - 0.25 * abs(x[1] - x[2]))

# Construct string to name simulation results
simGrid.delta8$simName <- sapply(1:nrow(simGrid.delta8), function(i) {
  x <- simGrid.delta8[i, ]
  rdir <- as.character(x$respDirection)
  paste0("d1_delta8.",
         ifelse(x$r0 == x$r1, paste0("r", x$r0* 10),
                paste0("r0_", x$r0*10, ".r1_", x$r1*10)),
         ".exch", x$corr * 10, ".",
         x$respFunction, 
         paste0(toupper(substr(rdir, 1, 1)), substr(rdir, 2, nchar(rdir))),
         ifelse(x$oldModel, ".old", ""),
         ifelse(x$sharp, ".sharp", ""))
})

# Check validity of scenarios before trying to simulate them
# and remove any "invalid" ones
invalidSims.delta8 <- checkVarGridValidity(simGrid.delta8)
simGrid.delta8 <- simGrid.delta8[!is.element(simGrid.delta8$simName, 
                                             invalidSims.delta8$simName), ]
rownames(simGrid.delta8) <- 1:nrow(simGrid.delta8)

save(file = here("Results", "simsDesign1-delta8-sLBdown25.RData"),
     list = c("sigma", "simGrid.delta8", "invalidSims.delta8",
              "gammas", "lambdas", "seed", "times", "spltime"))

for (scenario in 1:nrow(simGrid.delta8)) {
  # Extract simulation conditions from simGrid.delta8
  r0 <- simGrid.delta8$r0[scenario]
  r1 <- simGrid.delta8$r1[scenario]
  sharp <- simGrid.delta8$sharp[scenario]
  corr <- c(simGrid.delta8$corr[scenario], simGrid.delta8$corr.r1[scenario],
            simGrid.delta8$corr.r0[scenario])
  respFunc.name <- simGrid.delta8$respFunction[scenario]
  respDir <- simGrid.delta8$respDirection[scenario]
  old <- simGrid.delta8$oldModel[scenario]
  
  # Extract variances from simGrid
  sigma.r0 <- simGrid.delta8$sigma.r00[scenario]
  sigma.r1 <- simGrid.delta8$sigma.r11[scenario]
  vars <- simGrid.delta8[scenario, 
                         c(grep("^sigma.nr[0-9].", names(simGrid.delta8)),
                           grep("^v2\\.", names(simGrid.delta8)))]
  
  # Recompute r0 if necessary
  if(respFunc.name == "response.oneT"){
    upsilon <- qnorm(r1, as.numeric(sum(gammas[1:3])), sigma,
                     lower.tail = FALSE)
    r0 <- pnorm(upsilon, sum(gammas[1:2]) - gammas[3], sigma,
                lower.tail = FALSE)
  }
  
  postID <- paste0(
    "Scenario ", scenario, " of ", nrow(simGrid.delta8), "\n",
    "sLBdown25 simulation setup\n",
    "Effect size: 0.8\n",
    "Response function:",
    respFunc.name,
    " ", respDir, "\n",
    ifelse(sharp, "sharp n",
           "conservative n")
  )
  
  if ((simGrid.delta8$sigma.r00[scenario] >
       simGrid.delta8$sigma.r0.UB[scenario]) |
      (simGrid.delta8$sigma.r11[scenario] >
       simGrid.delta8$sigma.r1.UB[scenario])) {
    designText <- paste0("Design 1\n",
                         postID,
                         "delta = 0.8\n",
                         "true corstr = exchangeable(", corr[1], ")\n",
                         "r0 = ", round(r0, 3), ", r1 = ", round(r1, 3))
    if (notify) slackr_bot(designText)
    warnText <- paste("The maximum allowable sigma.rXX (11 or 00) is less than",
                      "the chosen value of sigma.r.",
                      "Skipping for now...")
    assign(simGrid.delta8$simName[scenario], warnText)
    if (notify) slackr_bot(warnText)
    next
  }
  
  # Set the seed for every unique simulation
  set.seed(seed)
  
  assign(simGrid.delta8$simName[scenario],
         try(
           simulateSMART(
             gammas = gammas,
             lambdas = lambdas,
             r1 = r1,
             r0 = r0,
             times = times,
             spltime = spltime,
             alpha = .05,
             power = .8,
             delta = 0.8,
             design = 1,
             conservative = !sharp,
             sigma = sigma,
             sigma.r1 = sigma.r1,
             sigma.r0 = sigma.r0,
             variances = vars,
             pool.time = TRUE,
             L = c(0, 0, 2, 0, 2, 2, 2, 0, 0),
             corstr = "exch",
             rho = corr[1],
             rho.r1 = corr[2],
             rho.r0 = corr[3],
             respFunction = get(unlist(respFunc.name)),
             respDirection = respDir,
             niter = niter,
             notify = notify,
             old = old,
             postIdentifier = postID
           )),
         envir = .GlobalEnv)
  
  save(file = here("Results", "simsDesign1-delta8-sLBdown25.RData"),
       list = c(grep("d1_delta8", ls(), value = T), "sigma",
                "gammas", "lambdas", "seed", "times", "spltime", 
                "simGrid.delta8", "invalidSims.delta8"),
       precheck = TRUE)
}

if (notify) {
  x <- paste("All simulations are complete for Design 1,", 
             "effect size 0.8\n for sLBdown25 scenarios.")
  slackr_bot(x)
  rm(x)
}

rm(list = grep("d1_delta8", ls(), value = T))

if(check.dompi) {
  closeCluster(clus)
  mpi.quit()
} else {
  stopCluster(clus)
}
