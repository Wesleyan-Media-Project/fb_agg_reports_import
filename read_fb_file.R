read_fb_file = function(x, old_format=F) {
  
  if (!require(dplyr)) {
    return(NA)
  }
  
  ## use try() to go over all lines
  a = readLines(x, encoding='UTF-8')
  df_list = list()
  for (j in 1:length(a)) {
    try({df_list[[j]] = read.csv(header=F, text=a[j], stringsAsFactors=F,
                                 colClasses = "character",
                                 encoding='UTF-8')}, silent=F)
  }
  
  ## offending lines will not have data in corresponding list elements
  s = sapply(df_list, length)
  r = which(s == 0)
  
  ## remove the double quotes
  a[r] = gsub('"', "", a[r])
  
  ## repeat the import for the offending rows
  for (row in r) {
    try({df_list[[row]] = read.csv(header=F, text=a[row], stringsAsFactors=F,
                                   colClasses = "character", encoding='UTF-8')}, silent=F)
  }
  
  ## make the dataframe
  if (!old_format) {
    tmp_df = dplyr::bind_rows(df_list) %>% slice(-1) %>% 
      rename(page_id = V1, page_name = V2, disclaimer = V3, amount_spent = V4,
             number_of_ads = V5)
  } else {
    tmp_df = dplyr::bind_rows(df_list) %>% slice(-1) %>% 
      rename(page_name = V1, disclaimer = V2, amount_spent = V3,
             number_of_ads = V4)
  }
  
  return(tmp_df)
  
}
