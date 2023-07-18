## nohup R CMD BATCH --no-save --no-restore fb_lifelong_upload.R  /home/poleinikov/FB_reports/Logs/upload_log_$(date +%Y-%m-%d).txt &

library(bigrquery)
library(readr)
library(dplyr)
library(RMySQL)

source("read_fb_file.R")

## open a connection to the MySQL server
conn = dbConnect(RMySQL::MySQL(), host="xxx.xxx.xx.xx", ## replace the 'host' with IP address or 'localhost
                 user="xxxx", password="xxxx",
                 dbname="dbase1")

sql = 'select distinct date from fb_lifelong'
previous_dates = dbGetQuery(conn, sql)

data_files = list.files(path="./FB_reports/Lifelong", 
                        pattern="FacebookAdLibraryReport_.*_US_lifelong.zip",
                        full.names = T)

p = "20[12][0-9]-[0-9]{2}-[0-9]{2}"
x = gregexpr(p, data_files)
report_date = unlist(regmatches(data_files, x))

df = data.frame(fname = data_files,
                report_date = report_date,
                stringsAsFactors = F)

k = report_date %in% c(previous_dates$date)

df = df %>% filter(!k, report_date >= "2021-01-06")


bq_auth(path="wmp-sandbox-key-file.json") ## replace with the actual filename of your service account key file

## wmp-sandbox is the name of GCP project, my_ad_archive is the dataset in BigQuery in your project
## replace if necessary
bqt = bq_table(project="wmp-sandbox", dataset="my_ad_archive", table="fb_lifelong")

## unzip the file into a tmp directory
## read the file
## import into MySQL
## import into BQ
## remove all files in the tmp directory

if (nrow(df) > 0) {
  for (j in 1:nrow(df)) {
    cat("Processing file", df$fname[j], "\n")
    ## clean up the tmp directory
    previous_files = list.files(path="./FB_reports/tmp", 
                                full.names = T, recursive=T)
    file.remove(previous_files, recursive=T)
    
    ## unzip a report file
    unzip(zipfile = df$fname[j],
          exdir = "./FB_reports/tmp")
    
    ## get the path to the CSV file with advertiser info
    csv_files = list.files(path="./FB_reports/tmp", 
                           pattern="FacebookAdLibraryReport(Revamp)?_.*_US_lifelong_advertisers.csv",
                           full.names = T)
    
    ## just in case, if something went wrong, check the number of file names and exit if 0
    if (length(csv_files) == 0) {
      dbDisconnect(conn)
      stop("No csv files after unzipping an archive")
    }
    
    d = read_fb_file(csv_files[1], old_format=F)
    
    d2 = d %>% mutate(amt_spent = gsub("^[^0-9]+", "", amount_spent),
                      amt_spent = as.numeric(amt_spent),
                      num_of_ads = as.numeric(number_of_ads)) %>% 
      group_by(page_name, page_id, disclaimer) %>% 
      summarise(amt_spent = sum(amt_spent, na.rm=T),
                num_of_ads = sum(num_of_ads, na.rm=T)) %>% 
      ungroup() %>% mutate(date = df$report_date[j]) %>% 
      select(page_name, disclaimer, amt_spent, num_of_ads, date, page_id)
    
    ## upload into MySQL  
    dbWriteTable(conn, name="fb_lifelong", value=d2, append=T, row.names=F)
    
    ## upload into BigQuery
    ## useful documentation: 
    ## https://stackoverflow.com/questions/51181966/r-to-bigquery-data-upload-error
    bq_table_upload(x=bqt, values=d2, write_disposition="WRITE_APPEND")
    
  }
  
}


dbDisconnect(conn)
