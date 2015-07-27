library(shiny)

# Define UI for application that draws a histogram
shinyUI(fluidPage(

  # Application title
  titlePanel("Hello World!"),

  # Sidebar with a slider input for the number of bins
  sidebarLayout(
    sidebarPanel(
      sliderInput("InitFR",
                  "Initial Funded Ratio",
                  min = 0,
                  max = 1,
                  value = 0.75),
      
    submitButton("Update")
    ),

    # Show a plot of the generated distribution
    mainPanel(
      tableOutput("table")
    )
  )
))