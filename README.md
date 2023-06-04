# fb_agg_reports_import
Collection of scripts that download and import the Facebook Ad Library aggregate reports in CSV format


<img width="1674" alt="fb_agg_report_scripts" src="https://github.com/Wesleyan-Media-Project/fb_agg_reports_import/assets/17502191/b04b8e5b-e719-40db-92b9-8ee676b64935">

## Introduction

Wesleyan Media Project (WMP) monitors and reports on the spending by political campaigns. To do this, WMP collects data from the Facebook Ad Library Report ([https://www.facebook.com/ads/library/report/?source=archive-landing-page&country=US](https://www.facebook.com/ads/library/report/?source=archive-landing-page&country=US)) for the United States. The report is a collection of zipped CSV files that differ by time span and geographic coverage. Example of the reports for June 1, 2023, is contained in the fodler `/data`.

The scripts in this repo download the CSV files, clean up the data, import the data into a MySQL database running locally on a WMP server, and insert data into a table hosted in BigQuery in Google Cloud Platform.

## Downloader

The `fb_all_reports_download_v060123.py` script 
