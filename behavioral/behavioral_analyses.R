# Ceci Westbrook, 2025
# reads in PsychoPy data for the TReW-Brain study and reformats for behavioral analyses.setwd("${TREW_DATA_ROOT}/sourcedata/psychopy/")

library(stringr)
library(dplyr)
library(reshape2)
library(lme4)
library(lmerTest)
library(ggplot2)
library(tidyverse)
library(fuzzyjoin)

setwd("${TREW_DATA_ROOT}/sourcedata/psychopy/")
basepath <- file.path("${TREW_DATA_ROOT}/sourcedata/psychopy/")
# dest_vol <- file.path("${TREW_WORK_ROOT}/")
dest_vol <- Sys.getenv("TREW_WORK_ROOT", unset = ".")

# going to save time by reading this in ahead of time and making the dataframe so it doesn't have to do it for every subject
csv_path <- file.path("${TREW_WORK_ROOT}/")
PTC_names <- read_csv(csv_path, n_max = 0) %>% names()
PTCall <- read_csv(csv_path,col_names = PTC_names, skip = 3)

getallsubdata <- function(searchdir,filename){
  subdir <- as.numeric(str_extract(searchdir,"[[:digit:]]+"))
  print(subdir)
  fulldir <- basename(searchdir)
  fullsub <- strsplit(fulldir,"_")[[1]][1]
  
  tryCatch(
    expr = {
      d <- read.csv(file.path(searchdir,filename))
      
      d$run_id <- cumsum(!nzchar(d$Thought))
      ## remove blank lines
      d <- d[nzchar(d$Thought), ]
      
      #dataframe to store everything
      allsubdata <- data.frame()
      
      ## split the data frame
      d_split <- split(d[, -ncol(d)], d$run_id)
      i = 0
      for(split in d_split){
        i <- i + 1
        
        # first, get the SART data
        SART_out <- split
        SART_out$onset <- SART_out$D_Cue.started
        SART_out$duration <- lead(SART_out$D_Cue.started) - SART_out$D_Cue.started
        SART_out[is.na(SART_out$duration),"duration"] <- lead(SART_out[is.na(SART_out$duration),"Reflect.started"]) - SART_out[is.na(SART_out$duration),"D_Cue.started"]
        SART_out <- SART_out[!is.na(split$thoughtNumber),]
        SART_out$response_time <- SART_out$D_Response.rt + (SART_out$D_Fixation.started - SART_out$D_Cue.started)
        SART_out$response <- SART_out$D_Response.keys
        SART_out$corr_ans <- ifelse(SART_out$D_Response.keys=="2" & SART_out$correct=="2.0" | SART_out$D_Response.keys==SART_out$correct,1,0)
        SART_out$trial_type <- SART_out$type
        SART_out <- SART_out %>% select(onset,duration,response_time,trial_type,corr_ans,thoughtNumber)
        # correct timing for start of the run
        SART_out$onset <- SART_out$onset - split$ThoughtText.started[1]
        SART_out$outlierRT <- ifelse(SART_out$response_time > mean(SART_out$response_time, na.rm=T) + 3*sd(SART_out$response_time,na.rm=T) |
                                       SART_out$response_time < mean(SART_out$response_time, na.rm=T) - 3*sd(SART_out$response_time,na.rm=T),1,0)
        SART_out$meanRT <- mean(SART_out$response_time, na.rm=T)
        SART_out$numSARTtrials <- nrow(SART_out)
        # remove outliers
        #SART_out <- SART_out %>% filter(outlierRT <1 | is.na(SART_out$response_time))

        # Next, need thought probe data
        Probes_out <- split[!is.na(split$probenumber),]
        # filter only for vars we need
        Probes_out <- Probes_out %>% select(participant,Thought,ThoughtNumber,Reflect.started,probenumber,slider.response)
        for(row in 1:nrow(Probes_out)){
          if(is.na(Probes_out[row,"Reflect.started"])){
            Probes_out[row,"Reflect.started"] <- Probes_out[row-1,"Reflect.started"]
          }
        }
        Probes_out <- dcast(Probes_out, participant + Thought + ThoughtNumber + Reflect.started ~ probenumber,value.var = "slider.response") %>% arrange(Reflect.started)
        Probes_out$onset <- Probes_out$Reflect.started
        Probes_out <- cbind(Probes_out,data.frame(offset = split[!is.na(split$Fixation_P.started),"Fixation_P.started"])[1])
        Probes_out$duration <- Probes_out$offset - Probes_out$onset
        Probes_out$probe1 <- Probes_out$`1`
        Probes_out$probe2 <- Probes_out$`2`
        Probes_out$probe3 <- Probes_out$`3`
        Probes_out$probe4 <- Probes_out$`4`
        Probes_out$probe5 <- Probes_out$`5`
        Probes_out$probe6 <- Probes_out$`6`
        Probes_out <- Probes_out %>% select(participant,Thought,ThoughtNumber,onset,duration,probe1,probe2,probe3,probe4,probe5,probe6)
              
        # then let's calculate the speed/accuracy index for each SART block,
        # then add that to the out dataframe. Also just the nogo accuracy

        for(thought in SART_out$thoughtNumber){
          # calculate index
          NoGo_ACC <- mean(SART_out[SART_out$thoughtNumber==thought & SART_out$trial_type=="nogo","corr_ans"])
          Mean_go_RT <- mean(SART_out[SART_out$thoughtNumber==thought & SART_out$trial_type=="go","response_time"],na.rm=T)
          AccIndex <- NoGo_ACC/(Mean_go_RT*100)*100
          #print(c(thought,sum(SART_out[SART_out$thoughtNumber==thought, "outlierRT"],na.rm=T)))
          TotalOutlierRT <- sum(SART_out[SART_out$thoughtNumber==thought, "outlierRT"],na.rm=T)
          SART_out[SART_out$thought==thought,"Mean_go_RT"] <- Mean_go_RT
          SART_out[SART_out$thought==thought,"AccIndex"] <- AccIndex
          SART_out[SART_out$thought==thought,"NoGo_ACC"] <- NoGo_ACC
          SART_out[SART_out$thought==thought,"TotalOutlierRT"] <- TotalOutlierRT
        }
        
        SART_out <- SART_out %>% rename(ThoughtNumber = thoughtNumber)
        Probes_out <- merge.data.frame(Probes_out,unique(SART_out[,c("ThoughtNumber","meanRT","Mean_go_RT","AccIndex","NoGo_ACC","TotalOutlierRT","numSARTtrials")]), by = "ThoughtNumber")
        Probes_out$run <- i
        Probes_out <- Probes_out %>% select(participant,run,Thought,ThoughtNumber,probe1,probe2,probe3,probe4,probe5,probe6,meanRT,Mean_go_RT,AccIndex,NoGo_ACC,TotalOutlierRT,numSARTtrials)
        
        # Now get the PTC data and merge in
        # already created dataframe before declaring function
        # filter for this subject

        PTCsub <- PTCall %>% filter(ExternalReference == fullsub)
        # get rid of some vars we don't need
        PTCsub <- PTCsub[,19:ncol(PTCsub)]
        # need to change into long format
        # pivot_longer is going to struggle with this dataset
        test<- PTCsub[,1:37]
        test <- test %>% rename(Q1_1=QID1_1, Q1_2=QID1_2, Q1_3=QID1_3, Q1_4=QID1_4, Q1_5=QID1_5, Q1_6=QID1_6, Q1_7=QID1_7, Q1_8=QID1_8,
                                Q1_9=QID1_9, Q1_10=QID1_10, Q1_11=QID1_11, Q1_12=QID1_12, Q1_13=QID1_13)
        
        suppressMessages(PTCsub <- bind_rows(test,PTCsub[,39:75],PTCsub[,77:113],PTCsub[,115:151],PTCsub[,153:189],PTCsub[,191:227],PTCsub[,229:265],PTCsub[,267:303],PTCsub[,305:341]))
        PTCsub <- PTCsub %>% rename(Thought = `Reminder Phrase`)
        #browser()
        Probes_out <- stringdist_join(Probes_out,PTCsub,mode="left",by = "Thought",ignore_case = TRUE)
        
        # merge with other splits
        
        allsubdata <- rbind(allsubdata,Probes_out)
      }
    },
    error = function(e){
      message(subdir, ":", e)
    }
  )
  return(allsubdata)
}

# combine the data!

alldata <- data.frame()

for (fulldir in list.files("${TREW_DATA_ROOT}/sourcedata/psychopy/")){
  
  searchdir <- file.path(basepath,fulldir)
  filename <- basename(dir(searchdir, full.names=T, pattern=glob2rx("*scanner*.csv")))
  tryCatch(
    expr = {
      alldata <- rbind(alldata,getallsubdata(searchdir,filename))
    },
    error = function(y){
      message(y)
    }
  )
}

# to look at individual subjects
searchdir <- dir(basepath, full.names=T, pattern="303")
fulldir <- basename(searchdir)
filename <- basename(dir(searchdir, full.names=T, pattern=glob2rx("*scanner*.csv")))
alldata <- rbind(alldata,getallsubdata(searchdir,filename))

# there are a few that don't work right - specify the files manually
# 381
searchdir <- dir(basepath, full.names=T, pattern="381")
filename <- basename(file.path(searchdir,"381_TREW-scannerReady_2024-08-24_15h49.29.089.csv"))
alldata <- rbind(alldata,getallsubdata(searchdir,filename))

# 336
searchdir <- dir(basepath, full.names=T, pattern="336")
filename <- basename(file.path(searchdir,"336_TREW-scannerReady_2023-12-02_10h24.02.625.csv"))
alldata <- rbind(alldata,getallsubdata(searchdir,filename))

# 335
searchdir <- dir(basepath, full.names=T, pattern="335")
filename <- basename(file.path(searchdir,"335_TREW-scannerReady_2023-12-05_09h56.15.560.csv"))
alldata <- rbind(alldata,getallsubdata(searchdir,filename))

# 368
searchdir <- dir(basepath, full.names=T, pattern="368")
filename <- basename(file.path(searchdir,"368_TREW-scannerReady_2024-05-03_12h28.39.286.csv"))
alldata <- rbind(alldata,getallsubdata(searchdir,filename))

# 334
searchdir <- dir(basepath, full.names=T, pattern="334")
filename <- basename(file.path(searchdir,"334_TREW-scannerReady_2023-12-06_14h41.07.021.csv"))
alldata <- rbind(alldata,getallsubdata(searchdir,filename))

# 339
searchdir <- dir(basepath, full.names=T, pattern="339")
filename <- basename(file.path(searchdir,"339_TREW-scannerReady_2024-01-11_10h26.54.822.csv"))
alldata <- rbind(alldata,getallsubdata(searchdir,filename))

# problem children
# 304 - didn't complete all probes for all trials
# 315 - almost no RTs
# 366 - not enough probes
# 384 - only two runs, almost no SART responses

# getting total number of outliers - need to turn off the line where we remove outlier trials first
outliercount <- alldata %>% group_by(participant,run) %>% summarize(alloutliers = sum(TotalOutlierRT),
                                                percentoutliers = sum(TotalOutlierRT)/162) %>% print(n=Inf)

range(outliercount$alloutliers)
range(outliercount$percentoutliers)
table(outliercount$alloutliers)
hist(outliercount$alloutliers)
hist(outliercount$percentoutliers)
sum(outliercount$alloutliers)
outliercount[outliercount$alloutliers>4,]
alldata[alldata$participant==368,"TotalOutlierRT"]

sum(alldata$TotalOutlierRT)/(nrow(outliercount)*162)

alldata$dyscontrol <- rowMeans(alldata[,c("Q3_1","Q3_2","Q3_3")],na.rm=T)
alldata$Q3_1_imputed <- ifelse(is.na(alldata$Q3_1),0,alldata$Q3_1)
alldata$Q3_2_imputed <- ifelse(is.na(alldata$Q3_2),0,alldata$Q3_2)
alldata$Q3_3_imputed <- ifelse(is.na(alldata$Q3_3),0,alldata$Q3_3)
alldata$dyscontrol_imputed <- rowMeans(alldata[,c("Q3_1_imputed","Q3_2_imputed","Q3_3_imputed")],na.rm=T)

# let's save the data
save(alldata,file=file.path(dest_vol,"TReWBehavDataAll.Rdata"))

load(file.path(dest_vol,"TReWBehavDataAll.Rdata"))

# NOW: analyses
# indiv ratings: dyscontrol

# skill index
m1 <- lmer(scale(dyscontrol_imputed) ~ scale(AccIndex) + (1 + AccIndex|participant), data = alldata)
summary(m1)
confint(m1)

m1 <- lmer(scale(dyscontrol) ~ scale(AccIndex) + (1 + AccIndex|participant), data = alldata)
summary(m1)
confint(m1)

# checking for outliers
meanACCsbysubj <- alldata %>% group_by(participant) %>% summarise(overall_mean_ACC = mean(AccIndex,na.rm=T))
meanACCsbysubj[which(meanACCsbysubj$overall_mean_ACC > mean(meanACCsbysubj$overall_mean_ACC) + 3*sd(meanACCsbysubj$overall_mean_ACC)),]

g <- ggplot(alldata,aes(x=dyscontrol,y=AccIndex))
g + geom_point(aes(color=as.factor(participant)), alpha = 0.4) +
  geom_line(stat="smooth",method="lm", alpha = 0.4, aes(color = as.factor(participant)), size = 0.5, se = F) +
  geom_smooth(data = alldata, method = "lm", aes(dyscontrol,AccIndex), lwd = 2, alpha = 1) +
  theme(legend.position="none") +
  scale_x_continuous(name="Pre-scan Dyscontrol Rating") +
  scale_y_continuous(name="SART Skill Index") 

# checking for influential outlier
m1 <- lmer(scale(dyscontrol_imputed) ~ scale(AccIndex) + (1 + AccIndex|participant), data = alldata[alldata$participant!=393,])
summary(m1)
confint(m1)

# Accuracy
# LM is significant--but not for imputed values
m1 <- lm(dyscontrol ~ NoGo_ACC, data = alldata)
summary(m1)

m1 <- lm(dyscontrol_imputed ~ NoGo_ACC, data = alldata)
summary(m1)

# MLM is NOT significant
m1 <- lmer(scale(dyscontrol_imputed) ~ scale(NoGo_ACC) + (1+NoGo_ACC|participant), data = alldata)
summary(m1)
confint(m1)

m1 <- lmer(scale(dyscontrol) ~ scale(NoGo_ACC) + (1+NoGo_ACC|participant), data = alldata)
summary(m1)
confint(m1)

# checking for outliers
meanACCsbysubj <- alldata %>% group_by(participant) %>% summarise(overall_mean_ACC = mean(NoGo_ACC,na.rm=T))
meanACCsbysubj[which(meanACCsbysubj$overall_mean_ACC > mean(meanACCsbysubj$overall_mean_ACC) + 3*sd(meanACCsbysubj$overall_mean_ACC)),]

g <- ggplot(alldata,aes(x=dyscontrol_imputed,y=NoGo_ACC))
g + geom_point(aes(color=as.factor(participant)), alpha = 0.4) +
  geom_line(stat="smooth",method="lm", alpha = 0.4, aes(color = as.factor(participant)), size = 0.5, se = F) +
  geom_smooth(data = alldata, method = "lm", aes(dyscontrol_imputed,NoGo_ACC), lwd = 2, alpha = 1) +
  theme(legend.position="none") +
  scale_x_continuous(name="Pre-scan Dyscontrol Rating") +
  scale_y_continuous(name="No-Go Accuracy") 

# Speed
# LM is significant
m1 <- lm(dyscontrol_imputed ~ Mean_go_RT, data = alldata)
summary(m1)

# MLM IS significant
m1 <- lmer(scale(dyscontrol_imputed) ~ scale(Mean_go_RT) + (1 + Mean_go_RT|participant), data = alldata)
summary(m1)
confint(m1)

m1 <- lmer(scale(dyscontrol) ~ scale(Mean_go_RT) + (1 + Mean_go_RT|participant), data = alldata)
summary(m1)
confint(m1)

g <- ggplot(alldata,aes(x=dyscontrol_imputed,y=Mean_go_RT))
g + geom_point(aes(color=as.factor(participant)), alpha = 0.4) +
  geom_line(stat="smooth",method="lm", alpha = 0.4, aes(color = as.factor(participant)), size = 0.5, se = F) +
  geom_smooth(data = alldata, method = "lm", aes(dyscontrol_imputed,Mean_go_RT), lwd = 2, alpha = 1) +
  theme(legend.position="none") +
  scale_x_continuous(name="Pre-scan Dyscontrol Rating\n (repetitive, intrusive, or hard to control?)") +
  scale_y_continuous(name="Mean Go RT") #+ geom_text(label = alldata$participant)

# and robust to outliers:
meanRTsbysubj <- alldata %>% group_by(participant) %>% summarise(overall_mean_RT = mean(Mean_go_RT,na.rm=T))
meanRTsbysubj[which(meanRTsbysubj$overall_mean_RT > mean(meanRTsbysubj$overall_mean_RT) + 3*sd(meanRTsbysubj$overall_mean_RT)),]

m1 <- lmer(scale(dyscontrol_imputed) ~ scale(Mean_go_RT) + (1 + Mean_go_RT|participant), data = alldata[alldata$participant!=393,])
summary(m1)
confint(m1)

m1 <- lmer(scale(dyscontrol) ~ scale(Mean_go_RT) + (1 + Mean_go_RT|participant), data = alldata[alldata$participant!=393,])
summary(m1)
confint(m1)

g <- ggplot(alldata[alldata$participant!=393,],aes(x=dyscontrol_imputed,y=Mean_go_RT))
g + geom_point(aes(color=as.factor(participant)), alpha = 0.4) +
  geom_line(stat="smooth",method="lm", alpha = 0.4, aes(color = as.factor(participant)), size = 0.5, se = F) +
  geom_smooth(data = alldata, method = "lm", aes(dyscontrol_imputed,Mean_go_RT), lwd = 2, alpha = 1) +
  theme(legend.position="none") +
  scale_x_continuous(name="Pre-scan Dyscontrol Rating\n (repetitive, intrusive, or hard to control?)") +
  scale_y_continuous(name="Mean Go RT") 

m1 <- lmer(scale(dyscontrol_imputed) ~ scale(AccIndex) + (1+AccIndex|participant), data = alldata)
summary(m1)

g <- ggplot(alldata,aes(x=dyscontrol_imputed,y=AccIndex))
g + geom_point(aes(color=as.factor(participant)), alpha = 0.4) +
  geom_line(stat="smooth",method="lm", alpha = 0.4, aes(color = as.factor(participant)), size = 0.5, se = F) +
  geom_smooth(data = alldata, method = "lm", aes(dyscontrol_imputed,AccIndex), lwd = 2, alpha = 1) +
  theme(legend.position="none") +
  scale_x_continuous(name="Individual Thought Rating: Dyscontrol (after imputation)") +
  scale_y_continuous(name="Accuracy Index") 


# one big combined plot
g1 <- ggplot(alldata[alldata$participant!=393,],aes(x=dyscontrol_imputed,y=AccIndex)) +
  geom_point(aes(color=as.factor(participant)), alpha = 0.4) +
  geom_line(stat="smooth",method="lm", alpha = 0.4, aes(color = as.factor(participant)), size = 0.5, se = F) +
  geom_smooth(data = alldata, method = "lm", aes(dyscontrol_imputed,AccIndex), lwd = 2, alpha = 1) +
  annotate(
    geom = "text",
    x = 5.0,
    y = 2.5,
    label = "*",
    color="red",
    size = 10) +
  theme(legend.position="none") +
  theme(axis.title.x = element_blank()) + theme(axis.title.y = element_text(size=18)) +
  scale_x_continuous(name="Pre-Scan Uncontrollability Rating (How much is this thought repetitive, intrusive, or hard to control?)") +
  scale_y_continuous(name="Skill Index (arbitrary units)") 

g2 <- ggplot(alldata[alldata$participant!=393,],aes(x=dyscontrol_imputed,y=NoGo_ACC)) +
  geom_point(aes(color=as.factor(participant)), alpha = 0.4) +
  geom_line(stat="smooth",method="lm", alpha = 0.4, aes(color = as.factor(participant)), size = 0.5, se = F) +
  geom_smooth(data = alldata, method = "lm", aes(dyscontrol_imputed,NoGo_ACC), lwd = 2, alpha = 1) +
  theme(legend.position="none") + theme(axis.title.y = element_text(size=18),axis.title.x = element_text(size=18)) +
  scale_x_continuous(name="Pre-Scan Uncontrollability Rating (How much is this thought repetitive, intrusive, or hard to control?)") +
  scale_y_continuous(name="No-Go Accuracy (percent correct)") 

g3 <- ggplot(alldata[alldata$participant!=393,],aes(x=dyscontrol_imputed,y=Mean_go_RT)) +
  geom_point(aes(color=as.factor(participant)), alpha = 0.4) +
  geom_line(stat="smooth",method="lm", alpha = 0.4, aes(color = as.factor(participant)), size = 0.5, se = F) +
  geom_smooth(data = alldata, method = "lm", aes(dyscontrol_imputed,Mean_go_RT), lwd = 2, alpha = 1) +
  theme(legend.position="none") +
  annotate(
    geom = "text",
    x = 5.0,
    y = 1.0,
    label = "†",
    color="red",
    size = 8) +
  theme(axis.title.x = element_blank()) + theme(axis.title.y = element_text(size=18)) +
  scale_x_continuous(name="Pre-Scan Uncontrollability Rating (How much is this thought repetitive, intrusive, or hard to control?)") +
  scale_y_continuous(name="Mean Go RT (s)") 

library(egg)
plot3 <- ggarrange(g1,g2,g3,ncol=3)


# Thought probes
alldata$probe1 <- as.numeric(alldata$probe1)
alldata$probe2 <- as.numeric(alldata$probe2)
alldata$probe3 <- as.numeric(alldata$probe3)
alldata$probe4 <- as.numeric(alldata$probe4)
alldata$probe5 <- as.numeric(alldata$probe5)
alldata$probe6 <- as.numeric(alldata$probe6)
m1 <- lmer(probe1 ~ AccIndex + (1+AccIndex|participant), data = alldata)
summary(m1)

"To what extent were your thoughts repetitive, intrusive, or hard to control?"
m1 <- lmer(probe1 ~ AccIndex + (1+AccIndex|participant), data = alldata)
summary(m1)

m1 <- lmer(scale(probe1) ~ scale(AccIndex) + (1+AccIndex|participant), data = alldata)
summary(m1)
confint(m1)

# adding baseline dyscontrol - still significant!
m1 <- lmer(scale(probe1) ~ scale(AccIndex) + scale(dyscontrol_imputed) + (1+AccIndex|participant), data = alldata)
summary(m1)
confint(m1)

m1 <- lmer(scale(probe1) ~ scale(AccIndex) + (1+AccIndex|participant), data = alldata[alldata$participant!=393,])
summary(m1)
confint(m1)

m1 <- lmer(scale(probe1) ~ scale(AccIndex) + scale(dyscontrol_imputed) + (1+AccIndex|participant), data = alldata[alldata$participant!=393,])
summary(m1)
confint(m1)

# adding task effort
m1 <- lmer(scale(probe1) ~ scale(AccIndex) + scale(probe3) + (1+AccIndex|participant), data = alldata)
summary(m1)
confint(m1)


g <- ggplot(alldata,aes(x=probe1,y=AccIndex))
g + geom_point(aes(color=as.factor(participant)), alpha = 0.4) +
  geom_line(stat="smooth",method="lm", alpha = 0.4, aes(color = as.factor(participant)), size = 0.5, se = F) +
  geom_smooth(data = alldata, method = "lm", aes(probe1,AccIndex), lwd = 2, alpha = 1) +
  theme(legend.position="none") +
  scale_x_continuous(name="End-of-trial Dyscontrol Rating\n (How much were thoughts\nrepetitive, intrusive, or hard to control?)") +
  scale_y_continuous(name="Accuracy Index") 

# let's look at speed/accuracy
m1 <- lmer(scale(probe1) ~ scale(Mean_go_RT) + (1+Mean_go_RT|participant), data = alldata[alldata$Mean_go_RT<1.0,])
summary(m1)
confint(m1)

g <- ggplot(alldata[alldata$Mean_go_RT<1.0,],aes(x=probe1,y=Mean_go_RT))
g + geom_point(aes(color=as.factor(participant)), alpha = 0.4) +
  geom_line(stat="smooth",method="lm", alpha = 0.4, aes(color = as.factor(participant)), size = 0.5, se = F) +
  geom_smooth(data = alldata, method = "lm", aes(probe1,Mean_go_RT), lwd = 2, alpha = 1) +
  theme(legend.position="none") +
  scale_x_continuous(name="End-of-trial Dyscontrol Rating\n (How much were thoughts\nrepetitive, intrusive, or hard to control?)") +
  scale_y_continuous(name="Mean Go RT") 

# not quite robust to one outlier
m1 <- lmer(scale(probe1) ~ scale(Mean_go_RT) + (1+Mean_go_RT|participant), data = alldata[alldata$participant!=393,])
summary(m1)
confint(m1)

g <- ggplot(alldata[alldata$participant!=393,],aes(x=probe1,y=Mean_go_RT))
g + geom_point(aes(color=as.factor(participant)), alpha = 0.4) +
  geom_line(stat="smooth",method="lm", alpha = 0.4, aes(color = as.factor(participant)), size = 0.5, se = F) +
  geom_smooth(data = alldata, method = "lm", aes(probe1,Mean_go_RT), lwd = 2, alpha = 1) +
  theme(legend.position="none") +
  scale_x_continuous(name="End-of-trial Dyscontrol Rating\n (How much were thoughts\nrepetitive, intrusive, or hard to control?)") +
  scale_y_continuous(name="Mean Go RT") 

# not significant if baseline dyscontrol included
m1 <- lmer(scale(probe1) ~ scale(Mean_go_RT) + scale(dyscontrol_imputed) + (1+Mean_go_RT|participant), data = alldata[alldata$Mean_go_RT<1.0,])
summary(m1)
confint(m1)

# accuracy
m1 <- lmer(scale(probe1) ~ scale(NoGo_ACC) + (1+NoGo_ACC|participant), data = alldata)
summary(m1)
confint(m1)

m1 <- lmer(scale(probe1) ~ scale(NoGo_ACC) + (1+NoGo_ACC|participant), data = alldata[alldata$participant!=393,])
summary(m1)
confint(m1)

m1 <- lmer(scale(probe1) ~ scale(NoGo_ACC) + scale(dyscontrol_imputed) + (1+NoGo_ACC|participant), data = alldata[alldata$participant!=393,])
summary(m1)
confint(m1)

g <- ggplot(alldata[alldata$NoGo_ACC<1.0,],aes(x=probe1,y=NoGo_ACC))
g + geom_point(aes(color=as.factor(participant)), alpha = 0.4) +
  geom_line(stat="smooth",method="lm", alpha = 0.4, aes(color = as.factor(participant)), size = 0.5, se = F) +
  geom_smooth(data = alldata, method = "lm", aes(probe1,NoGo_ACC), lwd = 2, alpha = 1) +
  theme(legend.position="none") +
  scale_x_continuous(name="End-of-trial Dyscontrol (repetitive, intrusive, or hard to control?)") +
  scale_y_continuous(name="No-Go Accuracy") 

g <- ggplot(alldata[alldata$participant!=393,],aes(x=probe1,y=NoGo_ACC))
g + geom_point(aes(color=as.factor(participant)), alpha = 0.4) +
  geom_line(stat="smooth",method="lm", alpha = 0.4, aes(color = as.factor(participant)), size = 0.5, se = F) +
  geom_smooth(data = alldata, method = "lm", aes(probe1,NoGo_ACC), lwd = 2, alpha = 1) +
  theme(legend.position="none") +
  scale_x_continuous(name="End-of-trial Dyscontrol (repetitive, intrusive, or hard to control?)") +
  scale_y_continuous(name="No-Go Accuracy") 

# one big combined plot
g1 <- ggplot(alldata[alldata$participant!=393,],aes(x=probe1,y=AccIndex)) +
  geom_point(aes(color=as.factor(participant)), alpha = 0.4) +
  geom_line(stat="smooth",method="lm", alpha = 0.4, aes(color = as.factor(participant)), size = 0.5, se = F) +
  geom_smooth(data = alldata, method = "lm", aes(probe1,AccIndex), lwd = 2, alpha = 1) +
  annotate(
    geom = "text",
    x = 50,
    y = 2.5,
    label = "*",
    color="red",
    size = 10) +
  theme(legend.position="none") +
  theme(axis.title.x = element_blank()) + theme(axis.title.y = element_text(size=18)) +
  scale_x_continuous(name="End-of-trial Uncontrollability (How much were thoughts repetitive, intrusive, or hard to control?)") +
  scale_y_continuous(name="Skill Index (arbitrary units)") 

g2 <- ggplot(alldata[alldata$participant!=393,],aes(x=probe1,y=NoGo_ACC)) +
  geom_point(aes(color=as.factor(participant)), alpha = 0.4) +
  geom_line(stat="smooth",method="lm", alpha = 0.4, aes(color = as.factor(participant)), size = 0.5, se = F) +
  geom_smooth(data = alldata, method = "lm", aes(probe1,NoGo_ACC), lwd = 2, alpha = 1) +
  theme(legend.position="none") + theme(axis.title.y = element_text(size=18), axis.title.x = element_text(size=18)) +
  scale_x_continuous(name="End-of-trial Uncontrollability (How much were thoughts repetitive, intrusive, or hard to control?)") +
  scale_y_continuous(name="No-Go Accuracy (percent correct)") 

g3 <- ggplot(alldata[alldata$participant!=393,],aes(x=probe1,y=Mean_go_RT)) +
  geom_point(aes(color=as.factor(participant)), alpha = 0.4) +
  geom_line(stat="smooth",method="lm", alpha = 0.4, aes(color = as.factor(participant)), size = 0.5, se = F) +
  geom_smooth(data = alldata, method = "lm", aes(probe1,Mean_go_RT), lwd = 2, alpha = 1) +
  annotate(
    geom = "text",
    x = 50,
    y = 0.9,
    label = "*",
    color="red",
    size = 10) +
  theme(legend.position="none") +
  theme(axis.title.x = element_blank()) + theme(axis.title.y = element_text(size=18)) +
  scale_x_continuous(name="End-of-trial Uncontrollability (How much were thoughts repetitive, intrusive, or hard to control?)") +
  scale_y_continuous(name="Mean Go RT (s)") 

library(egg)
plot3 <- ggarrange(g1,g2,g3,ncol=3)

"To what extent were your thoughts focused on the task?"
m1 <- lmer(probe2 ~ AccIndex + (1+run|participant), data = alldata)
summary(m1)

g <- ggplot(alldata,aes(x=probe2,y=AccIndex))
g + geom_point(aes(color=as.factor(participant)), alpha = 0.4) +
  geom_line(stat="smooth",method="lm", alpha = 0.4, aes(color = as.factor(participant)), size = 0.5, se = F) +
  geom_smooth(data = alldata, method = "lm", aes(probe2,AccIndex), lwd = 2, alpha = 1) +
  theme(legend.position="none") +
  scale_x_continuous(name="End-of-trial Focus (thoughts focused on the task?)") +
  scale_y_continuous(name="Accuracy Index") 

"To what extent were you trying (making an effort) to focus on the task?"
m1 <- lmer(AccIndex ~ probe3 + (1|participant), data = alldata)
summary(m1)

m2 <- lmer(NoGo_ACC ~ probe3 + (1|participant), data = alldata)
summary(m2)

m3 <- lmer(Mean_go_RT ~ probe3 + (1|participant), data = alldata)
summary(m3)

m4 <- lmer(probe1 ~ probe3 + (1|participant), data = alldata)
summary(m4)

g <- ggplot(alldata,aes(x=probe3,y=AccIndex))
g + geom_point(aes(color=as.factor(participant)), alpha = 0.4) +
  geom_line(stat="smooth",method="lm", alpha = 0.4, aes(color = as.factor(participant)), size = 0.5, se = F) +
  geom_smooth(data = alldata, method = "lm", aes(probe3,AccIndex), lwd = 2, alpha = 1) +
  theme(legend.position="none") +
  scale_x_continuous(name="End-of-trial Effort (were you trying (making an effort) to focus on the task?)") +
  scale_y_continuous(name="Accuracy Index") 

g <- ggplot(alldata,aes(x=probe3,y=NoGo_ACC))
g + geom_point(aes(color=as.factor(participant)), alpha = 0.4) +
  geom_line(stat="smooth",method="lm", alpha = 0.4, aes(color = as.factor(participant)), size = 0.5, se = F) +
  geom_smooth(data = alldata, method = "lm", aes(probe3,NoGo_ACC), lwd = 2, alpha = 1) +
  theme(legend.position="none") +
  scale_x_continuous(name="End-of-trial Effort (were you trying (making an effort) to focus on the task?)") +
  scale_y_continuous(name="No-go accuracy")

g <- ggplot(alldata,aes(x=probe3,y=Mean_go_RT))
g + geom_point(aes(color=as.factor(participant)), alpha = 0.4) +
  geom_line(stat="smooth",method="lm", alpha = 0.4, aes(color = as.factor(participant)), size = 0.5, se = F) +
  geom_smooth(data = alldata, method = "lm", aes(probe3,Mean_go_RT), lwd = 2, alpha = 1) +
  theme(legend.position="none") +
  scale_x_continuous(name="End-of-trial Effort (were you trying (making an effort) to focus on the task?)") +
  scale_y_continuous(name="Mean Go RT")

# one big combined plot
g1 <- ggplot(alldata,aes(x=probe3,y=AccIndex)) +
  geom_point(aes(color=as.factor(participant)), alpha = 0.4) +
  geom_line(stat="smooth",method="lm", alpha = 0.4, aes(color = as.factor(participant)), size = 0.5, se = F) +
  geom_smooth(data = alldata, method = "lm", aes(probe3,AccIndex), lwd = 2, alpha = 1) +
  annotate(
    geom = "text",
    x = 50,
    y = 2.5,
    label = "*",
    color="red",
    size = 10) +
  theme(legend.position="none") +
  theme(axis.title.x = element_blank()) + theme(axis.title.y = element_text(size=18)) +
  scale_x_continuous(name="End-of-trial Effort (were you trying (making an effort) to focus on the task?)") +
  scale_y_continuous(name="Skill Index (arbitrary units)") 

g2 <- ggplot(alldata,aes(x=probe3,y=NoGo_ACC)) +
  geom_point(aes(color=as.factor(participant)), alpha = 0.4) +
  geom_line(stat="smooth",method="lm", alpha = 0.4, aes(color = as.factor(participant)), size = 0.5, se = F) +
  geom_smooth(data = alldata, method = "lm", aes(probe3,NoGo_ACC), lwd = 2, alpha = 1) +
  theme(legend.position="none") + theme(axis.title.y = element_text(size=18),axis.title.x = element_text(size=18)) +
  scale_x_continuous(name="End-of-trial Effort (were you trying (making an effort) to focus on the task?)") +
  scale_y_continuous(name="No-Go Accuracy (percent correct)") 

g3 <- ggplot(alldata,aes(x=probe3,y=Mean_go_RT)) +
  geom_point(aes(color=as.factor(participant)), alpha = 0.4) +
  geom_line(stat="smooth",method="lm", alpha = 0.4, aes(color = as.factor(participant)), size = 0.5, se = F) +
  geom_smooth(data = alldata, method = "lm", aes(probe3,Mean_go_RT), lwd = 2, alpha = 1) +
  theme(legend.position="none") +
  annotate(
    geom = "text",
    x = 50,
    y = 1.0,
    label = "†",
    color="red",
    size = 8) +
  theme(axis.title.x = element_blank()) + theme(axis.title.y = element_text(size=18)) +
  scale_x_continuous(name="End-of-trial Effort (were you trying (making an effort) to focus on the task?)") +
  scale_y_continuous(name="Mean Go RT (s)") 

library(egg)
plot3 <- ggarrange(g1,g2,g3,ncol=3)

# relationship between task effort and focus: r ~ 0.20
m1 <- lmer(scale(probe2) ~ scale(probe3) + (1+run|participant), data = alldata)
summary(m1)

"To what extent did you feel afraid, scared, or frightened?" - n.s.
m1 <- lmer(probe4 ~ AccIndex + (1+run|participant), data = alldata)
summary(m1)

g <- ggplot(alldata,aes(x=probe4,y=AccIndex))
g + geom_point(aes(color=as.factor(participant)), alpha = 0.4) +
  geom_line(stat="smooth",method="lm", alpha = 0.4, aes(color = as.factor(participant)), size = 0.5, se = F) +
  geom_smooth(data = alldata, method = "lm", aes(probe4,AccIndex), lwd = 2, alpha = 1) +
  theme(legend.position="none") +
  scale_x_continuous(name="End-of-trial Anxiety (did you feel afraid, scared, or frightened?)") +
  scale_y_continuous(name="Accuracy Index") 

"To what extent did you feel sad, blue, or downhearted?" - n.s.
m1 <- lmer(probe5 ~ AccIndex + (1+run|participant), data = alldata)
summary(m1)

"To what extent did you feel: sleepy | lively"
m1 <- lmer(probe6 ~ AccIndex + (1+run|participant), data = alldata)
summary(m1)

g <- ggplot(alldata,aes(x=probe6,y=AccIndex))
g + geom_point(aes(color=as.factor(participant)), alpha = 0.4) +
  geom_line(stat="smooth",method="lm", alpha = 0.4, aes(color = as.factor(participant)), size = 0.5, se = F) +
  geom_smooth(data = alldata, method = "lm", aes(probe6,AccIndex), lwd = 2, alpha = 1) +
  theme(legend.position="none") +
  scale_x_continuous(name="End-of-trial Anxiety (did you feel afraid, scared, or frightened?)") +
  scale_y_continuous(name="Accuracy Index") 

# PTC scores
# Q3_1 = repetitive; Q3_2 = intrusive; Q3_3 = uncontrollable
# let's make a composite
alldata$dyscontrol <- rowMeans(alldata[,c("Q3_1","Q3_2","Q3_3")],na.rm=T)

m1 <- lmer(dyscontrol ~ AccIndex + (1+AccIndex|participant), data = alldata)
summary(m1)

m1 <- lmer(dyscontrol ~ AccIndex + (1|participant/Thought.x), data = alldata)
summary(m1)

m1 <- lmer(Q3_1 ~ AccIndex + (1+Thought.x|participant), data = alldata)
summary(m1)

# investigating missing data
alldata[,c(1,16:51)]
library(naniar)
mcar_test(alldata[,c(16:51)]) # p < .03

long_df <- alldata[,c(1:2,16:51)] %>%
  pivot_longer(
    cols = starts_with("Q"),
    names_to = "category",
    values_to = "rating"
  )

count_table <- long_df %>%
  mutate(rating = as.character(rating)) %>%  # Treat NA as a character
  replace_na(list(rating = "NA")) %>%        # Replace NA with string "NA"
  group_by(participant, category, rating) %>%
  summarise(count = n(), .groups = "drop") %>%
  pivot_wider(
    names_from = rating,
    values_from = count,
    values_fill = list(count = 0)  # Fill in missing counts with 0
  )

long_df_with_na <- long_df %>%
  mutate(is_na = is.na(rating)) %>%
  group_by(participant) %>%
  mutate(mean_rating = mean(rating, na.rm = TRUE),
         zero_count = sum(rating == 0, na.rm = TRUE)) %>%
  ungroup()

m1 <- glmer(is_na ~ zero_count + mean_rating + (1|participant), data = long_df_with_na, family = "binomial")
summary(m1)
library(lme4)

library(lme4)
long_df_model <- long_df %>%
  mutate(
    is_na = is.na(rating),
    is_zero = ifelse(rating == 0, 1, 0)  # this will be NA when rating is NA
  )
long_df_model <- long_df_model %>%
  mutate(is_zero = ifelse(is.na(is_zero), 0, is_zero))

table(long_df_model$is_zero, long_df_model$is_na)

participants_with_variation <- long_df_model %>%
  group_by(participant) %>%
  summarise(na_sum = sum(is_na), total = n()) %>%
  filter(na_sum > 0 & na_sum < total) %>%
  pull(participant)

long_df_model_filtered <- long_df_model %>%
  filter(participant %in% participants_with_variation)

glm_model <- glm(is_na ~ is_zero,
                 data = long_df_model,
                 family = binomial)

summary(glm_model)

table(long_df_model$is_zero, long_df_model$is_na)
# According to chatGPT this means that zeros are always picked explicitly, so NAs
# are not equivalent to zeros

participant_summary <- long_df_model %>%
  group_by(participant) %>%
  summarise(
    mean_rating = mean(rating, na.rm = TRUE),
    na_prop = mean(is_na),
    .groups = "drop"
  )

# looks like the relationship is actually inverse!
cor_test <- cor.test(participant_summary$mean_rating, participant_summary$na_prop)
print(cor_test)

ggplot(participant_summary, aes(x = mean_rating, y = na_prop)) +
  geom_point(alpha = 0.6, color = "tomato") +
  geom_smooth(method = "lm", se = FALSE, color = "steelblue") +
  labs(title = "Proportion of Missing Responses vs. Mean Rating",
       x = "Mean Rating (excluding NAs)",
       y = "Proportion of Missing Ratings (NAs)") +
  theme_minimal()

participant_by_category <- long_df_model %>%
  group_by(participant, category) %>%
  summarise(
    mean_rating = mean(rating, na.rm = TRUE),
    na_prop = mean(is_na),
    .groups = "drop"
  )

ggplot(participant_by_category, aes(x = mean_rating, y = na_prop)) +
  geom_point(alpha = 0.4, color = "purple") +
  geom_smooth(method = "lm", se = FALSE, color = "darkgreen") +
  facet_wrap(~ category) +
  labs(
    title = "NA Proportion vs. Mean Rating by Category",
    x = "Mean Rating (per Participant)",
    y = "Proportion NA"
  ) +
  theme_minimal()

library(purrr)

# Compute correlations per category
category_cor <- participant_by_category %>%
  group_by(category) %>%
  summarise(
    cor_test = list(cor.test(mean_rating, na_prop)),
    .groups = "drop"
  ) %>%
  # Unnest and extract the correlation results
  mutate(tidy = map(cor_test, broom::tidy)) %>%
  unnest(cols = c(tidy)) %>%
  dplyr::select(category,estimate,p.value)

# View the results
print(category_cor)
category_cor %>%
  mutate(sig = p.value < 0.05) %>%
  count(sig)

# OK so looks like NAs are positively correlated with values. Let's try looking at
# Cronbach's alpha:
library(dplyr)
library(tidyr)
library(psych)  # for alpha()

df_wide <- alldata[,c("participant","run","Q3_1","Q3_2","Q3_3")] #alldata[,c(1:2,4,16:51)] # select out just the thought var data

# baseline alpha
alpha(alldata[,c("Q3_1","Q3_2","Q3_3")])

alpha_results_list <- list()  # use a list instead of a tibble

  for (val in 0:9) {
    this_df <- df_wide %>%
      dplyr::mutate(across(-participant, ~ifelse(is.na(.), val, .)))

    alpha_val <- psych::alpha(this_df %>% select(-participant, -run), check.keys = TRUE)$total$raw_alpha

    alpha_results_list <- bind_rows(alpha_results_list,
                               tibble(imputed_value = val, alpha = alpha_val))
}
# for (Qnumber in 1:4) {
#   df_thisQ <- df_wide %>%
#     dplyr::select(starts_with(paste0("Q", Qnumber))) %>%
#     dplyr::mutate(participant = df_wide$participant)  # if you want to keep participant
#   
#   results_thisQ <- tibble()  # temp tibble for each Q
#   
#   for (val in 0:9) {
#     df_imputed <- df_thisQ %>%
#       dplyr::mutate(across(-participant, ~ifelse(is.na(.), val, .)))
#     
#     alpha_val <- psych::alpha(df_imputed %>% select(-participant), check.keys = TRUE)$total$raw_alpha
#     
#     results_thisQ <- bind_rows(results_thisQ,
#                                tibble(imputed_value = val, alpha = alpha_val))
#   }
  
  # Store tibble in list with key Q1, Q2, etc.
  #alpha_results_list[[paste0("Q", Qnumber)]] <- results_thisQ
#}


# View the list
alpha_results_list


ggplot(alpha_results_list, aes(x = imputed_value, y = alpha)) +
  geom_line(color = "steelblue", linewidth = 1.2) +
  geom_point(size = 2) +
  labs(
    title = "Cronbach’s Alpha by Imputed Value (0–9)",
    x = "Value Imputed for NAs",
    y = "Cronbach’s Alpha"
  ) +
  theme_minimal()

###### SOME MVPA STUFF ########
setwd('~/Downloads')
d <- read.csv('svr_lopo_predictions.csv')
cor.test(d$y_true,d$y_pred)
m1 <- lm(y_pred ~ poly(y_true,4), data = d)
summary(m1)

plot(d$y_true,d$y_pred)
