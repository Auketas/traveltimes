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
resultsfull <- read_sheet(sheet_url, sheet = "Results")
resultsmodefull <- read_sheet(sheet_url, sheet="Transportmode")

origins <- c(routes$Origin,routes$Destination)
destinations <- c(routes$Destination,routes$Origin)
modes <- c("driving", "transit", "walking", "bicycling") 

# Initialize empty data frame to store results
results <- data.frame()
resultsmode <- data.frame()

# Loop over pairs
for (i in seq_along(origins)) {
  origin <- origins[i]
  destination <- destinations[i]
  
  for (mode in modes) {
  params <- list(
    origins = origin,
    destinations = destination,
    mode = mode,
    key = api_key
  )
  
  if (mode == "driving") {
    params$departure_time <- "now"         # enables live traffic
    params$traffic_model <- "best_guess"   # can also be "optimistic" or "pessimistic"
  }

  if (mode=="transit"){

      # Build request body
      body <- list(
        origin = list(address = origin),
        destination = list(address = destination),
        travelMode = "TRANSIT"
      )
      
      # Send POST request
      dir_res <- POST(
        url = "https://routes.googleapis.com/directions/v2:computeRoutes",
        add_headers(
          "Content-Type" = "application/json",
          "X-Goog-Api-Key" = api_key,
          "X-Goog-FieldMask" = "routes.duration,routes.distanceMeters,routes.legs.steps"
        ),
        body = toJSON(body, auto_unbox = TRUE)
      )
      
      # Parse response
      dir_content <- content(dir_res, "text", encoding = "UTF-8")
      dir_data <- fromJSON(dir_content, simplifyVector = FALSE)
      steps <- dir_data$routes[[1]]$legs[[1]]$steps
      
      modesuse <- c()
      for(i in 1:length(steps)){
        modesuse[i] <- ifelse(steps[[i]]$travelMode=="TRANSIT",steps[[i]]$transitDetails$transitLine$vehicle$type,steps[[i]]$travelMode)
      }
      modesuse <- modesuse[modesuse!="WALK"]
      modesuse <- paste(modesuse,collapse="-")
      
      resultsmode <- rbind(resultsmode, data.frame(
        Origin = origin,
        Destination = destination,
        Modes = modesuse,
        stringsAsFactors = FALSE
      )
      )
    
  }
  
  res <- GET("https://maps.googleapis.com/maps/api/distancematrix/json", query = params)
  
  content_raw <- content(res, "text", encoding = "UTF-8")
  data <- fromJSON(content_raw)
  
  element <- data$rows$elements[[1]]
  
  if (element$status != "OK") {
    duration_text <- NA
    duration_value <- NA
    status <- element$status
  } else {
    if (mode == "driving" && !is.null(element$duration_in_traffic)) {
      duration_text <- element$duration_in_traffic$text
      duration_value <- element$duration_in_traffic$value
    } else {
      duration_text <- element$duration$text
      duration_value <- element$duration$value
    }
    status <- "OK"
  }
  
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
results$weekday <- weekdays(as.Date(date_part))
resultsmode$Date <- date_part
results$time <- time_part
results$Weekday <- weekdays(as.Date(date_part))



#if(file.exists("data/traveltimes.csv")){
  #resultsfull <- read.csv("data/traveltimes.csv")
  #resultsfull <- rbind(resultsfull,results)
  #write.csv(resultsfull,"data/traveltimes.csv",row.names=FALSE)
#}else{
  #resultsfull <- results
  #write.csv(resultsfull,"data/traveltimes.csv",row.names=FALSE)
#}
print("results")
print(ncol(resultsfull))
print(colnames(resultsfull))
print(ncol(results))
print(colnames(results))
print("results mode")
print(ncol(resultsmodefull))
print(colnames(resultsmodefull))
print(ncol(resultsmode))
print(colnames(resultsmode))
resultsfull <- rbind(resultsfull,results)
resultsmodefull <- rbind(resultsmodefull,resultsmode)

sheet_write(resultsfull, ss = sheet_url, sheet = "Results")
sheet_write(resultsmodefull, ss = sheet_url, sheet = "Transportmode")
