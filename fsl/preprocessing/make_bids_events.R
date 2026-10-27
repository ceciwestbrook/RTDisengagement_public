# Ceci Westbrook, 2025
# reads in PsychoPy data for the TReW-Brain study and reformats as tsv for BIDS format.

library(stringr)
library(dplyr)
library(reshape2)

setwd("${TREW_DATA_ROOT}/sourcedata/psychopy/")
basepath <- file.path("${TREW_DATA_ROOT}/sourcedata/psychopy/")
dest_vol <- file.path("${TREW_DATA_ROOT}/rawdata/")
timing_vol <- file.path("${TREW_DATA_ROOT}/timing/")
jsonfile <- file.path("${TREW_REPO_ROOT}","events.json")

# function to make the BIDS-style tsv files
make_tsvs <- function(filename,dest_vol,jsonfile){
  subdir <- as.numeric(str_extract(filename,"[[:digit:]]+"))
  print(subdir)
  
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
        SART_out <- SART_out %>% select(onset,duration,response_time,response,correct,trial_type,corr_ans,thoughtNumber,Thought,Intensity,probenumber)
        # correct timing for start of the run
        SART_out$onset <- SART_out$onset - split$ThoughtText.started[1]
        SART_out$eventType <- "SART"
        SART_out$probenumber <- "NA"
        
        # next, get thought block data
        Thoughts_out <- split[!is.na(split$ThoughtText.started),]
        Thoughts_out$duration <- Thoughts_out$D_Cue.started - Thoughts_out$ThoughtText.started
        #correct timing for start of the run
        Thoughts_out$onset <- Thoughts_out$ThoughtText.started - split$ThoughtText.started[1]
        Thoughts_out[,c("response_time","response","correct","trial_type","corr_ans","probenumber")] <- "NA"
        Thoughts_out$response_time <- as.numeric(Thoughts_out$response_time)
        Thoughts_out <- Thoughts_out %>% select(onset,duration,response_time,response,correct,trial_type,corr_ans,thoughtNumber,Thought,Intensity,probenumber)
        Thoughts_out$eventType <- "Thoughtblock"
        
        # put SART and thought blocks together
        file_out <- rbind(SART_out,Thoughts_out) %>% arrange(onset)
        
        # Next, need thought probe data
        # Start with just the reflect
        Reflect_out <- split[!is.na(split$Reflect.started),]
        Reflect_out$duration <- Reflect_out$slider.started - Reflect_out$Reflect.started
        Reflect_out$onset <- Reflect_out$Reflect.started
        #correct timing for start of the run
        Reflect_out$onset <- Reflect_out$Reflect.started - split$ThoughtText.started[1]
        Reflect_out[,c("response_time","response","correct","trial_type","corr_ans","probenumber")] <- "NA"
        Reflect_out$response_time <- as.numeric(Reflect_out$response_time)
        Reflect_out$thoughtNumber <- Reflect_out$ThoughtNumber
        Reflect_out <- Reflect_out %>% select(onset,duration,response_time,response,correct,trial_type,corr_ans,thoughtNumber,Thought,Intensity,probenumber)
        Reflect_out$eventType <- "Reflect"
        file_out <- rbind(file_out,Reflect_out) %>% arrange(onset)
        
        # next, get the rest of the thought probes
        Probes_out <- split
        #correct timing for start of the run
        Probes_out$onset <- Probes_out$slider.started - split$ThoughtText.started[1]
        # have to do some magic to get the durations
        for(row in 1:nrow(Probes_out)){
          if(!is.na(Probes_out[row+1,"slider.started"])){
            Probes_out[row,"duration"] <- Probes_out[row+1,"slider.started"] - Probes_out[row,"slider.started"]
          }
          else if (is.na(Probes_out[row+1,"slider.started"])) {
            Probes_out[row,"duration"] <- Probes_out[row+1,"Fixation_earlyfinish.started"] - Probes_out[row,"slider.started"]
          }
        }
        Probes_out <- Probes_out[!is.na(Probes_out$slider.started),]
        Probes_out$response <- Probes_out$slider.response
        Probes_out$response_time <- as.numeric(Probes_out$slider.rt)
        Probes_out[,c("correct","trial_type","corr_ans")] <- "NA"
        Probes_out$thoughtNumber <- Probes_out$ThoughtNumber
        Probes_out <- Probes_out %>% select(onset,duration,response_time,response,correct,trial_type,corr_ans,thoughtNumber,Thought,Intensity,probenumber)
        Probes_out$eventType <- "ThoughtProbe"
        file_out <- rbind(file_out,Probes_out) %>% arrange(onset)
        
        # last, just need fixations
        Fix_out <- split
        #correct timing for start of the run
        Fix_out$onset <- Fix_out$Fixation_earlyfinish.started - split$ThoughtText.started[1]
        for(row in 1:nrow(Fix_out)){
          if(!is.na(split[row+1,"ThoughtText.started"])){
            Fix_out[row,"duration"] <- split[row+1,"ThoughtText.started"] - Fix_out[row,"Fixation_earlyfinish.started"]
          }
          else if (is.na(split[row+1,"ThoughtText.started"])) {
            Fix_out[row,"duration"] <- 2
          }
        }
        Fix_out <- Fix_out[!is.na(Fix_out$Fixation_earlyfinish.started),]
        Fix_out$thoughtNumber <- Fix_out$ThoughtNumber
        Fix_out[,c("response_time","response","correct","trial_type","corr_ans","probenumber")] <- "NA"
        Fix_out$response_time <- as.numeric(Fix_out$response_time)
        Fix_out <- Fix_out %>% select(onset,duration,response_time,response,correct,trial_type,corr_ans,thoughtNumber,Thought,Intensity,probenumber)
        Fix_out$eventType <- "Fixation"
        file_out <- rbind(file_out,Fix_out) %>% arrange(onset)
        write.table(file_out,paste0(dest_vol,"sub-",subdir,"/ses-01","/func/sub-",subdir,"_ses-01_task-PDT_run-0",i,"_events.tsv"),col.names=T,row.names = F,quote = F,sep="\t")
        
        # write out the jsons too
        file.copy(jsonfile,paste0(dest_vol,"sub-",subdir,"/ses-01","/func/sub-",subdir,"_ses-01_task-PDT_run-0",i,"_events.json"),overwrite = T)
      }
    },
    error = function(e){
      message(subdir, ":", e)
    }
  )
}

# function to write timing files and substitute with empty EVs if no data
write_timing_files <- function(infile,outpath,outname){
  zerofile <- data.frame(matrix(0L,ncol=3,nrow=1))
  if(nrow(infile)<1){
    print("empty EV")
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
  dir.create(paste0(timing_vol,subdir))
  
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
        write_timing_files(hits,timing_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_hits.txt"))
        write_timing_files(misses,timing_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_misses.txt"))
        write_timing_files(FAs,timing_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_FAs.txt"))
        write_timing_files(CRs,timing_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_CRs.txt"))
        write_timing_files(hits_RT,timing_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_hits_RT.txt"))
        write_timing_files(FAs_RT,timing_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_FAs_RT.txt"))

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
        Probes_out$onset <- Probes_out$Reflect.started
        Probes_out <- cbind(Probes_out,data.frame(offset = split[!is.na(split$Fixation_P.started),"Fixation_P.started"])[1])
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
        write_timing_files(Probes_out[,c("onset","duration","mod")],timing_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_thoughtprobeblock.txt"))

        # write out all thought probe data for future use
        write_timing_files(Probes_out,timing_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_allthoughtprobes.txt"))

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
        write_timing_files(Thoughts_out[,c("onset","duration","mod")],timing_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_thoughtblock.txt"))
        
        # will also write out thought block modulated by thought probes in the loop below
        Thoughts_modout <- Thoughts_out[,c("onset","duration")]
        
        # then let's calculate the speed/accuracy index for each SART block,
        # then write out SART block modulated by index.
        # use the same loop to write out SART and thought blocks modulated by thought probe ratings too!
        SART_nomodout <- data.frame(matrix(ncol = 3,nrow = 0))
        SART_indexout <- data.frame(matrix(ncol = 3,nrow = 0))
        SART_modout <- data.frame(matrix(ncol = 3,nrow = 0))
        colnames(SART_indexout) <- c("onset","duration","mod")
        colnames(SART_modout) <- c("onset","duration","mod")
        colnames(SART_nomodout) <- c("onset","duration","mod")
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
          
          # write out SART EV modulated by ACC
          SART_indexout[thought,"onset"] <- head(SART_out[SART_out$thought==thought,"onset"],n=1)
          SART_indexout[thought,"duration"] <- dur
          SART_indexout[thought,"mod"] <- head(SART_out[SART_out$thought==thought,"AccIndex"],n=1)
          
          # also make one modulated by thought probe
          SART_modout[thought,"onset"] <- head(SART_out[SART_out$thought==thought,"onset"],n=1)
          SART_modout[thought,"duration"] <- dur
          SART_modout[thought,"mod"] <- Probes_out[thought,"probe1"]
          
          # and the same for thought block
          Thoughts_modout[thought,"mod"] <- Probes_out[thought,"probe1"]
          
        }
        
        # write to file
        write_timing_files(SART_nomodout,timing_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_SART.txt"))
        write_timing_files(SART_indexout,timing_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_SART_ACCmod.txt"))
        write_timing_files(SART_modout,timing_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_SART_dyscontrolmod.txt"))
        write_timing_files(Thoughts_modout,timing_vol,paste0("/",subdir,"/sub-",subdir,"_run-0",i,"_Thoughtblock_dyscontrolmod.txt"))
        
      }
    },
    error = function(e){
      message(subdir, ":", e)
    }
  )
}

# make the tsv files!
for (fulldir in list.files("${TREW_DATA_ROOT}/sourcedata/psychopy/")){

  filename <- dir(file.path(basepath,fulldir), full.names=T, pattern=glob2rx("*scanner*.csv"))
  make_tsvs(filename,dest_vol,jsonfile)
  
}

searchdir <- dir(basepath, full.names=T, pattern="315")
filename <- dir(searchdir, full.names=T, pattern=glob2rx("*scanner*.csv"))
make_tsvs(filename,dest_vol,jsonfile)
make_fsl_timing_files(filename,dest_vol)

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

# there are a few that don't work right - specify the files manually
# 381
searchdir <- dir(basepath, full.names=T, pattern="381")
filename <- file.path(searchdir,"381_TREW-scannerReady_2024-08-24_15h49.29.089.csv")
make_tsvs(filename,dest_vol,jsonfile)
make_fsl_timing_files(filename,dest_vol)

# 384--only two runs. Also almost no SART responses
searchdir <- dir(basepath, full.names=T, pattern="384")
filename <- file.path(searchdir,"384_TREW-scannerReady_2024-08-27_10h10.46.048.csv")
make_tsvs(filename,dest_vol,jsonfile)
make_fsl_timing_files(filename,dest_vol)

# 387
searchdir <- dir(basepath, full.names=T, pattern="387")
filename <- file.path(searchdir,"387_TREW-scannerReady_2024-09-05_09h32.20.638.csv")
make_tsvs(filename,dest_vol,jsonfile)
make_fsl_timing_files(filename,dest_vol)

# 336
searchdir <- dir(basepath, full.names=T, pattern="336")
filename <- file.path(searchdir,"336_TREW-scannerReady_2023-12-02_10h24.02.625.csv")
make_tsvs(filename,dest_vol,jsonfile)
make_fsl_timing_files(filename,dest_vol)

# 335
searchdir <- dir(basepath, full.names=T, pattern="335")
filename <- file.path(basename(searchdir),"335_TREW-scannerReady_2023-12-05_09h56.15.560.csv")
make_tsvs(filename,dest_vol,jsonfile)
make_fsl_timing_files(filename,dest_vol)

# 368
searchdir <- dir(basepath, full.names=T, pattern="368")
filename <- file.path(searchdir,"368_TREW-scannerReady_2024-05-03_12h28.39.286.csv")
make_tsvs(filename,dest_vol,jsonfile)
make_fsl_timing_files(filename,dest_vol)

# 334
searchdir <- dir(basepath, full.names=T, pattern="334")
filename <- file.path(searchdir,"334_TREW-scannerReady_2023-12-06_14h41.07.021.csv")
make_tsvs(filename,dest_vol,jsonfile)
make_fsl_timing_files(filename,dest_vol)

# 339
searchdir <- dir(basepath, full.names=T, pattern="339")
filename <- file.path(searchdir,"339_TREW-scannerReady_2024-01-11_10h26.54.822.csv")
make_tsvs(filename,dest_vol,jsonfile)
make_fsl_timing_files(filename,dest_vol)

# problem children
# 302 - no data (sim data only)--fixed
# 304 - didn't complete all probes for all trials
# 315 - almost no RTs
# 366 - not enough probes
# 384 - only two runs, almost no SART responses
