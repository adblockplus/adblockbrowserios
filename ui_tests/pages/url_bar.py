# /usr/bin/env python
# -*- coding: utf-8 -*-
"""
@author: Vojtech Burian, Irina Gvozdeva
"""
from selenium.webdriver.common.by import By

from pages.page_base import Page
import time

class UrlBar(Page):
    """ Adblock Browser url bar """
    def __init__(self, driver):
        Page.__init__(self, driver)
        self.driver = driver
        self._address_field = (By.NAME, 'Search or enter website name')
        self._cancel = (By.NAME, 'Cancel')
        self._clear_text = (By.NAME, 'Clear text')
        self._reload = (By.NAME, 'reload')
        self._address_field_text = (By.XPATH, '//UIAApplication[1]/UIAWindow[1]/UIATextField[1]')

    @property
    def address_field(self):
        return self.driver.find_element(*self._address_field)

    @property
    def address_field_text(self):
        return self.driver.find_element(*self._address_field_text)