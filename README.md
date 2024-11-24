# Hill Burton Funding Data Task

_Freya Blackmore_

_October, 2024_

# Summary
This file includes a data task calculating the expected Hill-Burton Funding allocation to different states based on the designated federal formula for such funds. 

# Data
The imported data includes three data sets. 

``` pcinc.csv ```

This data set includes the Bureau of Economic Analysis per capita personal income data for 1943-1962.

``` pop.csv ```

This data set includes the Bureau of Economic Analysis population data for 1947-1964. 

``` hbpr.txt ```

This data set includes the US Department of Health, Education, and Welfare's published Hill-Burton Project
Register which lists projects funded under Hill Burton. The relevant variables included in this file are state, year, and hillburtonfunds. 


# Code Description
I began my code by uploading the given data sets (csv reader for .csv files and tsv reader for the .txt file) and cleaning the contained data. The basic cleaning of these data sets involved removing extraneous columns of information that would not be necessary for following calculations, as well as removing the deliberately excluded entities from the state sets (Alaska, Hawaii, DC, other territories). It was also necessary to convert all relevant data columns to integers, as several years had funds presented as characters, creating further problems for subsequent manipulation. Cleaned data tables were labeled as such (clean_) in order to preserve the original data sets. 

I began by working with the HBPR file, through which I was able to group instances by state and year and merge them together in order to find the sum total of funds for each state in each year (hbfunds). Next, any years outside of the period of interest (1947-1964) were filtered out. After the data had been merged and narrowed down, I created the stateyear column with the correct formatting (ex. alabama_1947) for later use. 

The bulk of my code involved performing the series of calculations necessary to find the predicted funds for each state in each year. The first step was to extend the clean_pcinc data to include columns for years 1963 and 1964, which were not contained within the original data but whose rolling averages were attainable due to the lag in the formula (1964 calculated via data from 1960, 1961, and 1962). Then, this data was transformed into a longer format in order to apply the rolling average equation and to add a column for the national average for each year. The result was a data table including four columns: AreaName, year, smoothed_pcinc, and national_avg_inc. This data table (smooth_pcinc) was ultimately used to perform the rest of the calculations. With this setup, it was straightforward to add new columns performing the relevant subsequent calculations, including index_number, allotment_percentage, population (from clean_pop), weighted_population, yearly_weighted_population, state_allocation_share, total_yearly_hbpr, and predicted. 

Finally, with all steps completed and the final predicted column, I added the previously found stateyear and hbfunds to a new table (final_data) alongside the predicted column. These tables were matched using the AreaName/State and year columns included in the merged_hbpr table and the smooth_pcinc table to ensure the correct data was matched from both sources. 
