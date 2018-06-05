from selenium.webdriver.common.by import By
from pages.page_base import Page

class BookmarksPage(Page):
    """ ABP native dialog object which opened when user click on middle bottom button"""

    def __init__(self, driver):
        Page.__init__(self, driver)
        self.driver = driver
        self._bookmark_dialog = (By.XPATH, '//UIAApplication[1]/UIAWindow[1]/UIACollectionView[1]/UIACollectionCell[1]')

    @property
    def bookmark_dialog(self):
        return self.driver.find_element(*self._bookmark_dialog)