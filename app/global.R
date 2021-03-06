if (!require("tidyverse")) {
  install.packages("tidyverse")
  library(tidyverse)
}
if (!require("shinythemes")) {
  install.packages("shinythemes")
  library(shinythemes)
}

if (!require("raster")) {
  install.packages("raster")
  library(raster)
}
if (!require("RCurl")) {
  install.packages("RCurl")
  library(RCurl)
}
if (!require("maps")) {
  install.packages("maps")
  library(maps)
}
if (!require("maptools")) {
  install.packages("maptools")
  library(maptools)
}
if (!require("rgdal")) {
  install.packages("rgdal")
  library(rgdal)
}
if (!require("leaflet")) {
  install.packages("leaflet")
  library(leaflet)
}
if (!require("shiny")) {
  install.packages("shiny")
  library(shiny)
}
if (!require("shinythemes")) {
  install.packages("shinythemes")
  library(shinythemes)
}
if (!require("plotly")) {
  install.packages("plotly")
  library(plotly)
}
if (!require("ggplot2")) {
  install.packages("ggplot2")
  library(ggplot2)
}
if (!require("tigris")) {
  install.packages("tigris")
  library(tigris)
}
if (!require("geojsonio")) {
  install.packages("geojsonio")
  library(geojsonio)
}
if (!require("rgdal")) {
  install.packages("rgdal")
  library(rgdal)
}
if (!require("htmltools")) {
  install.packages("htmltools")
  library(htmltools)
}
if (!require("sp")) {
  install.packages("sp")
  library(sp)
}
if (!require("rgdal")){
  install.packages("rgdal")
  library(rgdal)
}
if (!require("basictabler")) {
  install.packages("basictabler")
  library(basictabler)
}

b64 <- base64enc::dataURI(file="../output/group10.png", mime="image/png")

# Data Processing
covid <- read_csv('../output/covid_cleaned.csv')
att <- read_csv('../output/Project 2 State Attractions.csv')
att <- att %>%
  rename('Lng' = `Latitude (E/W)`) %>%
  rename('Lat' = `Longitude (N/S)`) %>%
  mutate(Lng = -Lng)

covid <-  covid %>%
  filter(!is.na(Long_)) %>%
  filter(!is.na(Lat)) %>%
  filter(!is.na(Incidence_Rate)) %>%
  filter(Admin2 != 'Unassigned') %>%
  mutate(FIPS = ifelse(Province_State == "Connecticut", paste0("0",FIPS), FIPS))

date_choices <- as.Date(covid$Last_Update,format = 'X%m.%d.%y')

geo_try <- counties(c('New York','New Jersey','Massachusetts','Virginia',
                      'Maryland','Pennsylvania','Connecticut','Delaware',
                      'Rhode Island','West Virginia','District of Columbia'), cb =TRUE)

geo_try <- geo_try %>% mutate(Combine = paste(STATEFP, COUNTYFP, sep = ""))

covid <- merge(geo_try,
               covid,
               by.x = 'Combine',
               by.y = 'FIPS')

#--------------------------------------------------------------------------------------# Second Page Ends Here
# begin data prep
page2 <- read_csv('../output/covid_cleaned.csv') %>% filter(Last_Update == max(Last_Update)) %>%
  filter(Admin2 != 'Unassigned') %>%
  mutate(FIPS = formatC(FIPS, width = 5, format = 'd', flag = '0') ) %>%
  mutate(STATEFP = substr(FIPS, 1, 2)) %>% 
  transform(Province_State = tolower(Province_State)) %>%
  transform(Country_Region = tolower(Country_Region)) %>%
  transform(Admin2 = tolower(Admin2)) %>%
  # add leading zeros to any FIPS code that's less than 5 digits
  transform(FIPS = formatC(FIPS, width = 5, format = 'd', flag = '0'))
# lower column names
colnames(page2) <- tolower(colnames(page2))

# the shape file
county <- readOGR('../data/cb_2018_us_county_500k/cb_2018_us_county_500k.shp')
# select target states
county <- county[county$STATEFP %in% c('09','10','24','25','34','36','42','44','51','11','54'),]

# get the attractions data
attraction <- read_csv('../output/Project 2 State Attractions.csv') %>%
  transform(State = tolower(State)) %>%
  transform(County = tolower(County))
# rename columns
colnames(attraction) <- tolower(colnames(attraction))
colnames(attraction)[1:5] <- c('taname','province_state','admin2','latitude','longitude')
attraction$longitude = -attraction$longitude

# the funtion, input will be the state's name
countylevelmap <- function(x){
  x <- tolower(x)
  foo <- page2[page2$province_state == x,]
  # get the shape file for that state
  code <- unique(foo$statefp)[1]
  shape <- county[county$STATEFP == code,]
  # for polygons
  data <- sp::merge(x = shape, y = foo,by.y = 'fips', by.x = 'GEOID', all.y = TRUE, duplicateGeoms = TRUE)
  pop <- paste0('<strong>',data$NAME,'</strong>  ',round(data$incidence_rate,digits = 2))
  pal <- colorNumeric('YlOrRd', NULL, n = 9,)
  # for markers
  x <- ifelse(x == 'district of columbia','washington dc', x)
  my_att <- attraction[attraction$province_state == x,]
  attpop <- paste('<strong>',my_att$taname,'<br> Label:</strong>',my_att$label)
  # create markers
  leafIcons <- icons(
    iconUrl = ifelse(my_att$label %in% c('University','Landmark','Monument','Museum','Theater'),'https://www.flaticon.com/svg/static/icons/svg/3581/3581154.svg',
                     ifelse(my_att$label %in% c('Hiking','Trail'),'https://www.flaticon.com/svg/static/icons/svg/3373/3373903.svg',
                            ifelse(my_att$label %in% c("Amusement Park","National Park","Park",'Zoo','Ranch'),'https://www.flaticon.com/svg/static/icons/svg/2510/2510287.svg',
                                   ifelse(my_att$label %in% c('Boat Tour','Beach'), 'https://www.flaticon.com/svg/static/icons/svg/1175/1175010.svg',
                                          ifelse(my_att$label %in% c('Wineries','Casino'), 'https://www.flaticon.com/svg/static/icons/svg/1432/1432256.svg',
                                                 ifelse(my_att$label == "Arenas & Stadiums", 'https://www.flaticon.com/svg/static/icons/svg/2570/2570450.svg','https://www.flaticon.com/svg/static/icons/svg/2536/2536611.svg')
                                          ))))),
    iconWidth = 38, iconHeight = 40, shadowWidth = 10, shadowHeight = 10
  )
  # Produce Map:
  return(leaflet() %>% addTiles() %>%
           addPolygons(data = data,fillColor = ~pal(incidence_rate), fillOpacity = 0.5, popup = pop,color = 'white')%>%
           addMarkers(data = my_att, ~longitude,~latitude, label = ~taname, icon = leafIcons, popup = attpop)
  )
}

countytabel <- function(x){
  x <- ifelse(x == 'District of Columbia','washington dc',x)
  return(DT::datatable(attraction[attraction$province_state == tolower(x),][,1:7],
                options = list( pageLength = 3),
                colnames = c('Desitination','State','County','Latitude','Longitude','Label','Source')))
  
}