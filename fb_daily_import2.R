## nohup R CMD BATCH --no-save --no-restore fb_daily_import2.R  /home/poleinikov/FB_reports/Logs/daily_import_$(date +%Y-%m-%d).txt &

library(readr)
library(dplyr)
library(RMySQL)

source("read_fb_file.R")

conn = dbConnect(RMySQL::MySQL(), host="xxx.xxx.xx.xx", ## replace with IP address of the host or 'localhost'
                 user="xxxx", password="xxxx",
                 dbname="dbase1")

d = dbGetQuery(conn, "select distinct date from fb_daily")

data_files = list.files(path="./FB_reports/Daily", 
                        pattern="FacebookAdLibraryReport_.*_US_yesterday.zip",
                        full.names = T)

p = "20[12][0-9]-[0-9]{2}-[0-9]{2}"
x = gregexpr(p, data_files)
report_date = unlist(regmatches(data_files, x))

df = data.frame(fname = data_files,
                report_date = report_date,
                stringsAsFactors = F)

## the first date when FB included page_id was 06/06/2019
## we are restarting the DB with the 01/06/2021 - day after Georgia run-off elections
df = df %>% filter(report_date >= "2021-01-06")

## get only the dates that have not been uploaded yet
df = df %>% anti_join(d, by=c("report_date"="date"))

## unzip the file into a tmp directory
## read the file
## import into MySQL
## remove all files in the tmp directory
if (nrow(df) > 0) {
  for (j in 1:nrow(df)) {
    
    cat("Processing file", df$fname[j], "\n")
    ## clean up the tmp directory
    ## First, remove files in the regions folder
    previous_files = list.files(path="./FB_reports/tmp/regions", 
                                full.names = T, recursive=F,
                                include.dirs=F)
    
    file.remove(previous_files, recursive=T)
    
    ## then remove files in the parent folder, which will include the (now empty) regions folder
    previous_files = list.files(path="./FB_reports/tmp", 
                                full.names = T, recursive=T,
                                include.dirs=T)
    
    file.remove(previous_files, recursive=T)
    
    ## unzip a report file
    unzip(zipfile = df$fname[j],
          exdir = "./FB_reports/tmp")
    
    data_files = list.files(path="./FB_reports/tmp", 
                            pattern="FacebookAdLibraryReport.+yesterday_advertisers.csv",
                            full.names = T, 
                            recursive=F, 
                            include.dirs=F)
    
    p = "20[12][0-9]-[0-9]{2}-[0-9]{2}"
    x = gregexpr(p, data_files)
    report_date = unlist(regmatches(data_files, x))
    
    df_region = data.frame(fname = data_files,
                           report_date = report_date,
                           stringsAsFactors = F)
    
    region_df_list = list()
    
    for (k in 1:nrow(df_region)) {
      cat("Processing file", df_region$fname[k], "\n")
      
      tmp_text = readLines(df_region$fname[k])
      p = "\xef\xbb\xbf"
      tmp_text = gsub(p, "\n", tmp_text)
      tmp_text = gsub("^\n", "", tmp_text)
      writeLines(tmp_text, "FB_reports/tmp/tmp_data_x.csv")
      
      d = read_fb_file(x="FB_reports/tmp/tmp_data_x.csv", old_format=F)

      d %>% mutate(page_id = gsub("[^0-9]", "", page_id),
                   date = df_region$report_date[k]) -> d
      region_df_list[[k]] = d
    }
    
    ## check if there were any warnings during parsing of CSV files
    print(warnings())
    
    region_df = dplyr::bind_rows(region_df_list)
    
    region_df %>% mutate(amount_spent = gsub("^[^0-9]+", "", amount_spent),
                         amount_spent = as.numeric(amount_spent),
                         amount_spent = ifelse(is.na(amount_spent), 0, amount_spent),
                         page_id = as.character(page_id),
                         number_of_ads = as.numeric(number_of_ads)) %>% 
      group_by(page_name, disclaimer, page_id, date) %>% 
      summarise(amount_spent = sum(amount_spent, na.rm=T),
                num_of_ads = sum(number_of_ads, na.rm=T)) %>% 
      ungroup() %>% 
      select(page_name, disclaimer,
             amt_spent = amount_spent,
             num_of_ads, 
             date, page_id) -> d2
    
    dbWriteTable(conn, name="fb_daily", value=d2,
                 append=T, overwrite=F, row.names=F)
    
  }
}

dbDisconnect(conn)
