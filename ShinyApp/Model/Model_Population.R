# Population Simulation by 3D array for actuarial valuation
# Yimeng Yin
# 2/3/2015

get_Population <- function(.init_pop = init_pop,
                           .entrants_dist= entrants_dist,
                           .paramlist    = paramlist,
                           .Global_paramlist = Global_paramlist){


## Issues
 # For now, new entrants are equally distributed across all entry ages. 
 # growth of workforce(controlled by growth rate or pre-defined path of growth.)

## Inputs
 # - range_ea:         all possible entry ages  
 # - range_age:        range of age
 # - nyear:            number of years in simulation
 # - wf_growth:        growth rate of the size of workforce
 # - no_entrance:      no new entrants into the workforce if set "TRUE". Overrides "wf_growth"
 # - Decrement table:  from Model_Decrements.R  
 # - Initial workforce for each type:
 #    - init_pop$actives:   matrix, max ea by max age
 #    - init_pop$retirees:  matrix, max ea by max age


## An array is created for each of the 6 status:
 #  (1)Active     (dim = 3)
 #  (2)Terminated (dim = 4)
 #  (3)Disabled   (dim = 3) later will be expanded to dim = 4, with additional dim being year.disb
 #  (4)Retired    (dim = 3) later will be expanded to dim = 4, with additional dim being year.retired
 #  (5)Dead       (dim = 3) We do not really need an array for dead, what's needed is only the total number of dead.  

  
assign_parmsList(.Global_paramlist, envir = environment())
assign_parmsList(.paramlist,        envir = environment())  

#*************************************************************************************************************
#                                     Creating arrays for each status ####
#*************************************************************************************************************


  
## In each 3D array, dimension 1(row) represents entry age, dimension 2(column) represents attained age,
 # dimension 3(depth) represents number of year, dimension 4(terms only) represents the termination year. 
wf_dim <- c(length(range_ea), length(range_age), nyear)
wf_dimnames <- list(range_ea, range_age, 1:nyear)

# The array of terminated has 4 dimensions: ea x age x year x year of termination
wf_dim.term      <- c(length(range_ea), length(range_age), nyear, nyear)
wf_dimnames.term <- list(range_ea, range_age, 1:nyear, 1:nyear)


wf_active  <- array(0, wf_dim, dimnames = wf_dimnames)
wf_disb    <- array(0, wf_dim, dimnames = wf_dimnames) 
wf_retired <- array(0, wf_dim, dimnames = wf_dimnames)
wf_dead    <- array(0, wf_dim, dimnames = wf_dimnames)
wf_term    <- array(0, wf_dim.term, dimnames = wf_dimnames.term)


#*************************************************************************************************************
#                                     Setting initial population  ####
#*************************************************************************************************************

# Setting inital distribution of workforce and retirees.
wf_active[, , 1]  <- .init_pop$actives 
wf_retired[, , 1] <- .init_pop$retirees



#*************************************************************************************************************
#                                     Defining population dynamics  ####
#*************************************************************************************************************

## Transition matrices ####

# Assume the actual decrement rates are the same as the rates in decrement tables.
# Later we may allow the actual decrement rates to differ from the assumed rates. 

decrement_wf <- sapply(decrement, function(x){x[is.na(x)] <- 0; return(x)}) %>% data.frame

# Adjustment to retirement rates.
# The time line used in this model assume retirement occurs at the beginning of every period. In other words the 
# switch of retirement status happens at the beginning of each period. However, the transition process here requires that
# any switch of status between t - 1(beginning) and t(beginning) must be defined in period t - 1. Hence we need to make following 
# adjustment to the decrement table:
  # Move qxr.a backward by 1 period.(qxr at t is now assigned to t - 1), the probability of retirement at t - 1 is lead(qxr.a(t))*(1 - qxt.a(t-1) - qxm.a(t-1) - qxd.a(t-1))
  # For the age right before the max retirement age (r.max - 1), probability of retirement is 1 - qxm.a - qxd.a - qxt.a,
    # which means all active members who survive all other risks at (r.max - 1) will enter the status "retired" for sure at age r.max (and collect the benefit regardless 
    # whether they will die at r.max)      

decrement_wf %<>% group_by(ea) %>%  
                  mutate(qxr.a = ifelse(age == r.max - 1,
                         1 - qxt.a - qxm.a - qxd.a, 
                         lead(qxr.a)*(1 - qxt.a - qxm.a - qxd.a)))

# decrement_wf %>% filter(age == 64)

# Define a function that produce transition matrices from decrement table. 
make_dmat <- function(qx, df = decrement_wf) {
  # inputs:
  # qx: character, name of the transition probability to be created.
  # df: data frame, decrement table.
  # returns:
  # a transtion matrix
  df %<>% select_("age", "ea", qx) %>% ungroup %>% spread_("ea", qx, fill = 0) %>% select(-age) %>% t # need to keep "age" when use spread
  dimnames(df) <- wf_dimnames[c(1,2)] 
  return(df)
}
#(p_active2term_nv <- make_dmat("qxtnv.a"))  # test the function


# The transition matrices are defined below. The probabilities (eg. qxr for retirement) of flowing
# from the current status to the target status for a cell(age and ea combo) are given in the corresponding
# cell in the transtition matrices. 

# Where do the active go
p_active2term    <- make_dmat("qxt.a")
p_active2disb    <- make_dmat("qxd.a")
p_active2dead    <- make_dmat("qxm.a")
p_active2retired <- make_dmat("qxr.a")

# Where do the terminated go
p_term2dead    <- make_dmat("qxm.t")
# p_term2retired <- make_dmat("qxr.v")


# Where do the disabled go
#p_disb2retired   <- make_dmat("qxr.d")
p_disb2dead      <- make_dmat("qxm.d")

# Where do the retired go
p_retired2dead   <- make_dmat("qxm.r")

# In each iteration, a flow matrix for each possible transition(eg. active to retired) is created 
# (if we wanted to track the flow in each period, we create flow arrays instead of flow matrices)

# Define the shifting matrix. When left mutiplied by a workforce matrix, it shifts each element one cell rightward(i.e. age + 1)
# A square matrix with the dimension length(range_age)
# created by a diagal matrix without 1st row and last coloumn
A <- diag(length(range_age) + 1)[-1, -(length(range_age) + 1)] 


#*************************************************************************************************************
#                                     Creating a function to calculate new entrants ####
#*************************************************************************************************************


# define function for determining the number of new entrants 
calc_entrants <- function(wf0, wf1, delta, dist, no.entrants = FALSE){
  # This function deterimine the number of new entrants based on workforce before and after decrement and workforce 
  # growth rate. 
  # inputs:
  # wf0: a matrix of workforce before decrement. Typically a slice from wf_active
  # wf1: a matrix of workforce after decrement.  
  # delta: growth rate of workforce
  # returns:
  # a matrix with the same dimension of wf0 and wf1, with the number of new entrants in the corresponding cells,
  # and 0 in all other cells. 
  
  # working age
  working_age <- min(range_age):(r.max - 1)
  # age distribution of new entrants
  # dist <- rep(1/nrow(wf0), nrow(wf0)) # equally distributed for now. 
  
  # compute the size of workforce before and after decrement
  size0 <- sum(wf0[,as.character(working_age)], na.rm = TRUE)
  size1 <- sum(wf1[,as.character(working_age)], na.rm = TRUE)
  
  # computing new entrants
  size_target <- size0*(1 + delta)   # size of the workforce next year
  size_hire   <- size_target - size1 # number of workers need to hire
  ne <- size_hire*dist               # vector, number of new entrants by age
  
  # Create the new entrant matrix 
  NE <- wf0; NE[ ,] <- 0
  
  if (no.entrants){ 
    return(NE) 
  } else {
    NE[, rownames(NE)] <- diag(ne) # place ne on the matrix of new entrants
    return(NE)
  } 
}

# test the function 
 # wf0 <- wf_active[, , 1]
 # wf1 <- wf_active[, , 1]*(1 - p_active2term)
 # sum(wf0, na.rm = T) - sum(wf1, na.rm = T)
 # sum(calc_entrants(wf0, wf1, 0), na.rm = T)



#*************************************************************************************************************
#                                     Simulating the evolution of population  ####
#*************************************************************************************************************

# Now the next slice of the array (array[, , i + 1]) is defined
# wf_active[, , i + 1] <- (wf_active[, , i] + inflow_active[, , i] - outflow_active[, , i]) %*% A + wf_new[, , i + 1]
# i runs from 2 to nyear. 

for (j in 1:(nyear - 1)){
#i <-  1  
  # compute the inflow to and outflow
  active2term  <- wf_active[, , j] * p_active2term  # This will join wf_term[, , j + 1, j], note that workers who terminate in year j won't join the terminated group until j+1. 
  active2disb  <- wf_active[, , j] * p_active2disb
  active2dead  <- wf_active[, , j] * p_active2dead
  active2retired <- wf_active[, , j] * p_active2retired
  
  # Where do the terminated_vested go
  term2dead    <- wf_term[, , j, ] * as.vector(p_term2dead)    # a 3D array, each slice(3rd dim) contains the # of death in a termination age group

  # Where do the disabled go
  disb2dead      <- wf_disb[, , j] * p_disb2dead
  
  # Where do the retired go
  retired2dead   <- wf_retired[, , j] * p_retired2dead
  
  
  # Total inflow and outflow for each status
  out_active   <- active2term + active2disb + active2retired + active2dead 
  new_entrants <- calc_entrants(wf_active[, , j], wf_active[, , j] - out_active, wf_growth, dist = .entrants_dist, no.entrants = no_entrance) # new entrants
  
  out_term <- term2dead    # This is a 3D array 
  in_term  <- active2term  # This is a matrix
  
  out_disb <- disb2dead
  in_disb  <- active2disb
  
  out_retired <- retired2dead
  in_retired  <- active2retired
  
  in_dead <- active2dead + apply(term2dead, c(1,2), sum) + disb2dead + retired2dead
  
  # Calculate workforce for next year. 
  wf_active[, , j + 1]  <- (wf_active[, , j] - out_active) %*% A + new_entrants
  
  wf_term[, , j + 1, ]  <- apply((wf_term[, , j, ] - out_term), 3, function(x) x %*% A) %>% array(wf_dim.term[-3])
  wf_term[, , j + 1, j] <- in_term %*% A
  
  wf_disb[, ,   j + 1]    <- (wf_disb[, , j] + in_disb - out_disb) %*% A
  wf_retired[, ,j + 1]    <- (wf_retired[, , j] + in_retired - out_retired) %*% A
  wf_dead[, ,   j + 1]    <- (wf_dead[, , j] + in_dead) %*% A
}

return(list(active = wf_active, term = wf_term, disb = wf_disb, retired = wf_retired, dead = wf_dead))

}


start_time_wf <- proc.time()

pop <- get_Population()

end_time_wf <- proc.time()
Time_wf <- end_time_wf - start_time_wf


#*************************************************************************************************************
#                                     Checking the results  ####
#*************************************************************************************************************

# 
# # The workforce arrays
# wf_active
# wf_retired
# wf_term_nv
# wf_term_v
# wf_disb
# wf_dead
# 
# # Test the loop with no new entrants, set no.entrants = TRUE in cal_entrants()
#   
#   apply(wf_active, 3, sum)  + 
#   apply(wf_retired, 3, sum) + 
#   apply(wf_term_v, 3, sum)  + 
#   apply(wf_term_nv, 3, sum) + 
#   apply(wf_disb, 3, sum)    + 
#   apply(wf_dead, 3, sum) 
#   
# 
# # summarizing the results
# 
# # popluation by status
# apply(wf_active, 3, sum)  %>%  plot(type = "b") 
# apply(wf_retired, 3, sum) %>%  plot(type = "b")   
# apply(wf_term_v, 3, sum)  %>%  plot(type = "b")  
# apply(wf_term_nv, 3, sum) %>%  plot(type = "b")  
# apply(wf_disb, 3, sum)    %>%  plot(type = "b")  
# apply(wf_dead, 3, sum)    %>%  plot(type = "b")  
# 
# 
# # Total population
# (apply(wf_active, 3, sum) + 
#    apply(wf_retired, 3, sum) + 
#    apply(wf_term_v, 3, sum) + 
#    apply(wf_term_nv, 3, sum) + 
#    apply(wf_disb, 3, sum)) %>% plot(type = "b")
# 
# # Look at workforce by entry age
# apply(wf_active, c(1,3), sum)
# 
# # Look at workforce by age
# # options(digits = 4, scipen = 99)
# apply(wf_active, c(2,3), sum)
# # Potential problem, values for age over 65 are not exact 0s, although may be computationally equivalent to 0s.
# 
#  






# x <- array(0, c(3,3,3,3))
# for(i in 1:3) x[,,,i] <- i
# x[,,1,]
# x[,,1,] * as.vector(matrix(1:9, 3, 3))
#   
# matrix(1, 3,3) *   as.vector(matrix(1:9, 3, 3))
# 

#  x <- array(0, c(2,2,2,2))
#  for(i in 1:2) x[,,,i] <- i
# microbenchmark(
# alply(x[,,1,], 3, function(x) (x %*% matrix(1:4, 2))) %>% unlist %>% array(c(2,2,2)),
# apply(x[,,1,], 3, function(x) (x %*% matrix(1:4, 2))) %>% array(c(2,2,2))
# )
# 
# 
# x[,,1,]
# 
# 
# x[,,1,] %>% apply(c(1,2), sum)

# wf_term[,,2,1]





