
install.packages("shiny")
install.packages("rsconnect")
rsconnect::setAccountInfo(name='yimengyin', token='3585B8F296D58AE9DDC0392D37BCDD78', secret='Z8oAnBNEPC8cFtjQcK3wF4ByKxPKS5yafTVASvbb')
# account: marshallpku@gmail.com

library(shiny)
library(rsconnect)

getwd()
setwd("E:/GitHub/PenSim-Projects/PenSimShiny/ShinyApp")
setwd("..")

runApp("ShinyApp", display.mode = "auto" ) 


deployApp("./LearnShiny")
