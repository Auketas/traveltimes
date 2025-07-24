library(httr)
library(jsonlite)

# Your Google Maps API key
api_key <- Sys.getenv("GOOGLEMAPS_API_KEY")

routes <- read.csv("data/routes.csv")

origins <- routes$Origins
destinations <- routes$Destinations
modes <- c("driving", "transit", "walking", "bicycling") 

# Initialize empty data frame to store results
results <- data.frame()

# Loop over pairs
for (i in seq_along(origins)) {
  origin <- origins[i]
  destination <- destinations[i]
  
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
  write.csv(results,"data/traveltimes.csv",row.names=FALSE)
}
