library(shiny)

# Define UI for application that draws a histogram
shinyUI(fluidPage(

  # Application title
  titlePanel("Pension Simulation Model"),

  # Sidebar with a slider input for the number of bins
  sidebarLayout(
    sidebarPanel(
      actionButton("run", "Run Model"),
      
    
      radioButtons("init_MA", "How Initial Market Asset Value is Determined",
                   c("A Percentage of AL" = "AL_pct",
                     "Preset Value"       = "MA",
                     "Equal to AL"        = "AL")),
      
      conditionalPanel(
        condition = "input.init_MA == 'AL_pct'  ",
        sliderInput("InitFR", "Initial Funded Ratio (%)", min = 0, max = 100, value = 75)
      ),
      
      conditionalPanel(
        condition = "input.init_MA == 'MA'  ",
        numericInput("InitMA", "Initial Market Asset Value", value = 0, max = Inf, min = 0)
      ),
      
      
      numericInput("i", "Discount Rate (%)", 7.5, min = 0, max = 25),
      
      selectInput("actives", "Choose prototype for active members", 
                  choices = c("average", "youngplan", "oldplan", "highabratio")),
      
      h3("Smoothing Policies"),
      
      
      
      radioButtons("amort_type", "Amortization method: Open or Closed",
                   c("Open" = "open",
                     "Closed" = "closed")),
      
      radioButtons("amort_method", "Amortization: Constant Dollar or Constant Percent",
                   c("Constant Dollar" = "cd",
                     "Constant Perncent" = "cp")),
      
      numericInput("m", "Amortization Period", 30, min = 1, max = 40, width = "50%")
      
      
    #submitButton("Update")
    ),

    # Show a plot of the generated distribution
    mainPanel(
      
      tabsetPanel(
        tabPanel("Table", 
                 h4("Table1"),
                 tableOutput("table1"), 

                 h4("Table2"),
                 tableOutput("table2")),
        
        tabPanel("Plots", 
                 h4("Quantile Plot for Funded Ratio"),
                 plotOutput("plot_FR_MA", width = 600, height = 500),
                 
                 h4("Quantile Plot for Total Contribution Rate"),
                 plotOutput("plot_C_PR", width = 600, height = 500))
        
      )
      
    )
  )
)
)