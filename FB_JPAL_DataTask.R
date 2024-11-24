
# JPAL RA Data Task
# October 28th, 2024

# Data manipulation packages ####
library(dplyr)
library(knitr)
library(ggplot2)
library(readr)
library(zoo)
library(tidyr)
rm(list = objects())

#  ----------- Uploading/cleaning BEA Data --------------####
# Per capita personal income for 1943-1964 in dollars
# cleaned to remove NA columns and irrelevant locations
pcinc <- read_csv("Documents/R/MIT JPAL/ra_task_files/pcinc.csv")
area_filter <- c("United States", "District of Columbia", "Hawaii 3/", "Alaska",
                  "New England", "Mideast", "Great Lakes", "Plains", "Southeast",
                  "Southwest", "Rocky Mountain", "Far West 3/", "NA")
clean_pcinc <- pcinc %>%
  filter(!(AreaName %in% area_filter)) %>%
  select(!c("Per capita personal income 2/ (dollars)", "FIPS")) %>%
  na.omit(clean_pcinc) %>%
  type_convert(guess_integer = TRUE)

# Population for 1947-1964
# cleaned to remove extraneous data
pop <- read_csv("Documents/R/MIT JPAL/ra_task_files/pop.csv")
clean_pop <- pop %>%
  filter(!(AreaName %in% area_filter)) %>%
  select(!c("Population 1/ (number of persons)", "FIPS")) %>%
  na.omit(clean_pcinc) %>%
  type_convert(guess_integer = TRUE)

# Hill Burton Project Register (filtering for only relevant data)
# cleaned to include variable and states of interest
hbpr <- read_tsv("Documents/R/MIT JPAL/ra_task_files/hbpr.txt")

included_locations <- hbpr %>%
  select(c(State)) %>%
  distinct(State)

state_filter <- c("Alaska", "Hawaii", "Dist of Col", "American Samoa", "Guam", 
                  "Puerto Rico", "Virgin Islands")

clean_hbpr <- hbpr %>%
  select(c(State, Year, "Hill-Burton Funds")) %>%
  filter(!(State %in% state_filter))

colnames(clean_hbpr) <- c('State', 'Year', 'hbfunds')



# ------ Q1. CREATING STATE*YEAR PANEL DATA FRAME  ------ ####

# PART 1  -  summing funds for columns with matching states and years (1947-1964)
merged_hbpr <- clean_hbpr %>%
  group_by(State, Year) %>%
  summarize(hbfunds = sum(hbfunds), .groups = 'drop')

merged_hbpr <- merged_hbpr %>%
  filter(Year >= 47) %>%
  filter(Year <= 64)


# PART 2  -  adding state year column with correct name formatting
merged_hbpr$stateyear <- c(paste(tolower(merged_hbpr$State), merged_hbpr$Year, sep="_19"))


# PART 3  -  calculate predicted funds using 9 steps provided
# creating extra columns in manipulated table for later years
clean_pcinc[ , '1963'] = 0
clean_pcinc[ , '1964'] = 0

# transforming data to longer format for easier data manipulation 
clean_pcinc <- clean_pcinc %>% 
  pivot_longer(starts_with('19'), names_to = "year", values_to = "percap_inc")

# (1) creating a data table of the smoothed 3 year average per capita income per state
# using rolling average with width of 3 years and a lag of 2 years
smooth_pcinc <- clean_pcinc %>%
  group_by(AreaName) %>%
  arrange(AreaName, year) %>%
  mutate(smoothed_pcinc = rollapply(percap_inc, width = 3, FUN = mean, align = "right", fill = NA)) %>%
  mutate(smoothed_pcinc = lag(smoothed_pcinc, 2)) %>%
  na.omit(smooth_pcinc) %>% #removes NA values now found in 1943-1946
  select(c(AreaName, year, smoothed_pcinc))

# (2) finding a national average of smoothed per capita income per year
yearly_national_avg_inc <- smooth_pcinc %>%
  group_by(year) %>%
  summarise(national_avg_inc = mean(smoothed_pcinc))
smooth_pcinc <- smooth_pcinc %>%
  left_join(yearly_national_avg_inc, by = c("year"))

# (3-4) calculating the index number and the allotment percentage based on added columns
smooth_pcinc <- smooth_pcinc %>%
  mutate(index_number = smoothed_pcinc/national_avg_inc) %>%
  mutate(allotment_percentage = 1 - (0.5*index_number))

# (5) Replace values below min (.33) or above max (.75)
smooth_pcinc$allotment_percentage[smooth_pcinc$allotment_percentage < .33] <- .33
smooth_pcinc$allotment_percentage[smooth_pcinc$allotment_percentage > .75] <- .75 

# (6) Calculate a 'weighted population for each state'
# lengthen population data 
clean_pop <- clean_pop %>%
  pivot_longer(starts_with('19'), names_to = "year", values_to = "population") 
smooth_pcinc <- smooth_pcinc %>%
  left_join(clean_pop, by = c("year", "AreaName")) %>% # add population data along side income data
  mutate(weighted_population = (allotment_percentage^2) * population)

# (7) Calculate a state allocation share for each state*year using weighted population
weighted_pop_sum <- smooth_pcinc %>%
  group_by(year) %>%
  summarise(yearly_weighted_pop_sum = sum(weighted_population))
smooth_pcinc <- smooth_pcinc %>%
  left_join(weighted_pop_sum, by = c("year")) %>%
  mutate(state_allocation_share = (weighted_population / yearly_weighted_pop_sum))
  
# (8) Predicted Hill-Burton allocation 
merged_hbpr$Year = paste0('19', merged_hbpr$Year) #normalizing column names
total_hbpr <- merged_hbpr %>%
  group_by(Year) %>%
  summarise(total_yearly_hbpr = sum(hbfunds)) #calculating yearly totals for hbpr funds
smooth_pcinc <- smooth_pcinc %>%
  left_join(total_hbpr, by = c("year" = 'Year')) %>% #adding in yearly distributed funds, matched by year
  mutate(predicted = (state_allocation_share * total_yearly_hbpr))

# (9) Replacing values less than the allocated minimums in given years with corresponding minimum values
smooth_pcinc$predicted[smooth_pcinc$year == "1948" & smooth_pcinc$predicted < 100000] <- 100000
smooth_pcinc$predicted[smooth_pcinc$year > "1948" & smooth_pcinc$predicted < 200000] <- 200000

# creating final data table
final_data <- merged_hbpr %>%
  left_join(smooth_pcinc, by = c("State" = "AreaName", "Year" = "year")) %>%
  select(c(stateyear, predicted, hbfunds)) %>%
  na.omit(final_data)

final_data$predicted <- format(final_data$predicted, scientific = FALSE)
write.csv(final_data, "FB_StateYear_Panel_Data_Set.csv")

# ------------  Q3. GRAPH AND TABLE FOR ASSESSING PREDICTOR RELEVANCE  -------- ####

# linear regression between hbfunds and predicted
hill_burton_model <- lm(hbfunds ~ predicted, data = final_data)
summary(hill_burton_model) # presents the table of coefficients/statistical data
  
# plots a scatter chart with x as hbfunds and y as predicted
ggplot(final_data, aes(predicted, hbfunds)) +
  geom_point() +
  geom_smooth(method = 'lm', se = TRUE) #includes regression line with standard error





