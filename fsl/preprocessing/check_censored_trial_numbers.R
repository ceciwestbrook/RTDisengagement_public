# Ceci Westbrook, 2022
# This script cross-references the censor file TRs against the TRs of the trial start times
# to make sure we didn't censor out too many trials!

library(gdata)
library(tidyverse)
setwd('${TREW_REPO_ROOT}/fsl/')
allsubs <- read.csv('imaging_subjects.txt')
setwd('${TREW_REPO_ROOT}/fsl/level1/fsl_level1_timingfiles/')

# for debugging
#allsubs = data.frame(2163)

allsubdata <- data.frame(data.frame(matrix(ncol = 5, nrow = 0)))
for(subject in allsubs[,]){
  subDir <- paste0('${TREW_REPO_ROOT}/fsl/level1/fsl_level1_timingfiles/sub-',subject)
  preprocessedDir <- paste0('${TREW_DATA_ROOT}/preprocessed/sub-',subject)
    for(run in c(1,2)){
      possibleError <- tryCatch(assign("censors",read.table(paste0(preprocessedDir,'/ses-01/func/sub-',subject,
                                   '_ses-01_task-PDT_run-0',run,
                                   '_desc-confounds_timeseries.tsv'),
                            sep="\t",header=TRUE)),error = function(x) x)
      censors <- censors[,c("framewise_displacement","std_dvars")]
      censors$framewise_displacement <- as.numeric(as.character(censors$framewise_displacement))
      censors$std_dvars <- as.numeric(as.character(censors$std_dvars))
      censors <- censors[!is.na(censors$framewise_displacement),]
      spikes <- as.numeric(row.names(censors[censors$framewise_displacement>=0.9 | censors$std_dvars>=3,]))
      for(condition in c('Approach','Avoid','AmbigApproach','AmbigAvoid','XResponse')){
        assign("filename",data.frame(V1=NA,censored=NA))
        filename <- paste0(condition,'2sResponse')
        possibleError <- tryCatch(assign(filename,read.csv(
          paste(subDir,'/ses-',session,'/sub-',subject,'_ses-',session,'_FSLtiming-',filename,'_run-0',run,'.txt',
                sep=""),sep=" ",header=FALSE)),error = function(x) x)
        curfile <- get(filename)[1]
        curfile <- round(curfile/2) + 1
        curfile$censored <- 0
        for(i in 1:nrow(curfile)) {
          if(curfile[i,1] %in% spikes) {
            curfile[i,"censored"] <- 1
          }
        }
        assign(paste0(condition,session,run,'_onsets'),curfile)
      }
  }
  alldata <- data.frame(data.frame(matrix(ncol = 5, nrow = 0)))
  for(condition in c('Approach','Avoid','AmbigApproach','AmbigAvoid','XResponse')){
    assign("precondition",rbind(get(paste0(condition,'pretreatment1_onsets')),get(paste0(condition,'pretreatment2_onsets'))))
    precondition$subject <- subject
    precondition$condition <- condition
    precondition$session <- "pretreatment"
    assign("postcondition",rbind(get(paste0(condition,'posttreatment1_onsets')),get(paste0(condition,'posttreatment2_onsets'))))
    postcondition$subject <- subject
    postcondition$condition <- condition
    postcondition$session <- "posttreatment"
    allcondition <- rbind(precondition,postcondition)
    alldata <- rbind(alldata,allcondition)
  }
  allsubdata <- rbind(allsubdata,alldata)
}

# all the data!
allsubdata %>% group_by(c(subject,condition))

# to get which runs are usable/excluded
setwd('/ix/cladouceur/westbrook-data/Scripts/level2/make_fsfs/')
for(cope in c("cope1","cope2","cope3","cope4","cope5","cope6","cope7","cope8")) {
  for(session in c("pre","post")){
    c1 <- read.table(paste0(cope,session,"run1run2.txt"))
    c2 <- read.table(paste0(cope,session,"run1run1.txt"))
    c3 <- read.table(paste0(cope,session,"run2run2.txt"))
    towrite <- rbind(c1,c2,c3)
    towrite$sub <- 1
    colnames(towrite) <- c("ID_Num",paste0(cope,session,"_subs"))
    assign(paste0(cope,session),towrite)
  }
}

censortable_pre <- table(allsubdata[allsubdata$session=="pretreatment",c("subject","condition","censored")])
censorno_pre <- data.frame(censortable_pre[,,1])
censorno_pre$usable <- 0
censorno_pre[censorno_pre$subject %in% cope1pre$ID_Num & censorno_pre$condition=="Approach","usable"] <- 1
censorno_pre[censorno_pre$subject %in% cope2pre$ID_Num & censorno_pre$condition=="Avoid","usable"] <- 1
censorno_pre[censorno_pre$subject %in% cope3pre$ID_Num & censorno_pre$condition=="AmbigApproach","usable"] <- 1
censorno_pre[censorno_pre$subject %in% cope4pre$ID_Num & censorno_pre$condition=="AmbigAvoid","usable"] <- 1
censorno_pre <- censorno_pre[order(censorno_pre$subject),]

mean(censorno_pre[censorno_pre$condition=="Approach" & censorno_pre$usable==1,"Freq"])
range(censorno_pre[censorno_pre$condition=="Approach" & censorno_pre$usable==1,"Freq"])
table(censorno_pre[censorno_pre$condition=="Approach" & censorno_pre$usable==1,"Freq"])
mean(censorno_pre[censorno_pre$condition=="Avoid" & censorno_pre$usable==1,"Freq"])
range(censorno_pre[censorno_pre$condition=="Avoid" & censorno_pre$usable==1,"Freq"])
table(censorno_pre[censorno_pre$condition=="Avoid" & censorno_pre$usable==1,"Freq"])
mean(censorno_pre[censorno_pre$condition=="AmbigApproach" & censorno_pre$usable==1,"Freq"])
range(censorno_pre[censorno_pre$condition=="AmbigApproach" & censorno_pre$usable==1,"Freq"])
table(censorno_pre[censorno_pre$condition=="AmbigApproach" & censorno_pre$usable==1,"Freq"])
mean(censorno_pre[censorno_pre$condition=="AmbigAvoid" & censorno_pre$usable==1,"Freq"])
range(censorno_pre[censorno_pre$condition=="AmbigAvoid" & censorno_pre$usable==1,"Freq"])
table(censorno_pre[censorno_pre$condition=="AmbigAvoid" & censorno_pre$usable==1,"Freq"])

censoryes_pre <- data.frame(censortable_pre[,,2])
censoryes_pre$usable <- 0
censoryes_pre[censoryes_pre$subject %in% cope1pre$ID_Num & censoryes_pre$condition=="Approach","usable"] <- 1
censoryes_pre[censoryes_pre$subject %in% cope2pre$ID_Num & censoryes_pre$condition=="Avoid","usable"] <- 1
censoryes_pre[censoryes_pre$subject %in% cope3pre$ID_Num & censoryes_pre$condition=="AmbigApproach","usable"] <- 1
censoryes_pre[censoryes_pre$subject %in% cope4pre$ID_Num & censoryes_pre$condition=="AmbigAvoid","usable"] <- 1
censoryes_pre <- censoryes_pre[order(censoryes_pre$subject),]

mean(censoryes_pre[censoryes_pre$condition=="Approach" & censoryes_pre$usable==1,"Freq"])
range(censoryes_pre[censoryes_pre$condition=="Approach" & censoryes_pre$usable==1,"Freq"])
table(censoryes_pre[censoryes_pre$condition=="Approach" & censoryes_pre$usable==1,"Freq"])
mean(censoryes_pre[censoryes_pre$condition=="Avoid" & censoryes_pre$usable==1,"Freq"])
range(censoryes_pre[censoryes_pre$condition=="Avoid" & censoryes_pre$usable==1,"Freq"])
table(censoryes_pre[censoryes_pre$condition=="Avoid" & censoryes_pre$usable==1,"Freq"])
mean(censoryes_pre[censoryes_pre$condition=="AmbigApproach" & censoryes_pre$usable==1,"Freq"])
range(censoryes_pre[censoryes_pre$condition=="AmbigApproach" & censoryes_pre$usable==1,"Freq"])
table(censoryes_pre[censoryes_pre$condition=="AmbigApproach" & censoryes_pre$usable==1,"Freq"])
mean(censoryes_pre[censoryes_pre$condition=="AmbigAvoid" & censoryes_pre$usable==1,"Freq"])
range(censoryes_pre[censoryes_pre$condition=="AmbigAvoid" & censoryes_pre$usable==1,"Freq"])
table(censoryes_pre[censoryes_pre$condition=="AmbigAvoid" & censoryes_pre$usable==1,"Freq"])

setwd('/ix/cladouceur/westbrook-data/Scripts/group_level/')
write_csv2(censorno_pre,'uncensored_trials_pretreatment.csv')
write_csv2(censoryes_pre,'censored_trials_pretreatment.csv')
