# script for converting spike numbers to long format and figuring out how much data is lost

library(dplyr)
library(tidyverse)

setwd("/ix1/lhallion/TReW-Brain/Scripts/preprocessing")
spikes <- read.table("spike_numbers.txt")
spikes <- spikes %>% select(!V2)
colnames(spikes) <- c("subject","run","spikes")
spikes_wide <- spikes %>% 
  mutate(run = str_c('run', run)) %>%
  pivot_wider(names_from = run, values_from = spikes)
sum((spikes_wide$run1/512)>0.10)
sum((spikes_wide$run2/512)>0.10)
sum((spikes_wide$run3/512)>0.10,na.rm=T)


spikes_wide$which_fsf <- ""
for(sub in spikes_wide$subject){
  fsfvar <- spikes_wide[spikes_wide$subject==sub,]<128
  fsfvar[1,5] <- FALSE
  fsfvar[is.na(fsfvar)] <- FALSE
  spikes_wide[spikes_wide$subject==sub,"which_fsf"] <-  paste(colnames(spikes_wide[spikes_wide$subject==sub,fsfvar[1,]]), collapse = "")
}

write.table(spikes_wide,"spikes_wide.txt",sep = "\t",quote = F, row.names = F)
