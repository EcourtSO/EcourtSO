from selenium import webdriver
from selenium.webdriver.support.ui import WebDriverWait, Select
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By

# Setup driver
driver = webdriver.Chrome()
driver.get("https://njdg.ecourts.gov.in/njdg_v3//?p=home/index&state_code=27~1&dist_code=25")
wait = WebDriverWait(driver, 20)

# Wait for iframe and switch
iframe = wait.until(EC.presence_of_element_located((By.TAG_NAME, "iframe")))
driver.switch_to.frame(iframe)

# Wait for state dropdown to be available
state_dropdown = wait.until(EC.presence_of_element_located((By.ID, "state")))
Select(state_dropdown).select_by_visible_text("Maharashtra")

# Wait for district dropdown to load
district_dropdown = wait.until(EC.presence_of_element_located((By.ID, "district")))
Select(district_dropdown).select_by_visible_text("Pune")

# Extract or screenshot data
driver.save_screenshot("pune_data.png")