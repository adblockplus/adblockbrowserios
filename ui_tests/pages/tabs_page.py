from selenium.webdriver.common.by import By
from pages.page_base import Page


class TabsPage(Page):
    """ ABP native tab page object which opened when user click on bottom + button"""

    def __init__(self, driver):
        Page.__init__(self, driver)
        self.driver = driver
        self._tab_page = (By.NAME, 'Empty list')
        self._plus_button_locator = (By.NAME, 'addtab')
        self._tabs_list = (By.XPATH, '//UIAApplication[1]/UIAWindow[1]/UIATableView[2]/UIATableCell')
        #                             //UIAApplication[1]/UIAWindow[1]/UIATableView[2]/
        self._tab_value = (By.XPATH, './/UIAStaticText[1]')

    @property
    def tab_page(self):
        return self.driver.find_element(*self._tab_page)

    @property
    def plus_button(self):
        return self.driver.find_element(*self._plus_button_locator)

    @property
    def tabs_list(self):
        return self.driver.find_elements(*self._tabs_list)

    def tab_value(self, number):
        tabs = self.tabs_list
        return tabs[number].find_element(*self._tab_value)
