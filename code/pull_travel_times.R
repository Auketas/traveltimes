library(httr)
library(jsonlite)
library(googlesheets4)
library(dplyr)

# Read secret key from environment variable
key <- Sys.getenv("GCP_SHEETS_KEY")
keyfile <- tempfile(fileext = ".json")
writeLines(key, keyfile)
gs4_auth(path = keyfile)

# Your Google Maps API key
api_key <- Sys.getenv("GOOGLEMAPS_API_KEY")

#routes <- read.csv("data/routes.csv")
sheet_url <- "https://docs.google.com/spreadsheets/d/1gn_S5CmDFZTuLHE43yAx37sdnKmTyY-LS_L_jugc5_U/edit?gid=1954153640#gid=1954153640"
routes <- read_sheet(sheet_url, sheet = "Routes")

origins <- routes$Origin
destinations <- routes$Destination
modes <- c("driving", "transit", "walking", "bicycling") 

# Initialize empty data frame to store results
results <- data.frame()

# Loop over pairs
for (i in seq_along(origins)) {
  origin <- origins[i]
  destination <- destinations[i]
  print(paste("Trying", origin, "to", destination))
  
  for (mode in modes) {
    res <- GET("https://maps.googleapis.com/maps/api/distancematrix/json", query = list(
      origins = origin,
      destinations = destination,
      mode = mode,
      key = api_key
    ))
    
    content_raw <- content(res, "text", encoding = "UTF-8")
    data <- fromJSON(content_raw)
    
    element <- data$rows$elements[[1]]
    
    # Skip if no result
    if (element$status != "OK") {
      duration_text <- NA
      duration_value <- NA
      status <- element$status
    } else {
      duration_text <- element$duration$text
      duration_value <- element$duration$value
      status <- "OK"
    }
    
    # Append to results
    results <- rbind(results, data.frame(
      origin = origin,
      destination = destination,
      mode = mode,
      duration_text = duration_text,
      duration_sec = duration_value,
      status = status,
      stringsAsFactors = FALSE
    ))
  }
}

portugal_time <- as.POSIXct(Sys.time(), tz = "Europe/Lisbon")

# Extract date and time separately
date_part <- format(portugal_time, "%Y-%m-%d")
time_part <- format(portugal_time, "%H:%M:%S")

results$date <- date_part
results$time <- time_part



if(file.exists("data/traveltimes.csv")){
  resultsfull <- read.csv("data/traveltimes.csv")
  resultsfull <- rbind(resultsfull,results)
  write.csv(resultsfull,"data/traveltimes.csv",row.names=FALSE)
}else{
  resultsfull <- results
  write.csv(resultsfull,"data/traveltimes.csv",row.names=FALSE)
}

sheet_write(resultsfull, ss = sheet_url, sheet = "Results")

