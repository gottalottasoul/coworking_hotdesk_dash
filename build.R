# ./build.r
# This is the master file for ETL of data needed for marketing/sales reports
# Blake Abbenante
# 10/1/19

if (!require(tidyverse)) {
  install.packages('tidyverse') # load the base tidyverse libraries (dplyr, tidyr, etc.)
  require(tidyverse)
}
if (!require(janitor)) {
  install.packages('janitor') # functions for augmenting dataframes
  require(janitor)
}
if (!require(readr)) {
  install.packages('readr') # enhanced functions for loading data
  require(readr)
}
if (!require(lubridate)) {
  install.packages('lubridate') # enhanced functions for loading data
  require(lubridate)
}
if (!require(here)) {
  install.packages('here') # file referencing
  require(here)
}
if (!require(httr)) {
  install.packages('httr') # http posts
  require(httr)
}
if (!require(config)) {
  install.packages('config') # read a config file
  require(config)
}
if (!require(RiHana)) {
  devtools::install_github('RiHana') #Hana stuff
  require(RiHana)
}


## clear the console of all variables
rm(list = ls())
## free up unused memory
gc()

release_notes<-'Now supporting mutliple value choices for location and acquisition channel.'

hana_dates<-RiHana::get_relevant_date()

config<-config::get(file="~/OneDrive - CBRE, Inc/data/config/r_config.yaml")



###Build the reports ####

#check if our cached data is less than a day old, otherwise run the ETL script
file_date<-file.info('inc/share_data.RData')$mtime

 if(difftime(now(),file_date,units="hours")>24)
 {
  source("share_etl.R")
}


share_pub<-rsconnect::deployDoc("shareExplore.rmd",forceUpdate=TRUE,launch.browser=FALSE)

if (share_pub){
  POST(url=config$insights_webhook,body=get_slack_payload("Share Explore Dashboard","https://blake-abbenante-hana.shinyapps.io/shareExplore/",release_notes),encode="json")
}

