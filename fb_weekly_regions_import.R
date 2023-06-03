## nohup R CMD BATCH --no-save --no-restore fb_weekly_regions_import.R  /home/poleinikov/FB_reports/Logs/weekly_regions_import_$(date +%Y-%m-%d).txt &

library(readr)
library(dplyr)
library(RMySQL)

conn = dbConnect(RMySQL::MySQL(), host="localhost",
                 user="xxxx", password="xxxx",
                 dbname="textsim_new")

d = dbGetQuery(conn, "select distinct date from fb_weekly_region")

data_files = list.files(path="/home/poleinikov/FB_reports/Weekly", 
                        pattern="FacebookAdLibraryReport_.*_US_last_7_days.zip",
                        full.names = T)

p = "20[12][0-9]-[0-9]{2}-[0-9]{2}"
x = gregexpr(p, data_files)
report_date = unlist(regmatches(data_files, x))

df = data.frame(fname = data_files,
                report_date = report_date,
                stringsAsFactors = F)

## get only the dates that have not been uploaded yet
df = df %>% anti_join(d, by=c("report_date"="date"))

## the first date when FB included regions was 10/19/19
df = df %>% filter(report_date >= "2021-01-06")

## unzip the file into a tmp directory
## read the file
## import into MySQL
## remove all files in the tmp directory
if (nrow(df) > 0) {
  for (j in 1:nrow(df)) {
    
    cat("Processing file", df$fname[j], "\n")
    ## clean up the tmp directory
    ## First, remove files in the regions folder
    previous_files = list.files(path="/home/poleinikov/FB_reports/tmp/regions", 
                                full.names = T, recursive=F,
                                include.dirs=F)
    
    file.remove(previous_files, recursive=T)
    
    ## then remove files in the parent folder, which will include the (now empty) regions folder
    previous_files = list.files(path="/home/poleinikov/FB_reports/tmp", 
                                full.names = T, recursive=T,
                                include.dirs=T)
    
    file.remove(previous_files, recursive=T)
    
    ## unzip a report file
    unzip(zipfile = df$fname[j],
          exdir = "/home/poleinikov/FB_reports/tmp")
    
    data_files = list.files(path="~/FB_reports/tmp/regions", 
                            pattern="FacebookAdLibraryReport.+last_7_days_.+.csv",
                            full.names = T)
    
    p = "20[12][0-9]-[0-9]{2}-[0-9]{2}"
    x = gregexpr(p, data_files)
    report_date = unlist(regmatches(data_files, x))
    
    p = "(?<=last_7_days_).+(?=.csv)"
    x = gregexpr(p, data_files, perl=T)
    report_region = unlist(regmatches(data_files, x))
    
    df_region = data.frame(fname = data_files,
                           report_date = report_date,
                           report_region = report_region,
                           stringsAsFactors = F)
    
    col_names = c("page_id", "page_name", "disclaimer", "amt_spent", "num_of_ads", "col6", "col7")
    
    region_df_list = list()
    
    for (k in 1:nrow(df_region)) {
      cat("Processing file", df_region$fname[k], "\n")
      
      tmp_text = readLines(df_region$fname[k])
      p = "\xef\xbb\xbf"
      tmp_text = gsub(p, "\n", tmp_text)
      tmp_text = gsub("^\n", "", tmp_text)
      
      ## older files contain 5 columns, newer files have only 4
      ## This post and example says the result will be fine - 
      ## the specification will be ignored when there are only 4 columns
      d = read_csv(file=tmp_text, guess_max=10000, col_types="cccc?")
      colnames(d) = col_names[1:(ncol(d))]
      
      d %>% mutate(page_id = gsub("[^0-9]", "", page_id),
                   date = df_region$report_date[k],
                   region = df_region$report_region[k]) -> d
      region_df_list[[k]] = d
    }
    
    ## check if there were any warnings during parsing of CSV files
    print(warnings())
    
    region_df = dplyr::bind_rows(region_df_list)
    
    ## Depending on the date of the report there may be (or not) the column with number of ads
    ## because it is not universally present, we remove it
    if (colnames(region_df)[5] == "num_of_ads") {
      region_df = region_df %>% select(-num_of_ads)
    }
    
    region_df %>% mutate(amt_spent = gsub("^[^0-9]+", "", amt_spent),
                         amt_spent = as.numeric(amt_spent),
                         amt_spent = ifelse(is.na(amt_spent), 0, amt_spent),
                         page_id = as.character(page_id)) %>% 
      group_by(page_name, disclaimer, page_id, date, region) %>% 
      summarise(amt_spent = sum(amt_spent, na.rm=T)) %>% 
      ungroup() %>% 
      select(page_name, disclaimer,
             amt_spent,
             date, region, page_id) -> d2
    
    dbWriteTable(conn, name="fb_weekly_region", value=d2,
                 append=T, overwrite=F, row.names=F)
    
  }
}

dbDisconnect(conn)
