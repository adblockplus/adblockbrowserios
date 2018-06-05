# /usr/bin/env python
# -*- coding: utf-8 -*-
"""
@author: Vojtech Burian
"""
from selenium.webdriver.common.by import By

from pages.page_base import Page


class BottomBar(Page):
    """ Adblock Browser bottom bar """

    def __init__(self, driver):
        Page.__init__(self, driver)
        self.driver = driver
        self._menu_icon = (By.NAME, 'logo')
        self._bookmarks_icon = (By.NAME, 'bookmark')
        self._tabs_icon = (By.NAME, 'tabsoverview')
        self._settings_menu_item = (By.XPATH, '//UIAApplication[1]/UIAWindow[1]/UIAToolbar[1]/UIATableView[1]')

    @property
    def menu_icon(self):
        return self.driver.find_element(*self._menu_icon)

    @property
    def bookmarks_icon(self):
        return self.driver.find_element(*self._bookmarks_icon)

    @property
    def tabs_icon(self):
        return self.driver.find_element(*self._tabs_icon)

    @property
    def settings_menu_item(self):
        return self.driver.find_element(*self._settings_menu_item)
