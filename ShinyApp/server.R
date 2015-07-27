library(shiny)
library(ggplot2)

## Global Functions ####
source("Model/Functions.R", local = TRUE)


# Define server logic ####
shinyServer(function(input, output) {

outputs_list <- eventReactive(input$run, {
   
   source("Model/Model_RunControl.R", local = TRUE)
  
   paramlist$init_MA <- input$init_MA
   if(!is.null(input$InitFR)) paramlist$MA_0_pct <- input$InitFR/100
   if(!is.null(input$InitMA)) paramlist$MA_0     <- input$InitMA
   
   paramlist$i <- input$i/100
   
   paramlist$planname_actives <- input$actives
   
   # Amortization
   paramlist$amort_type   <- input$amort_type
   paramlist$amort_method <- input$amort_method
   paramlist$m            <- input$m
   
   
   
   source("Model/Model_Master.R", local = TRUE, echo = TRUE)
   outputs_list
    })


  output$table1 <- renderTable({
    outputs_list()$r1})

  output$table2 <- renderTable({
    outputs_list()$r2})
  
  output$plot_FR_MA <- renderPlot({
    print(draw_quantiles("Shiny", "FR_MA", data = outputs_list()$results)$plot)
    })
  
  output$plot_C_PR <- renderPlot({
    print(draw_quantiles("Shiny", "C_PR", data = outputs_list()$results)$plot) 
  })
  
  
  
  })