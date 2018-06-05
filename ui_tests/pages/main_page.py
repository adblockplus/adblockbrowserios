# /usr/bin/env python
# -*- coding: utf-8 -*-
from selenium.webdriver.common.by import By
from pages.page_base import Page


class MainPage(Page):
    """ ABP native UI page object """

    def __init__(self, driver):
        Page.__init__(self, driver)
        self.driver = driver
        self._bookmarks_button_locator = (By.NAME, 'Bookmarks')
        self._dashboard_button_locator = (By.NAME, 'Dashboard')
        self._history_button_locator = (By.NAME, 'History')
        self._go_button_locator = (By.NAME, 'Go')
        self._keyboard_locator = (By.XPATH, '//UIAApplication[1]/UIAWindow[2]/UIAKeyboard[1]')

    @property
    def history_button(self):
        return self.driver.find_element(*self._history_button_locator)

    @property
    def bookmark_button(self):
        return self.driver.find_element(*self._bookmarks_button_locator)

    @property
    def dashboard_button(self):
        return self.driver.find_element(*self._dashboard_button_locator)

    @property
    def go_button(self):
        return self.driver.find_element(*self._go_button_locator)
