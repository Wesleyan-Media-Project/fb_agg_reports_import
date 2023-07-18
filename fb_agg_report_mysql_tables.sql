/* Tables:

fb_daily
fb_daily_region
fb_weekly_region
fb_30days_region
fb_90days_region
fb_lifelong
*/

CREATE TABLE fb_lifelong 
(
    page_name text, 
    disclaimer text,
    amt_spent int(12),
    num_of_ads int(12),
    date date,
    page_id varchar(30)
);

create table fb_daily LIKE fb_lifelong;

create table fb_daily_region 
(
    page_name text,
    disclaimer text,
    amt_spent int(12),
    date text,
    region text,
    page_id varchar(30)
);

create table fb_weekly_region LIKE fb_daily_region;
create table fb_30days_region LIKE fb_daily_region;
create table fb_90days_region LIKE fb_daily_region;

