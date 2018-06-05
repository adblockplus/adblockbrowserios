# /usr/bin/env python
# -*- coding: utf-8 -*-
"""
@author: Vojtech Burian
"""
from selenium.webdriver.common.by import By

from pages.page_base import Page
from shishito.ui.selenium_support import SeleniumTest


class WelcomeGuide(Page):
    """ Adblock Browser welcome guide tutorial slides """

    def __init__(self, driver):
        Page.__init__(self, driver)
        self.driver = driver
        self._first_button = (By.NAME, 'Only one more step')
        self._second_button = (By.NAME, 'Finish')
        self.ts = SeleniumTest(self.driver)

    @property
    def first_button(self):
        return self.driver.find_element(*self._first_button)

    @property
    def second_button(self):
        return self.driver.find_element(*self._second_button)

    def skip_guide(self):
        if not self.ts.is_element_not_visible(self._first_button):
            self.ts.wait_for_element_visible(self._first_button)
            self.ts.click_and_wait(self.first_button, self._second_button)
            self.ts.click_and_wait(self.second_button)
