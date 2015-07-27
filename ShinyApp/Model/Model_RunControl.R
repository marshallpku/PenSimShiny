## 5/28/2015


#*********************************************************************************************************
#                      Preamble ####
#*********************************************************************************************************

rm(list = ls())
gc()

library(knitr)
library(data.table)
library(gdata) # read.xls
library(plyr)
library(dplyr)
library(ggplot2)
library(magrittr)
library(tidyr) # gather, spread
library(foreach)
library(doParallel)
library(microbenchmark)
library(data.table)
library(readxl)
library(stringr)
# library(xlsx)
# library(XLConnect) # slow but convenient because it reads ranges
# devtools::install_github("donboyd5/decrements")
# devtools::install_github("donboyd5/pp.prototypes")

library(pp.prototypes)
library(decrements)               # mortality and termination for now
load("Model/Data/winklevossdata.rdata") # disability, disability mortaity and early retirement
# load("Data/example_Salary_benefit.RData")


# source("Model/Functions.R")

devMode <- FALSE # Enter development mode if true. Parameters and initial population will be imported from Dev_Params.R instead of the RunControl file. 



#*********************************************************************************************************
# Read in Run Control files ####
#*********************************************************************************************************

folder_run          <- "Model"
filename_RunControl <- dir(folder_run, pattern = "^RunControl")

path_RunControl <- paste0(folder_run, "/" ,filename_RunControl)


# Import global parameters
Global_params <- read_excel(path_RunControl, sheet="GlobalParams", skip=1) 


# Import parameters for all plans
plan_params        <- read_excel(path_RunControl, sheet="RunControl", skip=4)    %>% filter(!is.na(runname))
plan_returns       <- read_excel(path_RunControl, sheet="Returns",    skip=0)    %>% filter(!is.na(runname))
plan_contributions <- read_excel(path_RunControl, sheet="Contributions", skip=0) %>% filter(!is.na(runname))




#*********************************************************************************************************
# Read in Run Control files ####
#*********************************************************************************************************

## select plans
runlist <- plan_params %>% filter(include == TRUE) %>% select(runname) %>% unlist


## Run selected plans 

for (runName in runlist){

suppressWarnings(rm(paramlist, Global_paramlist))
  
## Extract plan parameters 
paramlist    <- get_parmsList(plan_params, runName)
paramlist$plan_returns <- plan_returns %>% filter(runname == runName)
if(paramlist$exCon) paramlist$plan_contributions <- trans_cont(plan_contributions, runName) else 
                    paramlist$plan_contributions <- list(0) 


## Extract global parameters and coerce the number of simulation to 1 when using deterministic investment reuturns.
Global_paramlist <- Global_params %>% as.list
if ((paramlist$return_type == "simple" & paramlist$ir.sd == 0) |
    (paramlist$return_type == "internal" &  all(paramlist$plan_returns$ir.sd == 0))|
    (paramlist$return_type == "external")){
  
  Global_paramlist$nsim <- 1
}

## Run the model
#source("Model/Model_Master.R", echo = TRUE)
}



