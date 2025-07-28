library(dplyr)

setwd("/ix1/lhallion/TReW-Brain/Scripts/preprocessing/")

d <- read.table('spike_numbers.txt')
d <- d[,c("V1","V3","V4")]
colnames(d) <- c("participant","run","n_spikes")

range(d$n_spikes)
meanspikes <- d %>% group_by(participant) %>% summarise(mean = mean(n_spikes))
mean(meanspikes$mean)
range(meanspikes$mean)
