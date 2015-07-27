library(shiny)

source("Model/Functions.R", local = TRUE)
# source("Model/Model_RunControl.R")

# Define server logic required to draw a histogram
shinyServer(function(input, output) {

r1 <- reactive({
   source("Model/Model_RunControl.R", local = TRUE)
   paramlist$MA_0_pct <- input$InitFR
   source("Model/Model_Master.R", local = TRUE, echo = TRUE)
   r1

    })


  output$table <- renderTable({
    r1()
    })
})