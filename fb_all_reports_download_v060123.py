## import selenium and the time package necessary for delays
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.keys import Keys
from selenium.common.exceptions import NoSuchElementException
from selenium.webdriver.common.by import By
import time

import pandas as pd
import numpy as np
import datetime as dt

## fill out the options
user_agent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Safari/605.1.15,gzip(gfe)'

options = Options()
prefs = {'download.default_directory' : '/home/poleinikov'}
options.add_experimental_option("prefs", prefs)
options.add_argument('--window-size=1200x800')
options.add_argument(f'user-agent={user_agent}')
options.headless = True

## invoke an instance of Chrome browser in headless mode (try 'google-chrome --V')
driver = webdriver.Chrome(options=options, executable_path='/home/poleinikov/chromedriver')
driver.get("https://www.facebook.com/ads/library/report/?source=archive-landing-page&country=US")
time.sleep(60)
driver.save_screenshot('/home/poleinikov/crontab_logs/first_screen_' + dt.datetime.now().strftime("%Y_%m_%d_%H_%M") + '.png')

tabs = ['Last day', 'Last 7 days', 'Last 30 days', 'Last 90 days', 'All dates']
dl_folders = ['Daily', 'Weekly', '30Days', '90Days', 'Lifelong']

dl_df = pd.DataFrame({'tab': tabs, 'folder': dl_folders})

driver.command_executor._commands["send_command"] = ("POST", '/session/$sessionId/chromium/send_command')

## scroll to the bottom of the page
## webdriver.ActionChains(driver).send_keys(Keys.CONTROL, Keys.END).perform()
driver.execute_script("window.scrollTo(0,document.body.scrollHeight)")

## find the Time range tab
tab = driver.find_elements(by=By.XPATH, value = "//div[contains(text(), 'Time range')]/following-sibling::div")
if len(tab) == 0:
    print("Time range tab not found")
    driver.close()
    driver.quit()
    quit()

x_coord = 0
for i in range(dl_df.shape[0]):
    xpath_tab = dl_df['tab'][i]
    folder = dl_df['folder'][i]
    print(dl_df.loc[i, :])
    
    ## on its own Chrome in headless mode will not perform downloads, as a security feature
    ## to enable downloads, it is necessary to execute a command
    params = {'cmd': 'Page.setDownloadBehavior', 
            'params': {'behavior': 'allow', 
                        'downloadPath': '/home/poleinikov/FB_reports/' + folder}
        }
    ## print(params)
    command_result = driver.execute("send_command", params)
    
    ## open the menu
    webdriver.ActionChains(driver).move_to_element(tab[0]).perform()
    time.sleep(2)
    webdriver.ActionChains(driver).click(tab[0]).perform()
    time.sleep(5)

    ## select the item
    ## menu_item = driver.find_elements(by=By.XPATH, value = "//div[contains(@role, 'menu')]/descendant::div[contains(text(), 'All dates')]")
    menu_item = driver.find_elements(by=By.XPATH, value = "//div[contains(@role, 'menu')]/descendant::div[contains(text(), '{}')]".format(xpath_tab) )
    if len(menu_item) == 0:
        print("menu item not found")
        driver.close()
        driver.quit()
        quit()

    webdriver.ActionChains(driver).move_to_element(menu_item[0]).perform()
    webdriver.ActionChains(driver).click(menu_item[0]).perform()  
    webdriver.ActionChains(driver).reset_actions()
    ## clicking on the menu item closes the menu list

    try:
        ## locate the download button
        button = driver.find_elements_by_xpath("//div[contains(translate(text(), 'DR', 'dr'), 'download report')]/parent::a")
        print("Got {} elements for the download button".format(len(button)))

        second_button = button[0]

        ## move the focus onto the button
        webdriver.ActionChains(driver).move_to_element(second_button).perform()
        time.sleep(2)

        ## click on the button to initiate the download
        webdriver.ActionChains(driver).click(second_button).perform()
        time.sleep(60)

    except NoSuchElementException:
        print('Download report button not found for' + xpath_tab + ' tab')
        driver.close()
        driver.quit()
        quit()


## stop the Chrome process
driver.close()
driver.quit()
quit()

