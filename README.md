# fb_agg_reports_import
Collection of scripts that download and import the Facebook Ad Library aggregate reports in CSV format


<img width="1674" alt="fb_agg_report_scripts" src="https://github.com/Wesleyan-Media-Project/fb_agg_reports_import/assets/17502191/b04b8e5b-e719-40db-92b9-8ee676b64935">

## Introduction

Wesleyan Media Project (WMP) monitors and reports on the spending by political campaigns. To do this, WMP collects data from the Facebook Ad Library Report ([https://www.facebook.com/ads/library/report/?source=archive-landing-page&country=US](https://www.facebook.com/ads/library/report/?source=archive-landing-page&country=US)) for the United States. The report is a collection of zipped CSV files that differ by time span and geographic coverage. Example of the reports for June 1, 2023, is contained in the fodler `/data`.

The scripts in this repo download the CSV files, clean up the data, import the data into a MySQL database running locally on a WMP server, and insert data into a table hosted in BigQuery in Google Cloud Platform.

## Data

Meta/Facebook provides several files. They contain information on political and social-issue advertising on the platform and differ by the time span they cover.

An individual record contains the following fields:
* page id - a numeric id, uniquely identifying a page. This id does not change.
* page name - text string with the current name of the page. Page names can be changed by owners. When an owner deletes their page, the report will contain a null string instead of the page name.
* disclaimer, also known as "funding entity" or "paid for by". This is a text field that identifies the organization that paid for the specific ad. Providing this field is a requirement going back to the Federal Election Commission (FEC) rules.
* amount spent. The amount of money the specific page+funding_entity spent on the platform within the reporting time period. If the amount is less than 100 US dollars, the report will say "<= 100"
* number of ads - total number of ads run on the platform by the specific page+funding_entity

This kind of record is included in every type of the report. There are differences in how they are aggregated. 

* The lifelong "all dates" report contains the totals going back to May 2018 when Facebook launched its archive of political ads. This report does not separate the activity by geographic regions (i.e, the US states and territories).
* The time span reports ("last day", "last 7 days", "last 30 days", and "last 90 days") describe the activity during the specified time periods. The zip files with these reports contain separate CSV files for each region.

### Naming conventions

The Meta/Facebook team behind the ad library reports chose a convention where the information on the date and region covered in the report is contained in its filename. The reports are generated at the end of the day. Thus, the archive with the name `FacebookAdLibraryReport_2023-06-01_US_last_7_days.zip` will contain the data showing the activity during the week that **ends on June 1, 2023** - the period starting on May 26th and ending on June 1st, 2023. To paraphrase, the day of the report includes the activity on that day. (A subtler point is that this the date is defined by the Pacific Standard Time - the time zone of Meta/Facebook headquarters in Menlo Park, California.)

## Downloader

Historically, the FB Ad Library Report page was the part that spurred the most modifications to the pipeline. There were occasional redesigns of the page that required rewriting the downloader script. In addition, even though this is a public-facing page, Meta implements protection against bots. If you try to access the page too many times, you will be served a "please log in" page instead of the normal data dashboard. This has happened to WMP and required an intervention from the Facebook counterpart who asked the engineering team in charge of the reports page to white-list the IP address of the server used by the WMP.

In January 2023 Facebook has rolled out the new version of the webpage. It allows for downloads of reports going seven days back. This is a big improvement, because it greatly reduces the amount of labor required to manually download the data in case the downloading script breaks down. Now a user can visit the page once a week and download the required files.

Here is how the downloading part of the page looks now:

<img width="626" alt="Screenshot 2023-06-04 at 5 40 42 PM" src="https://github.com/Wesleyan-Media-Project/fb_agg_reports_import/assets/17502191/d2f5ba85-963f-49c0-8e2d-db59d805faed">

The `fb_all_reports_download_v060123.py` is a Python/Selenium script that runs on a Linux-based machine and uses Chrome running in the headless mode. There are two heavily technical points worth knowing:

* Enabling the downloads. By default, as a security precuation, browsers running in headless mode will not download files. The downloads need to be enabled explicitly. Our script uses the Chrome API where the `command_executor` module sends a POST request to the browser to enable the downloads and change the destination directory. This is a highly technical and poorly documented feature that, probably, is dependent on the version of the Chrome. For instance, Firefox uses a different set of instructions that are passed through the browser profile file.
* Triggering the download. The drop-down menu in the downloads section is actually a collection of `div` tags and is not a menu. In the past, the engineering team would change the spelling of the "download report" phrase and there was also a situation that there were actually two "download report" links in the page: one was visible, and the other one was not - it was part of the menu that would open up for users on a mobile device.

We are providing a version of the script that can run in a Google Colab notebook: `facebook_reports_downloader_firefox.ipynb`. Because the newer versions of Colab made installation of Chrome very difficult, the script uses headless Firefox that is installed when the notebook is initialized.

### Operation

The downloader is launched every 30 minutes using a crontab job. The script contains a for-loop that downloads the latest version of each kind of report into its own directory on our server. The names of the directories are:
* `Lifelong`
* `90Days`
* `30Days`
* `Weekly`, and 
* `Daily`

We use the 30 minute intervals as a protection against the situation when the Facebook team posts several reports in a quick succession. This happens occasionally, when the team falls behind the schedule. Normally, the webpage contains reports that lag about two days from the current day. On some occasions (around holidays like the Memorial Day or the Independence Day) the lag increases. The team then posts several reports, sometimes with an interval of one hour or so.

The 30-minute interval is rooted in the legacy mode of operations when it was impossible to go back and retrieve the reports from previous days. With the new feature in place, the script can visit the page once per day. If there is a gap in reports, it can be manually filled.

## Data import

A set of scripts scans the directories listed above and, if there are new files, imports them into the MySQL database. These scripts fall into two groups: with and without region data.

Scripts that do not handle region data:
* `fb_lifelong_upload.R`, and
* `fb_daily_import2.R`

Scripts that import a table with the `region` column:
* `fb_weekly_regions_import.R`,
* `fb_30days_regions_import.R`, and 
* `fb_90days_regions_import.R`

### Data cleanup

The scripts perform some data cleanup. Specifically, there was one transient and one persistent problem with the data furnished by Facebook.

#### Transient problem: 
The CSV files would contain a non-ASCII sequence of characters at the beginning of a line every 500 rows. This sequence is shown below:
```
p = "\xef\xbb\xbf"
```

Because the page name is the first column in the file, presence of this sequence meant that every 500th row contained incorrect page name and it would not match the other records. Our solution was to remove this sequence using regular expressions. We believe that this problem is no longer present, but as a safeguard the scripts still contain the instructions that search for this pattern.

#### Permanent problem:

This problem is caused not by something in the Facebook system, but by the user input. As the reader probably knows, many text editors will automatically replace the regular straight quotation marks with the "curly" quotation marks. This is done for aesthetic reasons. 

Some of the entries in the report contain mismatched quotation marks which, most likely, arise in the following scenario: A user enclosed something into quotation marks, for instance, the nickname of a candidate, e.g. `Rob "Chip" Robbie`. The user was typing this in a text editor. The editor has converted one quotation symbol into the curly mark, but the other one stayed as the "straight" quotation marks. Facebook preserves user input and inserts it into the reports. CSV is a format that uses commas to separate fields in a record. If a text string inside a field contains a comma, then this field is enclosed into (is surrounded by) quotation marks. If the text already had quotation marks and they are unmatched (meaning there is an opening mark but it is not matched with a closing mark), then the data parsing function will incorrectly identify the boundary between fields.

From our experience, the problem of mismatched quotation marks occurs more often among small advertisers. They tend to pick disclaimer strings with more textual flourishes (i.e., monickers in quotation marks). Here is an example of a record with this problem:

<img width="786" alt="Screenshot 2023-06-04 at 10 48 04 PM" src="https://github.com/Wesleyan-Media-Project/fb_agg_reports_import/assets/17502191/3d9eb5ba-0f8b-4879-985b-10e0d33e4373">


Notice how in the `funding_entity` column, the quotation marks around the nickname Chris are different: the opening quotation mark is straight, but the closing quotation mark is slanted and is actually a Unicode character.

Below is an output of an R script that displays that field. The curly quotation mark on the right is more visible:

<img width="355" alt="Screenshot of an output of R code that shows the text string" src="https://github.com/Wesleyan-Media-Project/fb_agg_reports_import/assets/17502191/b6852588-7dd4-413f-aa8b-2e99b0fea567">


The unmatched quotation marks lead to serious failures with data import: when the script does not find the end of an enclosing quotation mark, it fails to read the fields that follow the problematic field. It then also fails to read several rows of data - they are ingested as if they were part of one data row.

Our way of handling this problem was to write our own import function. It is contained in the script `read_fb_file.R`. It performs CSV import of a single row of data. If the number of columns in the result does not match the expected number of columns, then the script removes all double quotation marks from the row and performs the import again. This way we have a record, and later on we can match it manually to the name and disclaimer available via Facebook Ads API.

#### Number cleanup

When the amount of spend on ads is below 100, Facebook does not report the number and instead inserts the string 


<img width="58" alt="image of a string saying less than or equal to 100" src="https://github.com/Wesleyan-Media-Project/fb_agg_reports_import/assets/17502191/8ec0b73b-f998-4e9d-ba38-c17113d53c17">

In order to make this value compatible with the numerical format of the column, we remove the "less than or equal" character and convert the value to a number. Thus, for smaller spends, we store a rounded up value of 100.

As a side note, once an advertiser has exceeded the threshold of 100 USD, Facebook reports their spend with a one-dollar accuracy.

### BigQuery

Part of the reporting done by WMP during elections involves reporting the total spend on Facebook ads. The lifelong report serves this purpose perfectly. Because not everyone on the WMP team is proficient with writing SQL queries, we have come up with a workflow where the data is stored in BigQuery and the end user can explore the data using the BigQuery connector in Google Sheets.

For this reason, the `fb_lifelong_upload.R` script uploads the data to BigQuery after it imports the data into MySQL. We also use the table in BigQuery as a source for the diganostic chart showing the time series of the total number of ads and total spend reported by Facebook. The chart is available as a publicly viewable graphic accessible at this [link](https://docs.google.com/spreadsheets/d/1A9laSAxrBJ2I6osWm6qcUFBmKoZeFN_tcjFEvbnrWFs/edit#gid=0)

Here is a screenshot showing the data up to June 1, 2023. The drops indicate the days when Facebook "lost" the ads, and the spikes - the days when the number of ads and the spend was "over-reported". Our intention behind this chart is to show which days must be avoided if someone decides to write a story about campaign spending on Facebook.

![chart](https://github.com/Wesleyan-Media-Project/fb_agg_reports_import/assets/17502191/74af6049-edfb-462b-9ab4-0217212b7593)





