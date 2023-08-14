# Wesleyan Media Project - Facebook Aggregate Reports Import

Welcome to Wesleyan Media Project (WMP)'s Facebook Aggregate Reports Import Repository. This repo is part of the CREATIVE project which aims to acquire digital advertising across platforms along with candidate and sponsor data as well as processing and standardizing these data (For more information on the CREATIVE, click [here](https://www.creativewmp.com/)). To that end, we created this repo to enable researchers to collect and clean advertising reports from Facebook, ready to be analyzed. The objective of this repo is twofold. 

1. Download the advertising reports from [Facebook Ad Library](https://www.facebook.com/ads/library/report/?source=archive-landing-page&country=US) in CSV format. Reports are downloaded as `Daily`, `Weekly`, `30 Days`, `90 Days`, and `Lifelong`.
2. Clean and insert these reports to MySQL database (all reports) and BigQuery (Lifelong only) for analysis.

Check out the [Introduction](#introduction) to learn more about the aim of the repo as well as the steps taken.

If you would like to start running the scripts in this repo, check out the [Setup](#setup) section to learn about the steps you need to follow.

## Table of Contents

- [Introduction](#introduction)
    - [Objective](#objective)
- [Data](#data)
    - [Naming Conventions](#naming-conventions)
- [Downloader](#downloader)
    - [Operation](#operation)
- [Data Import](#data-import)
    - [Data Cleanup](#data-cleanup)
        - [Transient Problem](#transient-problem)
        - [Permanent Problem](#permanent-problem)
        - [Number Cleanup](#number-cleanup)
    - [BigQuery](#bigquery)
- [Setup](#setup)
    - [1. Create Directories](#1-create-directories)
    - [2. Create MySQL Tables](#2-create-mysql-tables)
    - [3. Create BigQuery Table](#3-create-bigquery-table)
    - [4. Acquire the GCP Service Account Key File](#4-acquire-the-gcp-service-account-key-file)
    - [5. Download the Reports](#5-download-the-reports)
    - [6. Upload Reports to MySQL](#6-upload-reports-to-mysql)
        - [6a. Insert Lifelong Report to BigQuery](#6a-insert-lifelong-report-to-bigquery)

## Introduction

<img width="1674" alt="fb_agg_report_scripts" src="https://github.com/Wesleyan-Media-Project/fb_agg_reports_import/assets/17502191/b04b8e5b-e719-40db-92b9-8ee676b64935">

Wesleyan Media Project (WMP) monitors and reports on the spending by political campaigns. To do this, WMP collects data from the Facebook Ad Library Report ([https://www.facebook.com/ads/library/report/?source=archive-landing-page&country=US](https://www.facebook.com/ads/library/report/?source=archive-landing-page&country=US)) for the United States. The report is a collection of zipped CSV files that differ by time span and geographic coverage. Example of the reports for June 1, 2023, is contained in the folder `/data`.

The scripts in this repo let you do the following things:

1. Create a folder for each report to be downloaded to. This is achieved by the `create_agg_file_folders.sh` file.

2. Download the reports CSV files (Daily, Weekly, 30 Days, 90 Days, and Lifelong). This is achieved by the `fb_all_reports_download_v060123.py` file. Check out the __[Data](#data)__ section to learn more about the reports.

3. Create tables in MySQL for each report. This is achieved by the `fb_agg_report_mysql_tables.sql` file.

4. Clean up the data and import the data into a MySQL database running locally on a WMP server

5. (For Lifelong only) Insert data into a table hosted in BigQuery in Google Cloud Platform

You will use the corresponding R files for steps 4 and 5. Each report has its own R file. For example, you will use the `fb_lifelong_upload.R` file if you want to insert the Lifelong report to your BiqQuery table. 

Instructions on how to set up the proper file directory structure, create the tables in MySQL, and enable uploads into BigQuery can be found in the __[Setup](#setup)__ section at the end of this document.

### Objective

This repository is part of the CREATIVE project which has two main aims

1. Acquire digital advertising across platforms (including content, spending, impression and sponsor names) along with candidate and sponsor data.
2. Process and integrate all content data through human and state-of-the-art computational methods to produce validated labels for analysis and distribution.

Since 2018, platforms like Google and Facebook have launched public archives of political ad spending on their platforms. The archives come in different formats and may lack certain information. In addition, platform ad libraries are dynamic and changing (and data can disappear). Thus, this project aims to utilize computational techniques to enable easy-to-access, shared baseline information critical to answering a host of important research questions about democracy.

With this repo you will collect political advertising reports from Facebook, clean the data in these reports and insert them into MySQL (all reports) and BigQuery (Lifelong only) for further analysis. Here is a screenshot of the BigQuery page that shows what the end result (e.g., table of Lifelong report) looks like.

![bigquery1](https://github.com/Wesleyan-Media-Project/fb_agg_reports_import/assets/93638016/9653152c-4777-476e-aedd-12b16a03aea9)

See [Data](#data) section for more information on variables.

What can you do with this data? Some examples?
We believe that this data could be used to address important issues including basic descriptive questions about the scope and content of election advertising for different offices across sources along with questions about effect such as how digital advertising influences election outcomes, the role of dark money in digital campaigns, and the spread and reach of misinformation in online political advertising.

## Data

The reports page provides several files. They contain information on political and social-issue advertising on the platform and differ by the time span they cover.

An individual record contains the following fields:
* page name - text string with the current name of the page. Page names can be changed by owners. When an owner deletes their page, the report will contain a null string instead of the page name.
* page id - a numeric id, uniquely identifying a page. This id does not change.
* disclaimer, also known as "funding entity" or "paid for by". This is a text field that identifies the organization that paid for the specific ad. Providing this field is mandatory and in the past, when some advertisers did not provide it, their ads were taken down. The "paid for by" string is a requirement linked to the Federal Election Commission (FEC) rules.
* amount spent. The amount of money the specific page+funding_entity spent on the platform within the reporting time period. If the amount is less than 100 US dollars, the report will say "<= 100"
* number of ads - total number of ads run on the platform by the specific page+funding_entity

This kind of record is included in every type of the report. There are differences in how they are aggregated. 

* The lifelong "all dates" report contains the totals going back to May 2018 when Facebook launched its archive of political ads. This report does not separate the activity by geographic regions (i.e, the US states and territories).
* The time span reports ("last day", "last 7 days", "last 30 days", and "last 90 days") describe the activity during the specified time periods. The zip files with these reports contain separate CSV files for each region.

The lifelong report does not contain a breakdown by the US state. Other reports do contain the breakdown. The state-level values are reported in separate files, one file per U.S. state.

### Naming conventions

The Meta/Facebook team behind the ad library reports chose a convention where the information on the date and region covered in the report is contained in its filename. The reports are generated at the end of the day. Thus, the archive with the name `FacebookAdLibraryReport_2023-06-01_US_last_7_days.zip` will contain the data showing the activity during the week that **ends on June 1, 2023** - the period starting on May 26th and ending on June 1st, 2023. To paraphrase, the day of the report includes the activity on that day. (A subtler point is that this the date is defined by the Pacific Standard Time - the time zone of Meta/Facebook headquarters in Menlo Park, California.)

## Downloader

Historically, the FB Ad Library Report page was the part that spurred the most modifications to the pipeline. There were occasional redesigns of the page that required rewriting the downloader script. In addition, even though this is a public-facing page, Meta implements protection against bots. If you try to access the page too many times, you will be served a "please log in" page instead of the normal data dashboard. This has happened to WMP and required an intervention from the Facebook counterpart who asked the engineering team in charge of the reports page to white-list the IP address of the server used by the WMP.

In January 2023 Facebook has rolled out the new version of the webpage. It allows for downloads of reports going seven days back. This is a big improvement, because it greatly reduces the amount of labor required to manually download the data in case the downloading script breaks down. Now a user can visit the page once a week and download the required files.

Here is how the downloading part of the page looks now:

<img width="626" alt="Screenshot 2023-06-04 at 5 40 42 PM" src="https://github.com/Wesleyan-Media-Project/fb_agg_reports_import/assets/17502191/d2f5ba85-963f-49c0-8e2d-db59d805faed">

The `fb_all_reports_download_v060123.py` is a Python/Selenium script that runs on a Linux-based machine and uses Chrome running in the headless mode. There are two heavily technical points worth knowing:

* Enabling the downloads. By default, as a security precaution, browsers running in headless mode will not download files. The downloads need to be enabled explicitly. Our script uses the Chrome API where the `command_executor` module sends a POST request to the browser to enable the downloads and change the destination directory. This is a highly technical and poorly documented feature that, probably, is dependent on the version of the Chrome. For instance, Firefox uses a different set of instructions that are passed through the browser profile file.
* Triggering the download. The drop-down menu in the downloads section is actually a collection of `div` tags and is not a menu. In the past, the engineering team would change the spelling of the "download report" phrase and there was also a situation that there were actually two "download report" links in the page: one was visible, and the other one was not - it was part of the menu that would open up for users on a mobile device.

We are providing a version of the script that can run in a Google Colab notebook: `facebook_reports_downloader_firefox.ipynb`. Because the newer versions of Colab made installation of Chrome very difficult, the script uses headless Firefox that is installed when the notebook is initialized.

### Operation

The downloader is launched every two hours using a crontab job. The script contains a for-loop that downloads the latest version of each kind of report into its own directory on our server. The names of the directories are:

* `Lifelong`
* `90Days`
* `30Days`
* `Weekly`, and 
* `Daily`


## Data Import

A set of scripts scans the directories listed above and, if there are new files, imports them into the MySQL database. These scripts fall into two groups: with and without region data.

Scripts that do not handle region data:
* `fb_lifelong_upload.R`, and
* `fb_daily_import2.R`

Scripts that import a table with the `region` column:
* `fb_weekly_regions_import.R`,
* `fb_30days_regions_import.R`, and 
* `fb_90days_regions_import.R`

### Data Cleanup

The scripts perform some data cleanup. Specifically, there was one transient and one persistent problem with the data furnished by Facebook.

#### Transient Problem: 
The CSV files would contain a non-ASCII sequence of characters at the beginning of a line every 500 rows. This sequence is shown below:
```
p = "\xef\xbb\xbf"
```

Because the page name is the first column in the file, presence of this sequence meant that every 500th row contained incorrect page name and it would not match the other records. Our solution was to remove this sequence using regular expressions. We believe that this problem is no longer present, but as a safeguard the scripts still contain the instructions that search for this pattern.

#### Permanent Problem:

This problem is caused not by something in the Facebook system, but by the user input. As the reader probably knows, many text editors will automatically replace the regular straight quotation marks with the "curly" quotation marks. This is done for aesthetic reasons. 

Some of the entries in the report contain mismatched quotation marks which, most likely, arise in the following scenario: A user enclosed something into quotation marks, for instance, the nickname of a candidate, e.g. `Rob "Chip" Robbie`. The user was typing this in a text editor. The editor has converted one quotation symbol into the curly mark, but the other one stayed as the "straight" quotation marks. Facebook preserves user input and inserts it into the reports. CSV is a format that uses commas to separate fields in a record. If a text string inside a field contains a comma, then this field is enclosed into (is surrounded by) quotation marks. If the text already had quotation marks and they are unmatched (meaning there is an opening mark but it is not matched with a closing mark), then the data parsing function will incorrectly identify the boundary between fields.

From our experience, the problem of mismatched quotation marks occurs more often among small advertisers. They tend to pick disclaimer strings with more textual flourishes (i.e., monickers in quotation marks). Here is an example of a record with this problem:

<img width="786" alt="Screenshot 2023-06-04 at 10 48 04 PM" src="https://github.com/Wesleyan-Media-Project/fb_agg_reports_import/assets/17502191/3d9eb5ba-0f8b-4879-985b-10e0d33e4373">


Notice how in the `funding_entity` column, the quotation marks around the nickname Chris are different: the opening quotation mark is straight, but the closing quotation mark is slanted and is actually a Unicode character.

Below is an output of an R script that displays that field. The curly quotation mark on the right is more visible:

<img width="355" alt="Screenshot of an output of R code that shows the text string" src="https://github.com/Wesleyan-Media-Project/fb_agg_reports_import/assets/17502191/b6852588-7dd4-413f-aa8b-2e99b0fea567">

The unmatched quotation marks lead to serious failures with data import: when the script does not find the end of an enclosing quotation mark, it fails to read the fields that follow the problematic field. It then also fails to read several rows of data - they are ingested as if they were part of one data row.

Our way of handling this problem was to write our own import function. It is contained in the script `read_fb_file.R`. It performs CSV import of a single row of data. If the number of columns in the result does not match the expected number of columns, then the script removes all double quotation marks from the row and performs the import again. This way we have a record, and later on we can match it manually to the name and disclaimer available via Facebook Ads API.

#### Number Cleanup

When the amount of spend on ads is below 100, Facebook does not report the number and instead inserts the string 


<img width="58" alt="image of a string saying less than or equal to 100" src="https://github.com/Wesleyan-Media-Project/fb_agg_reports_import/assets/17502191/8ec0b73b-f998-4e9d-ba38-c17113d53c17">

In order to make this value compatible with the numerical format of the column, we remove the "less than or equal" character and convert the value to a number. Thus, for smaller spends, we store a rounded up value of 100.

As a side note, once an advertiser has exceeded the threshold of 100 USD, Facebook reports their spend with a one-dollar accuracy.

### BigQuery

Part of the reporting done by WMP during elections involves reporting the total spend on Facebook ads. The lifelong report serves this purpose perfectly. Because not everyone on the WMP team is proficient with writing SQL queries, we have come up with a workflow where the data is stored in BigQuery and the end user can explore the data using the BigQuery connector in Google Sheets.

For this reason, the `fb_lifelong_upload.R` script uploads the data to BigQuery after it imports the data into MySQL. We also use the table in BigQuery as a source for the diagnostic chart showing the time series of the total number of ads and total spend reported by Facebook. The chart is available as a publicly viewable graphic accessible at this [link](https://docs.google.com/spreadsheets/d/1A9laSAxrBJ2I6osWm6qcUFBmKoZeFN_tcjFEvbnrWFs/edit#gid=0)

Here is a screenshot showing the data up to June 1, 2023. The drops indicate the days when Facebook "lost" the ads, and the spikes - the days when the number of ads and the spend was "over-reported". Our intention behind this chart is to show which days must be avoided if someone decides to write a story about campaign spending on Facebook.

![chart](https://github.com/Wesleyan-Media-Project/fb_agg_reports_import/assets/17502191/74af6049-edfb-462b-9ab4-0217212b7593)

## Setup

In order to have the scripts run, you need to follow several steps: 

1. Create local file directories for each type of report
2. Create tables in your MySQL/MariaDB instance that will store the data
3. Create the table in your project in Google Cloud Platform to store the `lifelong` report
4. Download the service account key file from GCP to authenticate script access to BigQuery
5. Download the Facebook Ad Reports for each time frame
6. Clean and upload reports to MySQL
    - 6a. Insert `lifelong` reports to BigQuery table (Lifelong only)

### 1. Create Directories

Open the command prompt in your local machine. Navigate to your working directory if needed using the `cd path/to/your/directory` command (replace the `path/to/your/directory` part with your working directory. Once you get to your working directory, run the command line statements contained in the file `create_agg_file_folders.sh` file. You can either copy the statements in an editor and paste them at the command line, or execute the whole file by using the bash interpreter: 

```
bash create_agg_file_folders.sh
```

This will create a `FB_report` parent folder with a folder for each type of report in it. It will also create `tmp`, `Logs`, and `crontab_logs` folders which will be utilized when running the R scripts.

### 2. Create MySQL Tables

Next step is to create MySQL tables for each report which will store the data. The `fb_agg_report_mysql_tables.sql` file contains the SQL statements that will create the required tables. Follow the steps below to execute them:

- Open terminal (Command Prompt) in your machine.
- Connect to MySQL: Start the MySQL command-line client and connect to your MySQL server using the following command:

```
mysql -u username -p
```

Replace `username` with your MySQL username. You will be prompted to enter the password for the specified MySQL user.

- (Optional) Select Database: If you want to create the table in a specific database, you can select that database using the `USE` statement:

```
USE your_database;
```

- Run the .sql File: To execute the .sql file, use the source command followed by the full path to the .sql file. Replace `/path/to/your_file.sql` with the actual path to your .sql file.

```
source /path/to/your_file.sql
```

Alternatively, you can also manually enter the queries in the .sql file within the MySQL command-line. If you wish to do this, be careful since some of the queries in this file are written in multiple lines. If you also want to write the query in multiple lines, make sure to use a backslash `\` at the end of each line.

After running the sql queries, you will have tables for each report in your MySQL database, ready to be populated.

### 3. Create BigQuery Table

If you have not done this yet, please create a Google Cloud Platform project. For instructions, watch the tutorial [link]. Going through the steps should make you have a project (in our demo its name is `wmp-sandbox`) and a BigQuery dataset `my_ad_archive`.

Go to your project and navigate to the BigQuery console. Execute the following statement in the editor of the console:

```
CREATE TABLE
  my_ad_archive.fb_lifelong (
    page_name STRING,
    disclaimer STRING,
    page_id STRING,
    amt_spent INTEGER,
    num_of_ads INTEGER,
    date STRING );
    
```

This will create an empty table that can be populated with the `lifelong` report from Facebook.

### 4. Acquire the GCP Service Account Key File

Navigate to the IAM & Admin tab in your GCP project. Select "Service accounts". Go through the steps and create a service account. Enter `wmp-sandbox` in the "Service account name" field. The "Service account ID" field will be auto-populated. Click "CREATE AND CONTINUE". This will take you to Step 2, "Grant this service account access to project" tab. In the "Select a role" dropdown list, choose "Owner". This will grant the account all privileges, including operations with BigQuery.
Click "DONE".

After a few seconds, you will be taken back to the Service Accounts page. This time, however, there will be an entry for the service account that you just created. 

Under the "Actions" menu on the right side, click the vertical ellipses and click "Manage keys". You will be taken to the page that says "KEYS". Click the drop-down button "Add key". Select "Create new key" and select "JSON". A JSON file will be created and automatically downloaded on your computer. This file is the service account key file that you will need.

Note: Google advises against granting unnecessarily wide privileges to a service account. "Owner" is the simplest role, but it can lead to trouble if your service account key file falls into the wrong hands. When you learn more about GCP operations, it is a good idea to create a new service account that is authorized only to retrieve data from BigQuery. Do not post the key file where outsiders can download it.

Take note of the name of the key file. Update the `fb_lifelong_upload.R` file so that it contains the correct name of the service account key file.

Now you are ready to launch the scripts and start collecting the data.

### 5. Download the Reports

The first part of collecting data is to download the reports for all timelines.
It is recommended to use a python virtual environment and install all necessary packages used in the script to that environment. You will also need Chrome and ChromeDriver located in the same directory as your Python virtual environment.

- Install Chrome
- ChromeDriver
- Install Python
- Create Python Venv
- Install dependencies
- Revise Python code
- Run the code

### 6. Upload Reports to MySQL

- Install R
- Install dependencies
- Revise code
- Run the R code using the command

#### 6a. Insert Lifelong report to BigQuery




