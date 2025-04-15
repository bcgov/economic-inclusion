# Copyright 2025 Province of British Columbia
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and limitations under the License.


#### Data import/organization and cleaning and analysis of Stat Can 
#Census 2021 data for economic inclusion analysis. Accompanies technical report
# fot the ARDA 2025 release of statistics
## Version: V01
## Date:    April 10, 2025
## Coder:   Sarah Moore




################ LOAD LIBRARIES ----------------

library(magrittr)
library(openxlsx)
library(xlsx)
library(readxl)
library(dplyr)
library(tidyr)
library(foreign)
library(broom)
library(oaxaca)
library(tidyverse)
library(ggthemes)
library(ggpubr)
library(berryFunctions)


########### LOAD PUMF AND FILTER SAMPLE ----------------
load(file= "Census_pumf.RData")

## not all of these are used below, but were at least considered when filtering and cleaning to the final sample
index_vars <- which(names(census)%in%c("PPSORT","AGEGRP", "Gender","ETHDER","FOL","HLMOSTEN","DPGRSUM",
                                       "VISMIN","DPGRSUM", "KOL","AGEIMM","Citizen","GENSTAT","POB","YRIM", "HDGREE","LOC_ST_RES",
                                       "Wages","EmpIn", "PR","NOC21","FPTWK","LFACT","WKSWRK","WRKACT","COW", "JOBPERM", "NAICS", "ABOID"))
## add to index variables all of the weights, 128:144
index_vars2 <- c(index_vars, 128:144)
census_BC <- census[,index_vars2]
census_BC <- census_BC[census_BC$PR=="British Columbia",]


table(census_BC_workers$DPGRSUM)
table(census_BC$ABOID)

# check the variables are there
names(census_BC)

# remove large object and unneeded 
rm(census)
rm(index_vars, index_vars2)

nrow(census_BC) # [1] 132733
## filter based on labour force participation/inclusion in a NOC21:
census_BC_workers <- census_BC[census_BC$WRKACT=="Worked 49 to 52 weeks full time",]
nrow(census_BC_workers) # [1] 36725
# remove large obejct
rm(census_BC)

## take out the too young and too old
table(census_BC_workers$AGEGRP)  # remove "not available"
census_BC_workers <- census_BC_workers[-which(census_BC_workers$AGEGRP=="Not available"),]
census_BC_workers$AGEGRP_binary <- ifelse(census_BC_workers$AGEGRP=="15 to 17 years" | 
                                            census_BC_workers$AGEGRP=="18 to 19 years" |
                                            census_BC_workers$AGEGRP=="20 to 24 years", "young", 
                                          ifelse(census_BC_workers$AGEGRP=="25 to 29 years" |
                                                   census_BC_workers$AGEGRP=="25 to 29 years" |
                                                   census_BC_workers$AGEGRP=="30 to 34 years" |
                                                   census_BC_workers$AGEGRP=="35 to 39 years" |
                                                   census_BC_workers$AGEGRP=="40 to 44 years" |
                                                   census_BC_workers$AGEGRP=="45 to 49 years" |
                                                   census_BC_workers$AGEGRP=="50 to 54 years" |
                                                   census_BC_workers$AGEGRP=="55 to 59 years" |
                                                   census_BC_workers$AGEGRP=="60 to 64 years", "old", "outside"))

dim(census_BC_workers[-which(census_BC_workers$AGEGRP_binary=="outside"),])
census_BC_workers <- census_BC_workers[-which(census_BC_workers$AGEGRP_binary=="outside"),]
nrow(census_BC_workers) # [1] 34924

## remove workers with indigenous idenity
census_BC_workers <- census_BC_workers[-which(census_BC_workers$DPGRSUM=="Indigenous peoples"),]
nrow(census_BC_workers) # 33384




## racialized/nonracialized variable
levels(census_BC_workers$VISMIN)[levels(census_BC_workers$VISMIN)=='Not available'] <- NA
dim(census_BC_workers[-which(is.na(census_BC_workers$VISMIN)),]) # [1] 32185
census_BC_workers <- census_BC_workers[-which(is.na(census_BC_workers$VISMIN)),]

table(census_BC_workers$COW)

census_BC_workers <- census_BC_workers[which(census_BC_workers$COW=="Employee"),]
nrow(census_BC_workers) # [1] 27989

## want people with NOC21
census_BC_workers <- census_BC_workers[-which(census_BC_workers$NOC21=="Not available"),]
nrow(census_BC_workers) #[1] 27629

# change missing code for income variables
census_BC_workers$EmpIn <- ifelse(census_BC_workers$EmpIn==88888888, NA, census_BC_workers$EmpIn)
census_BC_workers$EmpIn <- ifelse(census_BC_workers$EmpIn==99999999, NA, census_BC_workers$EmpIn)
census_BC_workers$Wages <- ifelse(census_BC_workers$Wages==88888888, NA, census_BC_workers$Wages)
census_BC_workers$Wages <- ifelse(census_BC_workers$Wages==99999999, NA, census_BC_workers$Wages)


## also limits people who are too young if we didn't do that above (admin data only 15 and up)
nrow(census_BC_workers[-which(is.na(census_BC_workers$EmpIn)),]) 
nrow(census_BC_workers[-which(is.na(census_BC_workers$Wages)),]) 

census_BC_workers <- census_BC_workers[-which(is.na(census_BC_workers$Wages)),]
nrow(census_BC_workers) # 26865


# remove those who earned nothing
workers1 <- census_BC_workers[-which(census_BC_workers$Wages< 2),]
nrow(workers1) # [1] 26831


# stricter removal, anyone earning less than expected based on minimum wage, full year, fulltime work in 2020
workers2 <- census_BC_workers[-which(census_BC_workers$Wages< 27000),]
nrow(workers2) # [1]  25134


hist(workers1[workers1$Wages<200000,]$Wages)
hist(workers2[workers2$Wages<200000,]$Wages)
save(census_BC_workers, file="BC_workers_before_low_wage_cuts.RData")

## we used the cut off 27k cut off to ensure workers were more likely to be full time as reported
census_BC_workers <- workers2  
rm(workers1)
rm(workers2)


############# RECODING VARIABLES -------------------


table(census_BC_workers$VISMIN)
census_BC_workers$VISMIN_binary <- ifelse(census_BC_workers$VISMIN=="Not a visible minority", "White", "Racialized")
table(census_BC_workers$VISMIN_binary)


table(census_BC_workers$HDGREE)
table(census_BC_workers$LOC_ST_RES)  # a simplified education variable, we simplify it further


census_BC_workers$Degree_origin <- recode(census_BC_workers$LOC_ST_RES, 
                                          'Same as province or territory of residence' = "Canadian Degree", 
                                          'Different than province or territory of residence' = "Canadian Degree")
# highest postsecondary certificate, diploma or degree
table(census_BC_workers$Degree_origin)

census_BC_workers$HDGREE_numeric <- ifelse(census_BC_workers$HDGREE=="Not available", NA, census_BC_workers$HDGREE)
str(census_BC_workers$HDGREE_numeric) #integer
table(census_BC_workers$HDGREE_numeric)
table(census_BC_workers$HDGREE)
census_BC_workers$HDGREE_binary <- ifelse(census_BC_workers$HDGREE=="Not available", NA, ifelse(
  census_BC_workers$HDGREE=="Bachelor's degree" | census_BC_workers$HDGREE=="University certificate or diploma above bachelor level" |
    census_BC_workers$HDGREE=="Degree in medicine, dentistry, veterinary medicine or optometry" | 
    census_BC_workers$HDGREE=="Master's degree" | census_BC_workers$HDGREE=="Earned doctorate", "PostSecondary", "NonPostSecondary"
))


census_BC_workers$HDGREE_cats <- census_BC_workers$HDGREE_numeric
census_BC_workers$HDGREE_cats <- ifelse(census_BC_workers$HDGREE_cats < 3, "No training/certificate", 
                                        ifelse(census_BC_workers$HDGREE_cats > 2 & 
                                                 census_BC_workers$HDGREE_cats < 9, 
                                               "Training program", "BA+"))


table(census_BC_workers$AGEIMM)  ## follow up variable to explore (excludes too much sample)



table(census_BC_workers$GENSTAT)  ## more details on generation, in or out (put this in methods)
table(census_BC_workers$GENSTAT)
census_BC_workers$GENSTAT2 <- ifelse(census_BC_workers$GENSTAT=="Not available", NA, 
                                     ifelse(census_BC_workers$GENSTAT=="Second generation, respondent born in Canada, both parents born outside Canada" |
                                              census_BC_workers$GENSTAT=="Second generation, respondent born in Canada, one parent born outside Canada and one parent born in Canada",
                                            "SECOND", ifelse (census_BC_workers$GENSTAT=="First generation, respondent born outside Canada", "FIRST",
                                                              "THIRD")))
table(census_BC_workers$GENSTAT2)

## one more recoding for first and then second and beyond
census_BC_workers$GENSTAT3 <- recode(census_BC_workers$GENSTAT2, "SECOND" = "SECOND AND LATER",
                                     "THIRD" = "SECOND AND LATER")

table(census_BC_workers$GENSTAT3)


## some notes on variables that were looked at
#COW Labour: Class of worker (derived); this could come into play later (unpaid family worker)
# FPTWK Labour: Full-time or part-time weeks worked in 2020
#JOBPERM Labour: Job permanency
#LFACT Labour: Labour force status - Detailed
#LSTWRK Labour: When last worked for pay or in self-employment
#NAICS Labour: Industry sectors (based on the North American Industry
#WKSWRK Labour: Weeks worked during the reference year


##### condensing age categories for plotting
table(census_BC_workers$AGEGRP) 
census_BC_workers$AGEGRP2 <- recode(census_BC_workers$AGEGRP, "15 to 17 years" = "under 20", 
                                    "18 to 19 years" = "under 20") 
table(census_BC_workers$AGEGRP2)


census_BC_workers$AGEGRP3 <- recode(census_BC_workers$AGEGRP2, "under 20" = "under 25", 
                                    "20 to 24 years" = "under 25",
                                    "55 to 59 years" ="55+", "60 to 64 years" = "55+") 
table(census_BC_workers$AGEGRP3)

census_BC_workers$AGEGRP_3bins <- ifelse(census_BC_workers$AGEGRP=="15 to 17 years" | 
                                           census_BC_workers$AGEGRP=="18 to 19 years" |
                                           census_BC_workers$AGEGRP=="20 to 24 years" |
                                           census_BC_workers$AGEGRP=="25 to 29 years", "age under 30", 
                                         ifelse(census_BC_workers$AGEGRP=="30 to 34 years" |
                                                  census_BC_workers$AGEGRP=="35 to 39 years" |
                                                  census_BC_workers$AGEGRP=="40 to 44 years" |
                                                  census_BC_workers$AGEGRP=="45 to 49 years",
                                                "age 30-49", "age 50 and over"))

# recoding age as ordinal variable
census_BC_workers$AGEGRP.o <- recode(census_BC_workers$AGEGRP, "15 to 17 years" = 1, "18 to 19 years" = 2,    
                                     "20 to 24 years" = 3,  "25 to 29 years" = 4,    "30 to 34 years" = 5, 
                                     "35 to 39 years" = 6,    "40 to 44 years"=7,    "45 to 49 years"=8,
                                     "50 to 54 years" = 9,    "55 to 59 years"=10, "60 to 64 years"=11) 

table(census_BC_workers$AGEGRP.o)


## also calculate years in Canada since immigration using age variable and ageimm
census_BC_workers$AGE.avg <- recode(census_BC_workers$AGEGRP, "15 to 17 years" = 16, "18 to 19 years" = 18.5,    
                                    "20 to 24 years" = 22,  "25 to 29 years" = 27,    "30 to 34 years" = 32, 
                                    "35 to 39 years" = 37,    "40 to 44 years"=42,    "45 to 49 years"=47,
                                    "50 to 54 years" = 52,    "55 to 59 years"=57, "60 to 64 years"=62) 


census_BC_workers$AGEIMMAGE.avg <- recode(census_BC_workers$AGEIMM, "0 to 4 years"=2,
                                          "5 to 9 years" = 7, "10 to 14 years" = 12,     "15 to 19 years" = 17,     
                                          "20 to 24 years" = 22,  "25 to 29 years" = 27,    "30 to 34 years" = 32, 
                                          "35 to 39 years" = 37,    "40 to 44 years"=42,    "45 to 49 years"=47,
                                          "50 to 54 years" = 52,    "55 to 59 years"=57, "60 years and over"=62) 

table(census_BC_workers$AGEIMMAGE.avg)
census_BC_workers$YRSCA <- census_BC_workers$AGE.avg - census_BC_workers$AGEIMMAGE.avg 
table(census_BC_workers$YRSCA)

census_BC_workers$YRSCA.c <- cut(census_BC_workers$YRSCA, breaks = c(0,5,20,60), 
                                 labels=c('5 or less', '>5 and <20', '>20'))
table(census_BC_workers$YRSCA.c)

#### language
census_BC_workers$FOL2 <- recode(census_BC_workers$FOL, "English and French" ="English", "French"="Not English", 
                                 "Neither English nor French" = "Not English")
table(census_BC_workers$FOL2)


table(census_BC_workers$HLMOSTEN)  # using this variable, mark not available as missing
levels(census_BC_workers$HLMOSTEN)[levels(census_BC_workers$HLMOSTEN)=='Not available'] <- NA
levels(census_BC_workers$HLMOSTEN) <- c("Not English", "English")
table(census_BC_workers$HLMOSTEN) # good to go





### FOR LATER CHECK OF MODEL ROBUSTNESS WITH high earners winzorized 

census_BC_workers$Wages.winzor <- scale(census_BC_workers$Wages)
hist(ifelse(census_BC_workers$Wages.winzor>3, 3, census_BC_workers$Wages.winzor))
census_BC_workers$Wages.winzor <- ifelse(census_BC_workers$Wages.winzor>3, 3, 
                                         census_BC_workers$Wages.winzor)
hist(census_BC_workers$Wages.winzor)




### coding dummy variables to use in the oaxaca decomposition models:
census_BC_workers$NONFIRST <-ifelse(census_BC_workers$GENSTAT2 == "SECOND" | census_BC_workers$GENSTAT2 == "THIRD", 1, 0)
census_BC_workers$CA_degree <-ifelse(census_BC_workers$Degree_origin == "Canadian Degree", 1, 0)
census_BC_workers$NonCA_degree <-ifelse(census_BC_workers$Degree_origin == "Outside Canada", 1, 0)



census_BC_workers$Female <- ifelse(census_BC_workers$Gender == "Woman+", 1, 0)
census_BC_workers$SECOND_GEN <-ifelse(census_BC_workers$GENSTAT2 == "SECOND", 1, 0)
census_BC_workers$THIRD_GEN <-ifelse(census_BC_workers$GENSTAT2 == "THIRD", 1, 0)
census_BC_workers$RACIALIZED <-ifelse(census_BC_workers$VISMIN_binary == "Racialized", 1, 0)
census_BC_workers$HDGREE_numeric <- as.numeric(census_BC_workers$HDGREE_numeric)
census_BC_workers$HDGREE_s <- scale(census_BC_workers$HDGREE_numeric, center = TRUE, scale = TRUE)
table(census_BC_workers$AGEGRP)  ## baseline group is 15 to 17 year olds 
census_BC_workers$AGE_18_19 <-ifelse(census_BC_workers$AGEGRP == "18 to 19 years", 1, 0)
census_BC_workers$AGE_20_24 <-ifelse(census_BC_workers$AGEGRP == "20 to 24 years", 1, 0)
census_BC_workers$AGE_25_29 <-ifelse(census_BC_workers$AGEGRP == "25 to 29 years", 1, 0)
census_BC_workers$AGE_30_34 <-ifelse(census_BC_workers$AGEGRP == "30 to 34 years", 1, 0)
census_BC_workers$AGE_35_39 <-ifelse(census_BC_workers$AGEGRP == "35 to 39 years", 1, 0)
census_BC_workers$AGE_40_44 <-ifelse(census_BC_workers$AGEGRP == "40 to 44 years", 1, 0)
census_BC_workers$AGE_45_49 <-ifelse(census_BC_workers$AGEGRP == "45 to 49 years", 1, 0)
census_BC_workers$AGE_50_54 <-ifelse(census_BC_workers$AGEGRP == "50 to 54 years", 1, 0)
census_BC_workers$AGE_55_59 <-ifelse(census_BC_workers$AGEGRP == "55 to 59 years", 1, 0)
census_BC_workers$AGE_60_64 <-ifelse(census_BC_workers$AGEGRP == "60 to 64 years", 1, 0)




######## save the dataset for BC data catalogue
names(census_BC_workers)
cat_data <- census_BC_workers[,which(names(census_BC_workers)%in%c("PPSORT","AGE.avg", "Female", "NONFIRST", "HDGREE_s", 
"RACIALIZED", "Wages", "VISMIN_binary", "AGEGRP2", "Gender", "GENSTAT3", 
"WEIGHT", "HDGREE_numeric", "LOC_ST_RES"))]
write.csv(cat_data, file="economic_inclusion_data.csv")
rm(cat_data)

#### SAMPLE SUMMARY STATISTICS ################

data_split <- split(census_BC_workers,census_BC_workers$NOC21)
length(data_split)

# code below fixes our big list so it does not have empty elements...begins as 28 long
# for some reason have to do 27 2x
data_split[[27]] <- NULL
data_split[[28]] <- NULL
data_split[[27]] <- NULL



## means by occupation included in the appendix

make_df_age_barplot <- function(occupation){
  new_df <- data_split[[occupation]]
  new_df <- new_df[,which(names(new_df)%in%c("Wages","VISMIN_binary","AGEGRP3","WEIGHT"))]
  new_df <- new_df[which(complete.cases(new_df)),]
  new_df.r <- new_df[new_df$VISMIN_binary=="Racialized",]
  new_df.w <- new_df[new_df$VISMIN_binary=="White",]
  new_df.r.1 <- new_df.r[new_df.r$AGEGRP3=="under 25",]
  new_df.w.1 <- new_df.w[new_df.w$AGEGRP3=="under 25",]
  new_df.r.2 <- new_df.r[new_df.r$AGEGRP3=="25 to 29 years",]
  new_df.w.2 <- new_df.w[new_df.w$AGEGRP3=="25 to 29 years",]
  new_df.r.3 <- new_df.r[new_df.r$AGEGRP3=="30 to 34 years",]
  new_df.w.3 <- new_df.w[new_df.w$AGEGRP3=="30 to 34 years",]
  new_df.r.4 <- new_df.r[new_df.r$AGEGRP3=="35 to 39 years",]
  new_df.w.4 <- new_df.w[new_df.w$AGEGRP3=="35 to 39 years",]
  new_df.r.5 <- new_df.r[new_df.r$AGEGRP3=="40 to 44 years",]
  new_df.w.5 <- new_df.w[new_df.w$AGEGRP3=="40 to 44 years",]
  new_df.r.6 <- new_df.r[new_df.r$AGEGRP3=="45 to 49 years",]
  new_df.w.6 <- new_df.w[new_df.w$AGEGRP3=="45 to 49 years",]
  new_df.r.7 <- new_df.r[new_df.r$AGEGRP3=="50 to 54 years",]
  new_df.w.7 <- new_df.w[new_df.w$AGEGRP3=="50 to 54 years",]
  new_df.r.8 <- new_df.r[new_df.r$AGEGRP3=="55+",]
  new_df.w.8 <- new_df.w[new_df.w$AGEGRP3=="55+",]
  prop.w <- c(sum(new_df.w.1$WEIGHT)/sum(new_df.w$WEIGHT),
              sum(new_df.w.2$WEIGHT)/sum(new_df.w$WEIGHT),
              sum(new_df.w.3$WEIGHT)/sum(new_df.w$WEIGHT),
              sum(new_df.w.4$WEIGHT)/sum(new_df.w$WEIGHT),
              sum(new_df.w.5$WEIGHT)/sum(new_df.w$WEIGHT),
              sum(new_df.w.6$WEIGHT)/sum(new_df.w$WEIGHT),
              sum(new_df.w.7$WEIGHT)/sum(new_df.w$WEIGHT),
              sum(new_df.w.8$WEIGHT)/sum(new_df.w$WEIGHT))
  mean.w <- c(sum(new_df.w.1$Wages*new_df.w.1$WEIGHT)/sum(new_df.w.1$WEIGHT),
              sum(new_df.w.2$Wages*new_df.w.2$WEIGHT)/sum(new_df.w.2$WEIGHT),
              sum(new_df.w.3$Wages*new_df.w.3$WEIGHT)/sum(new_df.w.3$WEIGHT),
              sum(new_df.w.4$Wages*new_df.w.4$WEIGHT)/sum(new_df.w.4$WEIGHT),
              sum(new_df.w.5$Wages*new_df.w.5$WEIGHT)/sum(new_df.w.5$WEIGHT),
              sum(new_df.w.6$Wages*new_df.w.6$WEIGHT)/sum(new_df.w.6$WEIGHT),
              sum(new_df.w.7$Wages*new_df.w.7$WEIGHT)/sum(new_df.w.7$WEIGHT),
              sum(new_df.w.8$Wages*new_df.w.8$WEIGHT)/sum(new_df.w.8$WEIGHT))
  se.w = c(sd(new_df.w.1$Wages)/sqrt(nrow(new_df.w.1)),
           sd(new_df.w.2$Wages)/sqrt(nrow(new_df.w.2)),
           sd(new_df.w.3$Wages)/sqrt(nrow(new_df.w.3)),
           sd(new_df.w.4$Wages)/sqrt(nrow(new_df.w.4)),
           sd(new_df.w.5$Wages)/sqrt(nrow(new_df.w.5)),
           sd(new_df.w.6$Wages)/sqrt(nrow(new_df.w.6)),
           sd(new_df.w.7$Wages)/sqrt(nrow(new_df.w.7)),
           sd(new_df.w.8$Wages)/sqrt(nrow(new_df.w.8)) 
  )
  CI_lower.w = mean.w - 1.96*se.w
  CI_upper.w = mean.w + 1.96*se.w
  ns.w = c(nrow(new_df.w.1),
           nrow(new_df.w.2),
           nrow(new_df.w.3), 
           nrow(new_df.w.4),
           nrow(new_df.w.5),
           nrow(new_df.w.6),
           nrow(new_df.w.7),
           nrow(new_df.w.8))
  
  df.w <- data.frame(GROUP = rep("Nonracialized", 8),  AGE = c("under25", "25 to 29 years",
                                                               "30 to 34 years","35 to 39 years",
                                                               "40 to 44 years","45 to 49 years",
                                                               "50 to 54 years","55+"), 
                     MEAN_WEIGHTED = mean.w, lower = CI_lower.w, upper=CI_upper.w, SIZE = ns.w, PROP_WEIGHTED=prop.w)
  
  
  prop.r <- c(sum(new_df.r.1$WEIGHT)/sum(new_df.r$WEIGHT),
              sum(new_df.r.2$WEIGHT)/sum(new_df.r$WEIGHT),
              sum(new_df.r.3$WEIGHT)/sum(new_df.r$WEIGHT),
              sum(new_df.r.4$WEIGHT)/sum(new_df.r$WEIGHT),
              sum(new_df.r.5$WEIGHT)/sum(new_df.r$WEIGHT),
              sum(new_df.r.6$WEIGHT)/sum(new_df.r$WEIGHT),
              sum(new_df.r.7$WEIGHT)/sum(new_df.r$WEIGHT),
              sum(new_df.r.8$WEIGHT)/sum(new_df.r$WEIGHT))
  mean.r <- c(sum(new_df.r.1$Wages*new_df.r.1$WEIGHT)/sum(new_df.r.1$WEIGHT),
              sum(new_df.r.2$Wages*new_df.r.2$WEIGHT)/sum(new_df.r.2$WEIGHT),
              sum(new_df.r.3$Wages*new_df.r.3$WEIGHT)/sum(new_df.r.3$WEIGHT),
              sum(new_df.r.4$Wages*new_df.r.4$WEIGHT)/sum(new_df.r.4$WEIGHT),
              sum(new_df.r.5$Wages*new_df.r.5$WEIGHT)/sum(new_df.r.5$WEIGHT),
              sum(new_df.r.6$Wages*new_df.r.6$WEIGHT)/sum(new_df.r.6$WEIGHT),
              sum(new_df.r.7$Wages*new_df.r.7$WEIGHT)/sum(new_df.r.7$WEIGHT),
              sum(new_df.r.8$Wages*new_df.r.8$WEIGHT)/sum(new_df.r.8$WEIGHT))
  se.r = c(sd(new_df.r.1$Wages)/sqrt(nrow(new_df.r.1)),
           sd(new_df.r.2$Wages)/sqrt(nrow(new_df.r.2)),
           sd(new_df.r.3$Wages)/sqrt(nrow(new_df.r.3)),
           sd(new_df.r.4$Wages)/sqrt(nrow(new_df.r.4)),
           sd(new_df.r.5$Wages)/sqrt(nrow(new_df.r.5)),
           sd(new_df.r.6$Wages)/sqrt(nrow(new_df.r.6)),
           sd(new_df.r.7$Wages)/sqrt(nrow(new_df.r.7)),
           sd(new_df.r.8$Wages)/sqrt(nrow(new_df.r.8)) 
  )
  CI_lower.r = mean.r - 1.96*se.r
  CI_upper.r = mean.r + 1.96*se.r
  ns.r = c(nrow(new_df.r.1),
           nrow(new_df.r.2),
           nrow(new_df.r.3), 
           nrow(new_df.r.4),
           nrow(new_df.r.5),
           nrow(new_df.r.6),
           nrow(new_df.r.7),
           nrow(new_df.r.8))
  
  df.r <- data.frame(GROUP = rep("Racialized", 8), AGE = c("under25", "25 to 29 years", 
                                                           "30 to 34 years","35 to 39 years",
                                                           "40 to 44 years","45 to 49 years",
                                                           "50 to 54 years","55+"), 
                     MEAN_WEIGHTED = mean.r, lower = CI_lower.r, upper=CI_upper.r, SIZE = ns.r, PROP_WEIGHTED=prop.r
  )
  
  df_for_barplot <- rbind(df.r, df.w)
  df_for_barplot}

all_age_means <- lapply(1:26, function(x) {
  make_df_age_barplot(x)
})
age_means <- as.data.frame(do.call(rbind, all_age_means))


make_df_gen2_barplot <- function(occupation){
  new_df <- data_split[[occupation]]
  new_df <- new_df[,which(names(new_df)%in%c("Wages","VISMIN_binary","GENSTAT3","WEIGHT"))]
  new_df <- new_df[which(complete.cases(new_df)),]
  new_df.r <- new_df[new_df$VISMIN_binary=="Racialized",]
  new_df.w <- new_df[new_df$VISMIN_binary=="White",]
  new_df.r.first <- new_df.r[new_df.r$GENSTAT3=="FIRST",]
  new_df.r.second <- new_df.r[new_df.r$GENSTAT3=="SECOND AND LATER",]
  new_df.w.first <- new_df.w[new_df.w$GENSTAT3=="FIRST",]
  new_df.w.second <- new_df.w[new_df.w$GENSTAT3=="SECOND AND LATER",]
  prop.w <- c(sum(new_df.w.first$WEIGHT)/sum(new_df.w$WEIGHT),
              sum(new_df.w.second$WEIGHT)/sum(new_df.w$WEIGHT))
  mean.w <- c(sum(new_df.w.first$Wages*new_df.w.first$WEIGHT)/sum(new_df.w.first$WEIGHT),
              sum(new_df.w.second$Wages*new_df.w.second$WEIGHT)/sum(new_df.w.second$WEIGHT))
  se.w = c(sd(new_df.w[new_df.w$GENSTAT3=="FIRST",]$Wages)/sqrt(nrow(new_df.w[new_df.w$GENSTAT3=="FIRST",])),
           sd(new_df.w[new_df.w$GENSTAT3=="SECOND AND LATER",]$Wages)/sqrt(nrow(new_df.w[new_df.w$GENSTAT3=="SECOND AND LATER",]
           )))
  CI_lower.w = mean.w - 1.96*se.w
  CI_upper.w = mean.w + 1.96*se.w
  
  ns.w = c(nrow(new_df.w[new_df.w$GENSTAT3=="FIRST",]),
           nrow(new_df.w[new_df.w$GENSTAT3=="SECOND AND LATER",]))
  
  df.w <- data.frame(GROUP = rep("Nonracialized", 2), GEN = c("First", "SECOND AND LATER"), 
                     MEAN_WEIGHTED = mean.w, lower = CI_lower.w, upper = CI_upper.w, SIZE = ns.w, PROP_WEIGHTED = prop.w)
  prop.r <- c(sum(new_df.r.first$WEIGHT)/sum(new_df.r$WEIGHT),
              sum(new_df.r.second$WEIGHT)/sum(new_df.r$WEIGHT))
  mean.r <- c(sum(new_df.r.first$Wages*new_df.r.first$WEIGHT)/sum(new_df.r.first$WEIGHT),
              sum(new_df.r.second$Wages*new_df.r.second$WEIGHT)/sum(new_df.r.second$WEIGHT))
  
  se.r = c(sd(new_df.r[new_df.r$GENSTAT3=="FIRST",]$Wages)/sqrt(nrow(new_df.r[new_df.r$GENSTAT3=="FIRST",])),
           sd(new_df.r[new_df.r$GENSTAT3=="SECOND AND LATER",]$Wages)/sqrt(nrow(new_df.r[new_df.r$GENSTAT3=="SECOND AND LATER",]
           )))
  CI_lower.r = mean.r - 1.96*se.r
  CI_upper.r = mean.r + 1.96*se.r
  ns.r = c(nrow(new_df.r[new_df.r$GENSTAT3=="FIRST",]),
           nrow(new_df.r[new_df.r$GENSTAT3=="SECOND AND LATER",]))
  
  
  df.r <- data.frame(GROUP = rep("Racialized", 2), GEN = c("First", "SECOND AND LATER"), 
                     MEAN_WEIGHTED = mean.r, lower = CI_lower.r, upper = CI_upper.r, SIZE = ns.r, PROP_WEIGHTED = prop.r)
  
  df_for_barplot <- rbind(df.r, df.w)
  df_for_barplot}

all_generation_means <- lapply(1:26, function(x) {
  make_df_gen2_barplot(x)
})
generation_means2 <- as.data.frame(do.call(rbind, all_generation_means))


make_df_edu_barplot <- function(occupation){
  new_df <- data_split[[occupation]]
  new_df <- new_df[,which(names(new_df)%in%c("Wages","VISMIN_binary","Degree_origin","WEIGHT"))]
  new_df <- new_df[which(complete.cases(new_df)),]
  new_df.r <- new_df[new_df$VISMIN_binary=="Racialized",]
  new_df.w <- new_df[new_df$VISMIN_binary=="White",]
  new_df.w.CA <- new_df.w[new_df.w$Degree_origin=="Canadian Degree",]
  new_df.w.OUT <- new_df.w[new_df.w$Degree_origin=="Outside Canada",]
  new_df.w.NONE <- new_df.w[new_df.w$Degree_origin=="No postsecondary certificate, diploma or degree",]
  
  new_df.r.CA <- new_df.r[new_df.r$Degree_origin=="Canadian Degree",]
  new_df.r.OUT <- new_df.r[new_df.r$Degree_origin=="Outside Canada",]
  new_df.r.NONE <- new_df.r[new_df.r$Degree_origin=="No postsecondary certificate, diploma or degree",]
  
  prop.w <- c(sum(new_df.w.CA$WEIGHT)/sum(new_df.w$WEIGHT),
              sum(new_df.w.OUT$WEIGHT)/sum(new_df.w$WEIGHT),
              sum(new_df.w.NONE$WEIGHT)/sum(new_df.w$WEIGHT))
  mean.w <- c(sum(new_df.w.CA$Wages*new_df.w.CA$WEIGHT)/sum(new_df.w.CA$WEIGHT),
              sum(new_df.w.OUT$Wages*new_df.w.OUT$WEIGHT)/sum(new_df.w.OUT$WEIGHT),
              sum(new_df.w.NONE$Wages*new_df.w.NONE$WEIGHT)/sum(new_df.w.NONE$WEIGHT))
  
  se.w = c(sd(new_df.w[new_df.w$Degree_origin=="Canadian Degree",]$Wages)/sqrt(nrow(new_df.w[new_df.w$Degree_origin=="Canadian Degree",])),
           sd(new_df.w[new_df.w$Degree_origin=="Outside Canada",]$Wages)/sqrt(nrow(new_df.w[new_df.w$Degree_origin=="Outside Canada",])),
           sd(new_df.w[new_df.w$Degree_origin=="No postsecondary certificate, diploma or degree",]$Wages)/sqrt(nrow(new_df.w[new_df.w$Degree_origin=="No postsecondary certificate, diploma or degree",])))
  CI_lower.w = mean.w - 1.96*se.w
  CI_upper.w = mean.w + 1.96*se.w
  
  ns.w = c(nrow(new_df.w[new_df.w$Degree_origin=="Canadian Degree",]),
           nrow(new_df.w[new_df.w$Degree_origin=="Outside Canada",]),
           nrow(new_df.w[new_df.w$Degree_origin=="No postsecondary certificate, diploma or degree",]))
  
  
  df.w <- data.frame(GROUP = rep("Nonracialized", 3), EDU = c("Canadian", "NonCanadian", "None"), 
                     MEAN_WEIGHTED = mean.w, lower=CI_lower.w, upper = CI_upper.w, SIZE = ns.w, 
                     PROP_WEIGHTED = prop.w)
  prop.r <- c(sum(new_df.r.CA$WEIGHT)/sum(new_df.r$WEIGHT),
              sum(new_df.r.OUT$WEIGHT)/sum(new_df.r$WEIGHT),
              sum(new_df.r.NONE$WEIGHT)/sum(new_df.r$WEIGHT))
  mean.r <- c(sum(new_df.r.CA$Wages*new_df.r.CA$WEIGHT)/sum(new_df.r.CA$WEIGHT),
              sum(new_df.r.OUT$Wages*new_df.r.OUT$WEIGHT)/sum(new_df.r.OUT$WEIGHT),
              sum(new_df.r.NONE$Wages*new_df.r.NONE$WEIGHT)/sum(new_df.r.NONE$WEIGHT))
  se.r = c(sd(new_df.r[new_df.r$Degree_origin=="Canadian Degree",]$Wages)/sqrt(nrow(new_df.r[new_df.r$Degree_origin=="Canadian Degree",])),
           sd(new_df.r[new_df.r$Degree_origin=="Outside Canada",]$Wages)/sqrt(nrow(new_df.r[new_df.r$Degree_origin=="Outside Canada",])),
           sd(new_df.r[new_df.r$Degree_origin=="No postsecondary certificate, diploma or degree",]$Wages)/sqrt(nrow(new_df.r[new_df.r$Degree_origin=="No postsecondary certificate, diploma or degree",])))
  CI_lower.r = mean.r - 1.96*se.r
  CI_upper.r = mean.r + 1.96*se.r
  ns.r = c(nrow(new_df.r[new_df.r$Degree_origin=="Canadian Degree",]),
           nrow(new_df.r[new_df.r$Degree_origin=="Outside Canada",]),
           nrow(new_df.r[new_df.r$Degree_origin=="No postsecondary certificate, diploma or degree",]))
  
  
  
  df.r <- data.frame(GROUP = rep("Racialized", 3), EDU = c("Canadian", "NonCanadian", "None"), 
                     MEAN_WEIGHTED = mean.r, lower=CI_lower.r, upper = CI_upper.r,SIZE = ns.r, PROP_WEIGHTED = prop.r)
  
  df_for_barplot <- rbind(df.r, df.w)
  df_for_barplot}

all_edu_means <- lapply(1:26, function(x) {
  make_df_edu_barplot(x)
})
education_means <- as.data.frame(do.call(rbind, all_edu_means))

make_df_edu_cats_barplot <- function(occupation){
  new_df <- data_split[[occupation]]
  new_df <- new_df[,which(names(new_df)%in%c("Wages","VISMIN_binary","HDGREE_cats","WEIGHT"))]
  new_df <- new_df[which(complete.cases(new_df)),]
  new_df.r <- new_df[new_df$VISMIN_binary=="Racialized",]
  new_df.w <- new_df[new_df$VISMIN_binary=="White",]
  new_df.r.1 <- new_df.r[new_df.r$HDGREE_cats=="No training/certificate",]
  new_df.w.1 <- new_df.w[new_df.w$HDGREE_cats=="No training/certificate",]
  new_df.r.2 <- new_df.r[new_df.r$HDGREE_cats=="Training program",]
  new_df.w.2 <- new_df.w[new_df.w$HDGREE_cats=="Training program",]
  new_df.r.3 <- new_df.r[new_df.r$HDGREE_cats=="BA+",]
  new_df.w.3 <- new_df.w[new_df.w$HDGREE_cats=="BA+",]
  
  
  prop.w <- c(sum(new_df.w.1$WEIGHT)/sum(new_df.w$WEIGHT),
              sum(new_df.w.2$WEIGHT)/sum(new_df.w$WEIGHT),
              sum(new_df.w.3$WEIGHT)/sum(new_df.w$WEIGHT))
  
  mean.w <- c(sum(new_df.w.1$Wages*new_df.w.1$WEIGHT)/sum(new_df.w.1$WEIGHT),
              sum(new_df.w.2$Wages*new_df.w.2$WEIGHT)/sum(new_df.w.2$WEIGHT),
              sum(new_df.w.3$Wages*new_df.w.3$WEIGHT)/sum(new_df.w.3$WEIGHT))
  
  se.w = c(sd(new_df.w.1$Wages)/sqrt(nrow(new_df.w.1)),
           sd(new_df.w.2$Wages)/sqrt(nrow(new_df.w.2)),
           sd(new_df.w.3$Wages)/sqrt(nrow(new_df.w.3)))
  CI_lower.w = mean.w - 1.96*se.w
  CI_upper.w = mean.w + 1.96*se.w
  ns.w = c(nrow(new_df.w.1),nrow(new_df.w.2),nrow(new_df.w.3))
  
  
  df.w <- data.frame(GROUP = rep("Nonracialized", 3), EDU = c("No training/certificate", 
                                                              "Training program",
                                                              "BA+"), 
                     MEAN_WEIGHTED = mean.w, lower=CI_lower.w, upper=CI_upper.w, SIZE = ns.w, PROP_WEIGHTED = prop.w)
  
  prop.r <- c(sum(new_df.r.1$WEIGHT)/sum(new_df.r$WEIGHT),
              sum(new_df.r.2$WEIGHT)/sum(new_df.r$WEIGHT),
              sum(new_df.r.3$WEIGHT)/sum(new_df.r$WEIGHT))
  
  mean.r <- c(sum(new_df.r.1$Wages*new_df.r.1$WEIGHT)/sum(new_df.r.1$WEIGHT),
              sum(new_df.r.2$Wages*new_df.r.2$WEIGHT)/sum(new_df.r.2$WEIGHT),
              sum(new_df.r.3$Wages*new_df.r.3$WEIGHT)/sum(new_df.r.3$WEIGHT))
  
  se.r = c(sd(new_df.r.1$Wages)/sqrt(nrow(new_df.r.1)),
           sd(new_df.r.2$Wages)/sqrt(nrow(new_df.r.2)),
           sd(new_df.r.3$Wages)/sqrt(nrow(new_df.r.3)))
  CI_lower.r = mean.r - 1.96*se.r
  CI_upper.r = mean.r + 1.96*se.r
  ns.r = c(nrow(new_df.r.1),nrow(new_df.r.2),nrow(new_df.r.3))
  
  
  
  
  df.r <- data.frame(GROUP = rep("Racialized", 3), EDU = c("No training/certificate", 
                                                           "Training program",
                                                           "BA+"), 
                     MEAN_WEIGHTED = mean.r, lower=CI_lower.r, upper=CI_upper.r, SIZE = ns.r, PROP_WEIGHTED = prop.r)
  
  df_for_barplot <- rbind(df.r, df.w)
  df_for_barplot}

all_edu_cats_means <- lapply(1:26, function(x) {
  make_df_edu_cats_barplot(x)
})
education_cats_means <- as.data.frame(do.call(rbind, all_edu_cats_means))


make_df_gender_barplot <- function(occupation){
  new_df <- data_split[[occupation]]
  new_df <-  new_df[,which(names(new_df)%in%c("Gender","Wages","VISMIN_binary","WEIGHT"))]
  new_df <- new_df[which(complete.cases(new_df)),]
  new_df.r <- new_df[new_df$VISMIN_binary=="Racialized",]
  new_df.w <- new_df[new_df$VISMIN_binary=="White",]
  new_df.r.m <- new_df.r[new_df.r$Gender=="Man+",]
  new_df.r.w <- new_df.r[new_df.r$Gender=="Woman+",]
  new_df.w.m <- new_df.w[new_df.w$Gender=="Man+",]
  new_df.w.w <- new_df.w[new_df.w$Gender=="Woman+",]
  
  prop.w <- c(sum(new_df.w.w$WEIGHT)/sum(new_df.w$WEIGHT),
              sum(new_df.w.m$WEIGHT)/sum(new_df.w$WEIGHT))
  mean.w <- c(sum(new_df.w.w$Wages*new_df.w.w$WEIGHT)/sum(new_df.w.w$WEIGHT),
              sum(new_df.w.m$Wages*new_df.w.m$WEIGHT)/sum(new_df.w.m$WEIGHT))
  
  se.w = c(sd(new_df.w[new_df.w$Gender=="Woman+",]$Wages)/sqrt(nrow(new_df.w[new_df.w$Gender=="Woman+",])),
           sd(new_df.w[new_df.w$Gender=="Man+",]$Wages)/sqrt(nrow(new_df.w[new_df.w$Gender=="Man+",]))
  )
  CI_lower.w = mean.w - 1.96*se.w
  CI_upper.w = mean.w + 1.96*se.w
  ns.w = c(nrow(new_df.w[new_df.w$Gender=="Woman+",]),
           nrow(new_df.w[new_df.w$Gender=="Man+",])
  )
  
  
  
  df.w <- data.frame(GROUP = rep("Nonracialized", 2), GEN = c("Woman+", "Man+"), 
                     MEAN_WEIGHTED = mean.w, lower=CI_lower.w, upper = CI_upper.w, SIZE = ns.w, PROP_WEIGHTED = prop.w)
  
  prop.r <- c(sum(new_df.r.w$WEIGHT)/sum(new_df.r$WEIGHT),
              sum(new_df.r.m$WEIGHT)/sum(new_df.r$WEIGHT))
  mean.r <- c(sum(new_df.r.w$Wages*new_df.r.w$WEIGHT)/sum(new_df.r.w$WEIGHT),
              sum(new_df.r.m$Wages*new_df.r.m$WEIGHT)/sum(new_df.r.m$WEIGHT))
  
  se.r = c(sd(new_df.r[new_df.r$Gender=="Woman+",]$Wages)/sqrt(nrow(new_df.r[new_df.r$Gender=="Woman+",])),
           sd(new_df.r[new_df.r$Gender=="Man+",]$Wages)/sqrt(nrow(new_df.r[new_df.r$Gender=="Man+",]))
  )
  CI_lower.r = mean.r - 1.96*se.r
  CI_upper.r = mean.r + 1.96*se.r
  ns.r = c(nrow(new_df.r[new_df.r$Gender=="Woman+",]),
           nrow(new_df.r[new_df.r$Gender=="Man+",])
  )
  
  median.r <-  c(median(new_df.r[new_df.r$Gender=="Woman+",]$Wages),
                 median(new_df.r[new_df.r$Gender=="Man+",]$Wages)
  )
  
  df.r <- data.frame(GROUP = rep("Racialized", 2), GEN = c("Woman+", "Man+"), 
                     MEAN_WEIGHTED = mean.r, lower=CI_lower.r, upper = CI_upper.r,SIZE = ns.r, PROP_WEIGHTED = prop.r)
  
  df_for_barplot <- rbind(df.r, df.w)
  df_for_barplot}

all_gender_means <- lapply(1:26, function(x) {
  make_df_gender_barplot(x)
})
gender_means <- as.data.frame(do.call(rbind, all_gender_means))

## add the NOCS codes
NOC_var <- levels(census_BC_workers$NOC21)[1:26]
rm(NOC21_var6)

dim(age_means) # 156, rep XXX times
age_means$NOC21 <- rep(NOC_var, each = 16) # check 16 was in error?

education_means$NOC21 <- rep(NOC_var, each = 6)  
education_cats_means$NOC21 <- rep(NOC_var, each = 6)

gender_means$NOC21 <- rep(NOC_var, each = 4)
generation_means2$NOC21 <- rep(NOC_var, each=4)


## assemble and format all of the means tables here
job_means_split <- lapply(1:length(NOC_var), function(x) {
  match_this <- NOC_var[x]
  print(match_this)
  new2 <- age_means[which(age_means$NOC21 == match_this & age_means$GROUP =="Racialized"),]
  names(new2)[2] <- "FACTOR_LEVEL"
  new3 <- gender_means[which(gender_means$NOC21 == match_this & gender_means$GROUP =="Racialized"),]
  names(new3)[2] <- "FACTOR_LEVEL"
  new4 <- generation_means2[which(generation_means2$NOC21 == match_this & generation_means2$GROUP=="Racialized"),]
  names(new4)[2] <- "FACTOR_LEVEL"
  new5 <- education_cats_means[which(education_cats_means$NOC21 == match_this& education_cats_means$GROUP=="Racialized"),]
  names(new5)[2] <- "FACTOR_LEVEL"
  new7 <- education_means[which(education_means$NOC21 == match_this & education_means$GROUP=="Racialized"),]
  names(new7)[2] <- "FACTOR_LEVEL"
  race <- rbind(new2,new3,new4,new5,new7)
  
  newa <- age_means[which(age_means$NOC21 == match_this & age_means$GROUP =="Nonracialized"),]
  names(newa)[2] <- "FACTOR_LEVEL"
  newb <- gender_means[which(gender_means$NOC21 == match_this & gender_means$GROUP =="Nonracialized"),]
  names(newb)[2] <- "FACTOR_LEVEL"
  newc <- generation_means2[which(generation_means2$NOC21 == match_this & generation_means2$GROUP=="Nonracialized"),]
  names(newc)[2] <- "FACTOR_LEVEL"
  newd <- education_cats_means[which(education_cats_means$NOC21 == match_this& education_cats_means$GROUP=="Nonracialized"),]
  names(newd)[2] <- "FACTOR_LEVEL"
  newe <- education_means[which(education_means$NOC21 == match_this & education_means$GROUP=="Nonracialized"),]
  names(newe)[2] <- "FACTOR_LEVEL"
  white <- rbind(newa,newb,newc,newd,newe)
  out <- cbind(race, white)  
  out <- out[,-c(1,8,9,10,16)]
  out$MEAN_WEIGHTED <- round(out$MEAN_WEIGHTED, digits=0) 
  out$lower <- round(out$lower, digits=0)  
  out$upper <- round(out$upper, digits=0) 
  out$MEAN_WEIGHTED.1 <- round(out$MEAN_WEIGHTED.1, digits=0) 
  out$lower.1 <- round(out$lower.1, digits=0)  
  out$upper.1 <- round(out$upper.1, digits=0) 
  out$PROP_WEIGHTED <- paste(round(out$PROP_WEIGHTED, digits=2)*100 , "%", sep="")
  out$PROP_WEIGHTED.1 <- paste(round(out$PROP_WEIGHTED.1, digits=2)*100, "%", sep="") 
  out$FACTOR_LEVEL <- ifelse(out$FACTOR_LEVEL=="under25", "Under 25", out$FACTOR_LEVEL)
  out$FACTOR_LEVEL <- ifelse(out$FACTOR_LEVEL=="SECOND AND LATER", 
                             "2nd+", out$FACTOR_LEVEL)
  
  out <- insertRows(out, 1, new = "")
  out <- insertRows(out, 10, new = "")
  out <- insertRows(out, 13, new = "")
  out <- insertRows(out, 16, new = "")
  out <- insertRows(out, 20, new = "")
  out[c(1,10,13,16,20),1] <- c("Age", "Gender", "Generation","Education", "Education Origin")
  names(out) <- c("Group","Mean","Lower CI","Upper CI","Size","Proportion","Mean","Lower CI",
                  "Upper CI","Size","Proportion")
  
  out
})

## for a simplified name on each sheet
names(job_means_split) <- substr(NOC_var, 1, 5)

## declutter intermediate objects
rm(all_age_means, all_edu_means, all_edu_cats_means, all_gender_means, all_generation_means)
rm(age_means, education_means, education_cats_means, gender_means, generation_means2)


#### PRIMARY ANALYSIS ################

# for results table: 
# NOC, sample size, percent racialized, median, mean, mean white, mean race, difference, 
# adjusted difference, TEST STATISTIC, se, pvalue, adjusted R2

mean_wage_and_gap <- sapply(1:length(data_split), function(x) { 
  df <- data_split[[x]]
  mean_tot <- mean(df$Wages, na.rm = TRUE)
  median_tot <- median(df$Wages, na.rm = TRUE)
  mean_white <- mean(df[which(df$VISMIN_binary=="White"),]$Wages, na.rm = TRUE)
  mean_rac <- mean(df[which(df$VISMIN_binary=="Racialized"),]$Wages, na.rm = TRUE)
  #sd_white <- sd(df[which(df$VISMIN_binary=="White"),]$Wages, na.rm = TRUE)
  #sd_rac <- sd(df[which(df$VISMIN_binary=="Racialized"),]$Wages, na.rm = TRUE)
  gap <- mean_white - mean_rac  # positive = more money for whites
  cbind(median_tot,mean_tot, mean_white, mean_rac,gap)
})
mean_wage_and_gap <- as.data.frame(t(mean_wage_and_gap))
colnames(mean_wage_and_gap) <- c("median","mean", "mean white",
                                 "mean race", "mean gap")

rownames(mean_wage_and_gap) <- NOC_var



## pulls the wanted statitsics for linear model testing VISMIS_binary significance
all_covars_pval <- sapply(1:length(data_split), function(x) { 
  df <- data_split[[x]]
  m1 <- lm(Wages ~ VISMIN_binary+ AGEGRP2 + Gender + GENSTAT3 + HDGREE_numeric,weights=WEIGHT , df)
  summary(m1) 
  af <- anova(m1)
  afss <- af$"Sum Sq"
  PctExp <- afss/sum(afss)*100
  out <- c(tidy(m1)$estimate[2],
           tidy(m1)$std.error[2],
           tidy(m1)$statistic[2],
           tidy(m1)$p.value[2],summary(m1)$adj.r.squared)
  
  out
})

which(all_covars_pval[4,]<.05) # 9 occupations

# check the significance if we winzorize the extreme positive incomes
all_covars_pval_winzor <- sapply(1:length(data_split), function(x) { 
  df <- data_split[[x]]
  m1 <- lm(Wages.winzor ~ VISMIN_binary+ AGEGRP2 + Gender + GENSTAT3 + HDGREE_numeric , df)
  summary(m1) 
  tidy(m1)$p.value[2]
})

which(all_covars_pval_winzor<.05)  # 2 more occupations with p < .05



## robustness checks of the linear model
## data overall vs. data split by occupation

## reduce to a matrix with only the variables we used in model:
which(names(census_BC_workers)%in%c("Wages","RACIALIZED","Female","SECOND_GEN", "AGE.avg"))

# Compute the correlation matrix
multicor <- census_BC_workers[,c(27,57, 67, 68, 70)]
cor_matrix <- cor(multicor)

# Visualize the correlation matrix
corrplot::corrplot(cor_matrix, method = "circle") #negligable


# multicoll check, vif should be less than 5
vif_vals <- sapply(1:length(data_split), function(x) { 
  df <- data_split[[x]]
  m1 <- lm(Wages.winzor ~ VISMIN_binary+ AGEGRP2 + Gender + GENSTAT3 + HDGREE_numeric , df)
  vif_values <- car::vif(m1)
  vif_values[,1]
})
## all good

# now check residuals with education (can be a problem but not likely for specific occupation groups)
res_edu <- sapply(1:length(data_split), function(x) { 
  df <- data_split[[x]]
  m1 <- lm(Wages.winzor ~ VISMIN_binary+ AGEGRP2 + Gender + GENSTAT3 + HDGREE_numeric , df)
  out <- cor.test(residuals(m1), m1$model$HDGREE_numeric)
  out$p.value
})
rm(multicor,cor_matrix,vif_vals, res_edu)



# last elements for results table
sample_sizes <- unlist(lapply(data_split, nrow))
prop_racialized <- sapply(1:length(data_split), function(x) { 
  df <- data_split[[x]]
  table(df$VISMIN_binary)[1]/(table(df$VISMIN_binary)[1]+table(df$VISMIN_binary)[2])
})


# NOC, sample size, percent racialized, median, mean, mean white, mean race, difference, 
# adjusted difference, TEST STATISTIC, se, pvalue, adjusted R2

mean_wage_and_gap # "mean","median", "mean gap", "mean white", "mean race"


new_table1 <- cbind( prop_racialized, sample_sizes,mean_wage_and_gap,t(all_covars_pval),all_covars_pval_winzor)

names(new_table1)[8:12] <- c("estimate", "se", "test stat", "pvalue", "adjRq")
names(new_table1)

## this is the first, "Main results" tab in the "workbook_economic_inclusion_BCcatalogue.xlsx"
#file found in the BC Data catalogue for this project. All following tabs in that file
# are the summary tables created in lists below and saved at the end of the script
write.csv(new_table1, file="new_main_results_feb13.csv")

## clean up
rm(new_table1, mean_wage_and_gap)


################# oaxaca model per occupation ############
## the below code running 26 oaxaca models of various forms will take time to run, plan accordingly

all_oax <- lapply(1:length(data_split), function(x) { 
  test <- data_split[[x]]
  results2 <- oaxaca(formula = Wages ~ AGE.avg
                     + Female + NONFIRST
                     + HDGREE_s | RACIALIZED
                     , data = test, R = 1000)
  results2
})
## save right away for later
save(all_oax, file="oaxaca_results_object_feb12.R")


## WE ARE INCLUDING racial identity, pooled regressions, use contrast -2 for variance explained
summaries_all <- lapply(all_oax, function(x) {
  sizeA <- x$n$n.A
  sizeB <- x$n$n.B
  propA <- round(x$n$n.A/x$n$n.pooled, digits=2)
  propB <- round(x$n$n.B/x$n$n.pooled, digits=2)
  sqA <- round(summary(x$reg$reg.A)$r.squared,digits=2)
  sqB <- round(summary(x$reg$reg.B)$r.squared, digits=2)
  sumA <- summary(x$reg$reg.A)$coefficients
  sumB <- summary(x$reg$reg.B)$coefficients
  rownames(sumA) <- paste(rownames(sumA), "_nonracialized", sep="")
  rownames(sumB) <- paste(rownames(sumB), "_racialized", sep="")
  sum_pooled <- summary(x$reg$reg.pooled.2)$coefficients
  sums <- rbind(sumA, sumB, sum_pooled)
  sums2 <- as.data.frame(sums[-c(1,6,11:16),])
  sums2$CI_lower <- round(sums2$Estimate - 1.96*sums2$'Std. Error', digits=0)
  sums2$CI_higher <- round(sums2$Estimate + 1.96*sums2$'Std. Error', digits=0)
  sums2$Variables <- rep(c("Age (older)","Gender (Woman+)","Generation (2nd+)","Education (more)"),2)
  sums2$Ref_cat <- rep(c("Younger","Man+","1st","Less"),2)
  sums2$Model <- c("White", paste("n = ",sizeA, sep=""), propA, paste("R2 = ",sqA, sep=""),
                   "Racialized", paste("n = ",sizeB, sep=""), propB, paste("R2 = ",sqB, sep=""))
  sums3 <- sums2[,c(9,7,8,1,5,6,3,4)]
  sums3$Estimate <- round(sums3$Estimate, digits=0)
  sums3$`t value` <- round(sums3$`t value`, digits=0)
  sums3$`Pr(>|t|)` <- round(sums2$`Pr(>|t|)`, digits=2)
  names(sums3) <- c("Model","Variables", "Reference Category", 
                    "Regression Coefficient (b)",	"Lower CI",	"Upper CI",	"t-value","p-value")
  sums3
})

substr(NOC_var, 1, 5)  # name each item in list so that each sheet in excel will have these names
names(summaries_all) <- substr(NOC_var, 1, 5)

######## save all List results (as excel files where each tab is by occupation) ######

library(openxlsx)
openxlsx::write.xlsx(job_means_split, "means_feb14.xlsx")
openxlsx::write.xlsx(summaries_all, "oax_results_by_job_feb12.xlsx")

