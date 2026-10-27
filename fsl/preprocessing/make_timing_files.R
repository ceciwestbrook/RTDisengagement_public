# Ceci Westbrook, 2025
# reads in PsychoPy data for the TReW-Brain study and reformats as tsv for BIDS format.

library(stringr)
library(dplyr)
library(reshape2)

# for the original timing files with SART skill index and EOT dyscontrol as parametric modulators
setwd("${TREW_DATA_ROOT}/sourcedata/psychopy/")
basepath <- file.path("${TREW_DATA_ROOT}/sourcedata/psychopy/")
dest_vol <- file.path(Sys.getenv("TREW_DATA_ROOT", unset = "./data"))

# function to write timing files and substitute with empty EVs if no data
write_timing_files <- function(infile,outpath,outname){
  zerofile <- data.frame(matrix(0L,ncol=3,nrow=1))
  if(nrow(infile)<1){
    #print(c(outname, " empty EV"))
    write.table(zerofile,paste0(outpath,"/",outname),col.names=F,row.names = F,quote = F,sep=" ")
  }
  else{
    write.table(infile,paste0(outpath,"/",outname),col.names=F,row.names = F,quote = F,sep=" ")
  }
}

make_fsl_timing_files <- function(fulldir,dest_vol){
  subdir <- as.numeric(str_extract(fulldir,"[[:digit:]]+"))
  print(subdir)
  
  # make a directory to put them in
  dir.create(file.path(dest_vol,subdir))

  tryCatch(
    expr = {
      d <- read.csv(file.path(filename))
      
      #split into one dataframe per run
      d$run_id <- cumsum(!nzchar(d$Thought))
      ## remove blank lines
      d <- d[nzchar(d$Thought), ]
      
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
        SART_out$mod <- 1
        
        # remove trials if RT was > 3SD from subject's mean per block
        meanRT <- mean(SART_out$response_time,na.rm=T)
        SDRT <- sd(SART_out$response_time,na.rm=T)
        SART_out$outlierRT <- ifelse(SART_out$response_time > meanRT + 3*SDRT | SART_out$response_time < meanRT - 3*SDRT,
                                      1,0)
        
        SART_out <- SART_out %>% filter(outlierRT < 1 | is.na(SART_out$response_time))
        
        # now, divide into hits, misses etc. and save as onset files.
        # this way I can combine them if I want to or look at the separately.
        hits <- SART_out[SART_out$trial_type=="go" & SART_out$corr_ans==1,c("onset","duration","mod")]
        misses <- SART_out[SART_out$trial_type=="go" & SART_out$corr_ans==0,c("onset","duration","mod")]
        FAs <- SART_out[SART_out$trial_type=="nogo" & SART_out$corr_ans==0,c("onset","duration","mod")]
        CRs <- SART_out[SART_out$trial_type=="nogo" & SART_out$corr_ans==1,c("onset","duration","mod")]
        
        # also want them modified by RT, mean-centered by run.
        SART_RTs <- SART_out[!is.na(SART_out$response_time),]
        SART_RTs$mean_RT <- mean(SART_out[!is.na(SART_out$response_time),"response_time"],na.rm=T)
        
        # no RTs for misses or FAs
        hits_RT <- SART_RTs[SART_RTs$trial_type=="go" & SART_RTs$corr_ans==1,c("onset","response_time","mean_RT")]
        FAs_RT <- SART_RTs[SART_RTs$trial_type=="nogo" & SART_RTs$corr_ans==0,c("onset","response_time","mean_RT")]
        
        # write to file
        #write_timing_files(hits,dest_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_hits.txt"))
        #write_timing_files(misses,dest_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_misses.txt"))
        #write_timing_files(FAs,dest_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_FAs.txt"))
        #write_timing_files(CRs,dest_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_CRs.txt"))
        #write_timing_files(hits_RT,dest_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_hits_RT.txt"))
        #write_timing_files(FAs_RT,dest_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_FAs_RT.txt"))
        
        # Next, need thought probe data
        Probes_out <- split[!is.na(split$probenumber),]
        # filter only for vars we need
        Probes_out <- Probes_out %>% select(Thought,ThoughtNumber,Reflect.started,probenumber,slider.response)
        for(row in 1:nrow(Probes_out)){
          if(is.na(Probes_out[row,"Reflect.started"])){
            Probes_out[row,"Reflect.started"] <- Probes_out[row-1,"Reflect.started"]
          }
        }
        Probes_out <- dcast(Probes_out, Thought + ThoughtNumber + Reflect.started ~ probenumber,value.var = "slider.response") %>% arrange(Reflect.started)
        Probes_out$onset <- Probes_out$Reflect.started - split$ThoughtText.started[1]
        Probes_out <- cbind(Probes_out,data.frame(offset = split[!is.na(split$Fixation_P.started),"Fixation_P.started"])[1]- split$ThoughtText.started[1])
        Probes_out$duration <- Probes_out$offset - Probes_out$onset
        # make sure to mean-center
        Probes_out$probe1 <- as.numeric(Probes_out$`1`) - mean(as.numeric(Probes_out$`1`),na.rm=T)
        Probes_out$probe2 <- as.numeric(Probes_out$`2`) - mean(as.numeric(Probes_out$`2`),na.rm=T)
        Probes_out$probe3 <- as.numeric(Probes_out$`3`) - mean(as.numeric(Probes_out$`3`),na.rm=T)
        Probes_out$probe4 <- as.numeric(Probes_out$`4`) - mean(as.numeric(Probes_out$`4`),na.rm=T)
        Probes_out$probe5 <- as.numeric(Probes_out$`5`) - mean(as.numeric(Probes_out$`5`),na.rm=T)
        Probes_out$probe6 <- as.numeric(Probes_out$`6`) - mean(as.numeric(Probes_out$`6`),na.rm=T)
        Probes_out <- Probes_out %>% select(Thought,ThoughtNumber,onset,duration,probe1,probe2,probe3,probe4,probe5,probe6)
        Probes_out$mod <- 1
        
        # write out EV for thought probes
        #write_timing_files(Probes_out[,c("onset","duration","mod")],dest_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_thoughtprobeblock.txt"))
        
        # write out all thought probe data for future use
        #write_timing_files(Probes_out,dest_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_allthoughtprobes.txt"))
        
        # as of right now, don't plan to model thought probe block modulated by RT or any of the probes
        
        # next, get thought block data
        Thoughts_out <- split[!is.na(split$ThoughtText.started),]
        Thoughts_out$duration <- Thoughts_out$D_Cue.started - Thoughts_out$ThoughtText.started
        #correct timing for start of the run
        Thoughts_out$onset <- Thoughts_out$ThoughtText.started - split$ThoughtText.started[1]
        Thoughts_out[,c("response","correct","trial_type","corr_ans")] <- "NA"
        Thoughts_out <- Thoughts_out %>% select(onset,duration,thoughtNumber,Thought)
        Thoughts_out$mod <- 1
        
        # write out EV for thought block
        #write_timing_files(Thoughts_out[,c("onset","duration","mod")],dest_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_thoughtblock.txt"))
        
        # will also write out thought block modulated by thought probes in the loop below
        Thoughts_modout <- Thoughts_out[,c("onset","duration")]
        
        # then let's calculate the speed/accuracy index for each SART block,
        # then write out SART block modulated by index.
        # use the same loop to write out SART and thought blocks modulated by thought probe ratings too!
        SART_nomodout <- data.frame(matrix(ncol = 3,nrow = 0))
        SART_indexout <- data.frame(matrix(ncol = 3,nrow = 0))
        SART_modout <- data.frame(matrix(ncol = 3,nrow = 0))
        SART_effort <- data.frame(matrix(ncol = 3,nrow = 0))
        SART_meanRTmodout <- data.frame(matrix(ncol = 3,nrow = 0))
        colnames(SART_indexout) <- c("onset","duration","mod")
        colnames(SART_modout) <- c("onset","duration","mod")
        colnames(SART_effort) <- c("onset","duration","mod")
        colnames(SART_nomodout) <- c("onset","duration","mod")
        colnames(SART_meanRTmodout) <- c("onset","duration","mod")
        for(thought in SART_out$thoughtNumber){
          # calculate index
          NoGo_ACC <- mean(SART_out[SART_out$thoughtNumber==thought & SART_out$trial_type=="nogo","corr_ans"])
          Mean_go_RT <- mean(SART_out[SART_out$thoughtNumber==thought & SART_out$trial_type=="go","response_time"],na.rm=T)
          AccIndex <- NoGo_ACC/(Mean_go_RT*100)*100
          SART_out[SART_out$thought==thought,"AccIndex"] <- AccIndex
        }
        #need to break out of the loop to get the mean centering for the whole run, then back into it:
        SART_out$AccIndex <- SART_out$AccIndex - mean(SART_out$AccIndex,na.rm=T)
        
        for(thought in SART_out$thoughtNumber){
          # calculate total SART block duration
          dur <- sum(SART_out[SART_out$thought==thought,"duration"])
          
          # write out SART EV
          SART_nomodout[thought,"onset"] <- head(SART_out[SART_out$thought==thought,"onset"],n=1)
          SART_nomodout[thought,"duration"] <- dur
          SART_nomodout[thought,"mod"] <- 1
          
          # write out SART EV with mean RT
          SART_meanRTmodout[thought,"onset"] <- head(SART_out[SART_out$thought==thought,"onset"],n=1)
          SART_meanRTmodout[thought,"duration"] <- dur
          SART_meanRTmodout[thought,"mod"] <- meanRT
          
          # write out SART EV modulated by ACC
          SART_indexout[thought,"onset"] <- head(SART_out[SART_out$thought==thought,"onset"],n=1)
          SART_indexout[thought,"duration"] <- dur
          SART_indexout[thought,"mod"] <- head(SART_out[SART_out$thought==thought,"AccIndex"],n=1)
          
          # also make one modulated by thought probe
          SART_modout[thought,"onset"] <- head(SART_out[SART_out$thought==thought,"onset"],n=1)
          SART_modout[thought,"duration"] <- dur
          SART_modout[thought,"mod"] <- Probes_out[thought,"probe1"]
          
          # and effort
          SART_effort[thought,"onset"] <- head(SART_out[SART_out$thought==thought,"onset"],n=1)
          SART_effort[thought,"duration"] <- dur
          SART_effort[thought,"mod"] <- Probes_out[thought,"probe3"]
          
          # and the same for thought block
          Thoughts_modout[thought,"mod"] <- Probes_out[thought,"probe1"]
          
        }
        
        SART_index_missed <- SART_indexout %>% filter(is.na(mod))
        if(nrow(SART_index_missed) > 0) {
          print(c(subdir, "found SART missed trials"))
          SART_index_missed$mod <- 1
        }
        SART_indexout <- SART_indexout %>% filter(!is.na(mod))
        
        SART_dc_missed <- SART_modout %>% filter(is.na(mod))
        if(nrow(SART_dc_missed) > 0) {
          print(c(subdir, "found DC missed trials"))
          SART_dc_missed$mod <- 1
        }
        SART_modout <- SART_modout %>% filter(!is.na(mod))
        
        SART_effort_missed <- SART_effort %>% filter(is.na(mod))
        if(nrow(SART_effort_missed) > 0) {
          SART_effort_missed$mod <- 1
        }
        SART_effort <- SART_effort %>% filter(!is.na(mod))
        
        Thought_dc_missed <- Thoughts_modout %>% filter(is.na(mod))
        if(nrow(Thought_dc_missed) > 0) {
          Thought_dc_missed$mod <- 1
        }
        Thoughts_modout <- Thoughts_modout %>% filter(!is.na(mod))
        
        # write to file
        #write_timing_files(SART_nomodout,dest_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_SART.txt"))
        #write_timing_files(SART_meanRTmodout,dest_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_SART_meanRTmod.txt"))
        #write_timing_files(SART_indexout,dest_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_SART_ACCmod.txt"))
        #write_timing_files(SART_modout,dest_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_SART_dyscontrolmod.txt"))
        #write_timing_files(SART_effort,dest_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_SART_effortmod.txt"))
        #write_timing_files(Thoughts_modout,dest_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_Thoughtblock_dyscontrolmod.txt"))
        
        #write_timing_files(SART_index_missed,dest_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_SART_ACC_missedtrials.txt"))
        #write_timing_files(SART_dc_missed,dest_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_SART_dyscontrolmod_missedtrials.txt"))
        #write_timing_files(SART_effort_missed,dest_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_SART_effortmod_missedtrials.txt"))
        #write_timing_files(Thought_dc_missed,dest_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_Thoughts_dyscontrolmod_missedtrials.txt"))
        
      }
    },
    error = function(e){
      message(subdir, ":", e)
    }
  )
}


# make the timing files!
for (fulldir in list.files("${TREW_DATA_ROOT}/sourcedata/psychopy/")){
  
  filename <- dir(file.path(basepath,fulldir), full.names=T, pattern=glob2rx("*scanner*.csv"))
  tryCatch(
    expr = {
      make_fsl_timing_files(filename,dest_vol)
    },
    error = function(y){
      message(y)
    }
  )
}

searchdir <- dir(basepath, full.names=T, pattern="342")
filename <- dir(searchdir, full.names=T, pattern=glob2rx("*scanner*.csv"))
make_fsl_timing_files(filename,dest_vol)

# there are a few that don't work right - specify the files manually
# 381
searchdir <- dir(basepath, full.names=T, pattern="381")
filename <- file.path(searchdir,"381_TREW-scannerReady_2024-08-24_15h49.29.089.csv")
make_fsl_timing_files(filename,dest_vol)

# 384--only two runs. Also almost no SART responses
searchdir <- dir(basepath, full.names=T, pattern="384")
filename <- file.path(searchdir,"384_TREW-scannerReady_2024-08-27_10h10.46.048.csv")
make_fsl_timing_files(filename,dest_vol)

# 387
searchdir <- dir(basepath, full.names=T, pattern="387")
filename <- file.path(searchdir,"387_TREW-scannerReady_2024-09-05_09h32.20.638.csv")
make_fsl_timing_files(filename,dest_vol)

# 336
searchdir <- dir(basepath, full.names=T, pattern="336")
filename <- file.path(searchdir,"336_TREW-scannerReady_2023-12-02_10h24.02.625.csv")
make_fsl_timing_files(filename,dest_vol)

# 335
searchdir <- dir(basepath, full.names=T, pattern="335")
filename <- file.path(searchdir,"335_TREW-scannerReady_2023-12-05_09h56.15.560.csv")
make_fsl_timing_files(filename,dest_vol)

# 368
searchdir <- dir(basepath, full.names=T, pattern="368")
filename <- file.path(searchdir,"368_TREW-scannerReady_2024-05-03_12h28.39.286.csv")
make_fsl_timing_files(filename,dest_vol)

# 334
searchdir <- dir(basepath, full.names=T, pattern="334")
filename <- file.path(searchdir,"334_TREW-scannerReady_2023-12-06_14h41.07.021.csv")
make_fsl_timing_files(filename,dest_vol)

# 339
searchdir <- dir(basepath, full.names=T, pattern="339")
filename <- file.path(searchdir,"339_TREW-scannerReady_2024-01-11_10h26.54.822.csv")
make_fsl_timing_files(filename,dest_vol)

# problem children
# 302 - no data (sim data only)--fixed
# 304 - didn't complete all probes for all trials
# 315 - almost no RTs
# 366 - not enough probes
# 384 - only two runs, almost no SART responses

########################################################################################################################
########################################################################################################################
########################################################################################################################
########################################################################################################################

# to make the timing files with the a priori dyscontrol ratings
localdir <- Sys.getenv("TREW_REPO_ROOT", unset = ".")
filedir <- file.path(localdir,"behav_analyses")
timing_vol <- file.path(localdir,"PTD_timingfiles/fsl_level1_timingfiles_censorRT")
#load(file.path(filedir,"TReWBehavDataAll.Rdata"))
# make the composite dyscontrol measure
# no imputation
alldata$dyscontrol <- rowMeans(alldata[,c("Q3_1","Q3_2","Q3_3")],na.rm=T)
alldata$Q3_1_imputed <- ifelse(is.na(alldata$Q3_1),0,alldata$Q3_1)
alldata$Q3_2_imputed <- ifelse(is.na(alldata$Q3_2),0,alldata$Q3_2)
alldata$Q3_3_imputed <- ifelse(is.na(alldata$Q3_3),0,alldata$Q3_3)
alldata$dyscontrol_imputed <- rowMeans(alldata[,c("Q3_1_imputed","Q3_2_imputed","Q3_3_imputed")],na.rm=T)

make_dyscontrol_timing_files <- function(searchdir,filename){
  subdir <- as.numeric(str_extract(searchdir,"[[:digit:]]+"))
  print(subdir)
  fulldir <- basename(searchdir)
  fullsub <- strsplit(fulldir,"_")[[1]][1]
  
  # make a directory to put them in
  dir.create(paste0(timing_vol,"/",subdir))
  
  tryCatch(
    expr = {
      d <- read.csv(file.path(searchdir,filename))
      
      #split into one dataframe per run
      d$run_id <- cumsum(!nzchar(d$Thought))
      ## remove blank lines
      d <- d[nzchar(d$Thought), ]
      
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
        SART_out$mod <- 1
        
        # remove trials if RT was > 3SD from subject's mean per block
        meanRT <- mean(SART_out$response_time,na.rm=T)
        SDRT <- sd(SART_out$response_time,na.rm=T)
        SART_out$outlierRT <- ifelse(SART_out$response_time > meanRT + 3*SDRT | SART_out$response_time < meanRT - 3*SDRT,
                                     1,0)
        
        SART_out <- SART_out %>% filter(outlierRT < 1 | is.na(SART_out$response_time))
        
        # Next, need thought probe data
        Probes_out <- split[!is.na(split$probenumber),]
        # filter only for vars we need
        Probes_out <- Probes_out %>% select(Thought,ThoughtNumber,Reflect.started,probenumber,slider.response)
        for(row in 1:nrow(Probes_out)){
          if(is.na(Probes_out[row,"Reflect.started"])){
            Probes_out[row,"Reflect.started"] <- Probes_out[row-1,"Reflect.started"]
          }
        }
        Probes_out <- dcast(Probes_out, Thought + ThoughtNumber + Reflect.started ~ probenumber,value.var = "slider.response") %>% arrange(Reflect.started)
        Probes_out$onset <- Probes_out$Reflect.started - split$ThoughtText.started[1]
        Probes_out <- cbind(Probes_out,data.frame(offset = split[!is.na(split$Fixation_P.started),"Fixation_P.started"])[1]- split$ThoughtText.started[1])
        Probes_out$duration <- Probes_out$offset - Probes_out$onset
        # add in the dyscontrol ratings
        Probes_out <- merge.data.frame(Probes_out,
                         alldata[alldata$participant==subdir & alldata$run==i,c("ThoughtNumber","dyscontrol_imputed")],
                         by = "ThoughtNumber")
        # make sure to mean-center
        Probes_out$probe1 <- as.numeric(Probes_out$`1`) - mean(as.numeric(Probes_out$`1`),na.rm=T)
        Probes_out$probe2 <- as.numeric(Probes_out$`2`) - mean(as.numeric(Probes_out$`2`),na.rm=T)
        Probes_out$probe3 <- as.numeric(Probes_out$`3`) - mean(as.numeric(Probes_out$`3`),na.rm=T)
        Probes_out$probe4 <- as.numeric(Probes_out$`4`) - mean(as.numeric(Probes_out$`4`),na.rm=T)
        Probes_out$probe5 <- as.numeric(Probes_out$`5`) - mean(as.numeric(Probes_out$`5`),na.rm=T)
        Probes_out$probe6 <- as.numeric(Probes_out$`6`) - mean(as.numeric(Probes_out$`6`),na.rm=T)
        Probes_out <- Probes_out %>% select(Thought,ThoughtNumber,onset,duration,probe1,probe2,probe3,probe4,probe5,probe6,dyscontrol_imputed)
        Probes_out$mod <- 1
        
        # next, get thought block data
        Thoughts_out <- split[!is.na(split$ThoughtText.started),]
        Thoughts_out$duration <- Thoughts_out$D_Cue.started - Thoughts_out$ThoughtText.started
        #correct timing for start of the run
        Thoughts_out$onset <- Thoughts_out$ThoughtText.started - split$ThoughtText.started[1]
        Thoughts_out[,c("response","correct","trial_type","corr_ans")] <- "NA"
        Thoughts_out <- Thoughts_out %>% select(onset,duration,thoughtNumber,Thought)
        Thoughts_out$mod <- 1
       
        # will also write out thought block modulated by thought probes in the loop below
        Thoughts_modout <- Thoughts_out[,c("onset","duration")]
        
        # now to add in the dyscontrol mod
        SART_modout <- data.frame(matrix(ncol = 3,nrow = 0))
        colnames(SART_modout) <- c("onset","duration","mod")
        for(thought in SART_out$thoughtNumber){
          # calculate total SART block duration
          dur <- sum(SART_out[SART_out$thought==thought,"duration"])

          # also make one modulated by thought probe
          SART_modout[thought,"onset"] <- head(SART_out[SART_out$thought==thought,"onset"],n=1)
          SART_modout[thought,"duration"] <- dur
          SART_modout[thought,"mod"] <- Probes_out[thought,"dyscontrol_imputed"]
          
          # and the same for thought block
          Thoughts_modout[thought,"mod"] <- Probes_out[thought,"dyscontrol_imputed"]
          
        }
        
        SART_dc_missed <- SART_modout %>% filter(is.na(mod))
        if(nrow(SART_dc_missed) > 0) {
          SART_dc_missed$mod <- 1
        }
        SART_modout <- SART_modout %>% filter(!is.na(mod))
        
        Thought_dc_missed <- Thoughts_modout %>% filter(is.na(mod))
        if(nrow(Thought_dc_missed) > 0) {
          Thought_dc_missed$mod <- 1
        }
        Thoughts_modout <- Thoughts_modout %>% filter(!is.na(mod))
        
        # write to file
        #write_timing_files(SART_modout,timing_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_SART_indivthoughtmod.txt"))
        #write_timing_files(Thoughts_modout,timing_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_Thoughtblock_indivthoughtmod.txt"))
        
        #write_timing_files(SART_dc_missed,timing_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_SART_indivthoughtmod_missedtrials.txt"))
        #write_timing_files(Thought_dc_missed,timing_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_Thoughts_indivthoughtmod_missedtrials.txt"))
        
      }
    },
    error = function(e){
      message(subdir, ":", e)
    }
  )
}

searchdir <- dir(basepath, full.names=T, pattern="356")
fulldir <- basename(searchdir)
filename <- basename(dir(searchdir, full.names=T, pattern=glob2rx("*scanner*.csv")))
make_dyscontrol_timing_files(searchdir,filename)


# make the timing files!
for (fulldir in list.files("${TREW_DATA_ROOT}/sourcedata/psychopy/")){
  
  searchdir <- file.path(basepath,fulldir)
  filename <- basename(dir(searchdir, full.names=T, pattern=glob2rx("*scanner*.csv")))
  tryCatch(
    expr = {
      make_dyscontrol_timing_files(searchdir,filename)
    },
    error = function(y){
      message(y)
    }
  )
}

# there are a few that don't work right - specify the files manually
# 381
searchdir <- dir(basepath, full.names=T, pattern="381")
filename <- basename(file.path(searchdir,"381_TREW-scannerReady_2024-08-24_15h49.29.089.csv"))
make_dyscontrol_timing_files(searchdir,filename)

# 336
searchdir <- dir(basepath, full.names=T, pattern="336")
filename <- basename(file.path(searchdir,"336_TREW-scannerReady_2023-12-02_10h24.02.625.csv"))
make_dyscontrol_timing_files(searchdir,filename)

# 335
searchdir <- dir(basepath, full.names=T, pattern="335")
filename <- basename(file.path(searchdir,"335_TREW-scannerReady_2023-12-05_09h56.15.560.csv"))
make_dyscontrol_timing_files(searchdir,filename)

# 368
searchdir <- dir(basepath, full.names=T, pattern="368")
filename <- basename(file.path(searchdir,"368_TREW-scannerReady_2024-05-03_12h28.39.286.csv"))
make_dyscontrol_timing_files(searchdir,filename)

# 334
searchdir <- dir(basepath, full.names=T, pattern="334")
filename <- basename(file.path(searchdir,"334_TREW-scannerReady_2023-12-06_14h41.07.021.csv"))
make_dyscontrol_timing_files(searchdir,filename)

# 339
searchdir <- dir(basepath, full.names=T, pattern="339")
filename <- basename(file.path(searchdir,"339_TREW-scannerReady_2024-01-11_10h26.54.822.csv"))
make_dyscontrol_timing_files(searchdir,filename)

# problem children
# 304 - didn't complete all probes for all trials
# 315 - almost no RTs
# 366 - not enough probes
# 384 - only two runs, almost no SART responses

########################################################################################################################
########################################################################################################################
########################################################################################################################
########################################################################################################################

# just for getting outliers
get_all_outlier_RTs <- function(fulldir,dest_vol){
  subdir <- as.numeric(str_extract(fulldir,"[[:digit:]]+"))
  print(subdir)
  
  # make a directory to put them in
  dir.create(paste0(timing_vol,subdir))
  
  suboutliers <- data.frame()
  tryCatch(
    expr = {
      d <- read.csv(file.path(filename))
      
      #split into one dataframe per run
      d$run_id <- cumsum(!nzchar(d$Thought))
      ## remove blank lines
      d <- d[nzchar(d$Thought), ]
      
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
        SART_out$mod <- 1
        
        # remove trials if RT was > 3SD from subject's mean per block
        meanRT <- mean(SART_out$response_time,na.rm=T)
        SDRT <- sd(SART_out$response_time,na.rm=T)
        SART_out$outlierRT <- ifelse(SART_out$response_time > meanRT + 3*SDRT | SART_out$response_time < meanRT - 3*SDRT,
                                     1,0)
        
        SART_outliers <- SART_out %>% filter(outlierRT > 0)
        #SART_out <- SART_out %>% filter(outlierRT <= 0 | is.na(response_time))
        if(nrow(SART_outliers>0)){
          SART_outliers$participant <- subdir
          SART_outliers$meanRT <- meanRT
        }
       
        suboutliers <- rbind(suboutliers,SART_outliers)
        
        SART_nomodout <- data.frame(matrix(ncol = 3,nrow = 0))
        SART_indexout <- data.frame(matrix(ncol = 3,nrow = 0))
        SART_modout <- data.frame(matrix(ncol = 3,nrow = 0))
        SART_meanRTmodout <- data.frame(matrix(ncol = 3,nrow = 0))
        colnames(SART_indexout) <- c("onset","duration","mod")
        colnames(SART_modout) <- c("onset","duration","mod")
        colnames(SART_nomodout) <- c("onset","duration","mod")
        colnames(SART_meanRTmodout) <- c("onset","duration","mod")
        for(thought in SART_out$thoughtNumber){
          # calculate index
          NoGo_ACC <- mean(SART_out[SART_out$thoughtNumber==thought & SART_out$trial_type=="nogo","corr_ans"])
          Mean_go_RT <- mean(SART_out[SART_out$thoughtNumber==thought & SART_out$trial_type=="go","response_time"],na.rm=T)
          AccIndex <- NoGo_ACC/(Mean_go_RT*100)*100
          SART_out[SART_out$thought==thought,"AccIndex"] <- AccIndex
        }
        #need to break out of the loop to get the mean centering for the whole run, then back into it:
        SART_out$AccIndex <- SART_out$AccIndex - mean(SART_out$AccIndex,na.rm=T)
        
        for(thought in SART_out$thoughtNumber){
          # calculate total SART block duration
          dur <- sum(SART_out[SART_out$thought==thought,"duration"])
          
          # write out SART EV
          SART_nomodout[thought,"onset"] <- head(SART_out[SART_out$thought==thought,"onset"],n=1)
          SART_nomodout[thought,"duration"] <- dur
          SART_nomodout[thought,"mod"] <- 1
          
          # write out SART EV with mean RT
          SART_meanRTmodout[thought,"onset"] <- head(SART_out[SART_out$thought==thought,"onset"],n=1)
          SART_meanRTmodout[thought,"duration"] <- dur
          SART_meanRTmodout[thought,"mod"] <- meanRT
          
          # write out SART EV modulated by ACC
          SART_indexout[thought,"onset"] <- head(SART_out[SART_out$thought==thought,"onset"],n=1)
          SART_indexout[thought,"duration"] <- dur
          SART_indexout[thought,"mod"] <- head(SART_out[SART_out$thought==thought,"AccIndex"],n=1)
          
          # also make one modulated by thought probe
          SART_modout[thought,"onset"] <- head(SART_out[SART_out$thought==thought,"onset"],n=1)
          SART_modout[thought,"duration"] <- dur
          SART_modout[thought,"mod"] <- Probes_out[thought,"probe1"]
          
        }
        
      }
    },
    error = function(e){
      message(subdir, ":", e)
    }
  )
  return(suboutliers)
}

searchdir <- dir(basepath, full.names=T, pattern="374")
filename <- dir(searchdir, full.names=T, pattern=glob2rx("*scanner*.csv"))

# make the outlier dataframe
alloutliers <- data.frame()
for (fulldir in list.files("${TREW_DATA_ROOT}/sourcedata/psychopy/")){
  
  filename <- dir(file.path(basepath,fulldir), full.names=T, pattern=glob2rx("*scanner*.csv"))
  tryCatch(
    expr = {
      alloutliers <- rbind(alloutliers,get_all_outlier_RTs(filename,dest_vol))
    },
    error = function(y){
      message(y)
    }
  )
}

# 381
searchdir <- dir(basepath, full.names=T, pattern="381")
filename <- file.path(searchdir,"381_TREW-scannerReady_2024-08-24_15h49.29.089.csv")
alloutliers <- rbind(alloutliers,get_all_outlier_RTs(filename,dest_vol))

# 384--only two runs. Also almost no SART responses
searchdir <- dir(basepath, full.names=T, pattern="384")
filename <- file.path(searchdir,"384_TREW-scannerReady_2024-08-27_10h10.46.048.csv")
alloutliers <- rbind(alloutliers,get_all_outlier_RTs(filename,dest_vol))

# 387
searchdir <- dir(basepath, full.names=T, pattern="387")
filename <- file.path(searchdir,"387_TREW-scannerReady_2024-09-05_09h32.20.638.csv")
alloutliers <- rbind(alloutliers,get_all_outlier_RTs(filename,dest_vol))

# 336
searchdir <- dir(basepath, full.names=T, pattern="336")
filename <- file.path(searchdir,"336_TREW-scannerReady_2023-12-02_10h24.02.625.csv")
alloutliers <- rbind(alloutliers,get_all_outlier_RTs(filename,dest_vol))

# 335
searchdir <- dir(basepath, full.names=T, pattern="335")
filename <- file.path(basename(searchdir),"335_TREW-scannerReady_2023-12-05_09h56.15.560.csv")
alloutliers <- rbind(alloutliers,get_all_outlier_RTs(filename,dest_vol))

# 368
searchdir <- dir(basepath, full.names=T, pattern="368")
filename <- file.path(searchdir,"368_TREW-scannerReady_2024-05-03_12h28.39.286.csv")
alloutliers <- rbind(alloutliers,get_all_outlier_RTs(filename,dest_vol))

# 334
searchdir <- dir(basepath, full.names=T, pattern="334")
filename <- file.path(searchdir,"334_TREW-scannerReady_2023-12-06_14h41.07.021.csv")
alloutliers <- rbind(alloutliers,get_all_outlier_RTs(filename,dest_vol))

# 339
searchdir <- dir(basepath, full.names=T, pattern="339")
filename <- file.path(searchdir,"339_TREW-scannerReady_2024-01-11_10h26.54.822.csv")
alloutliers <- rbind(alloutliers,get_all_outlier_RTs(filename,dest_vol))

# writing out for mvpa
write.table(alldata[,c("participant","run","ThoughtNumber","dyscontrol","dyscontrol_imputed")],
            file.path(dest_vol,"dyscontrol_for_mvpa.txt"),quote=FALSE,row.names = F,sep = "\t")


# figuring out whether people with missed trials for SART also have them for dyscontrol.
# turns out only 2 subjects that we're using (342 and 381) have missed SART trials, and
# only 2 subjects that we're using (342 - same trial and 386) have missing dyscontrol trials.
# So, can safely just remove those trials for those participants
# ACTUALLY: since the missed trials are already covered by the vanilla task regressor,
# don't need the missed trial regressor at all! Will just exclude.
for(subdir in list.files(timing_vol)){
  for(run in c(1,2,3)){
    tryCatch(
      expr = {
        suppressMessages(SARTfile <- read_csv(paste0(timing_vol,"/",subdir,"/sub-",subdir,"_run-0",run,"_SART_ACC_missedtrials.txt")))
        if(nrow(SARTfile) > 0){
          print(c("SART: ",subdir,run,nrow(SARTfile)))
        }
          suppressMessages(dcfile <- read_csv(paste0(timing_vol,"/",subdir,"/sub-",subdir,"_run-0",run,"_SART_dyscontrolmod_missedtrials.txt")))
          if(nrow(dcfile) > 0){
            print(c("dyscontrol: ",subdir,run,nrow(dcfile)))
        }
      },
      error = function(e){
        message(subdir, ":", e)
      }
    )
    
  }
}
