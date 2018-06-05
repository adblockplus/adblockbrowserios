from selenium.webdriver.common.by import By
from pages.page_base import Page

class DashboardPage(Page):
    """ ABP native dialog object which opened when user click on middle bottom button"""

    def __init__(self, driver):
        Page.__init__(self, driver)
        self.driver = driver
        self._dashboard_dialog = (By.XPATH, '//UIAApplication[1]/UIAWindow[1]/UIACollectionView[1]/UIACollectionCell[2]')

    @property
    def dashboard_dialog(self):
        return self.driver.find_element(*self._dashboard_dialog)