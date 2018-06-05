# -*- coding: utf-8 -*-
import pytest
from unittestzero import Assert

from pages.bottom_bar import BottomBar
from pages.url_bar import UrlBar
from pages.welcome_guide import WelcomeGuide
from pages.tabs_page import TabsPage
from pages.main_page import MainPage
from pages.bookmarks_page import BookmarksPage
from pages.history_page import HistoryPage
from pages.dashboard_page import DashboardPage
from shishito.runtime.shishito_support import ShishitoSupport
from shishito.ui.selenium_support import SeleniumTest
from tests.conftest import get_test_info


@pytest.mark.usefixtures("test_status")
class TestWelcomeGuide():
    """ Test Adblock Browser Welcome Guide """

    def setup_class(self):
        self.tc = ShishitoSupport().get_test_control()
        self.driver = self.tc.start_browser()
        self.ts = SeleniumTest(self.driver)
        self.welcome_guide = WelcomeGuide(self.driver)
        self.bottom_bar = BottomBar(self.driver)
        self.url_bar = UrlBar(self.driver)
        self.tabs_page = TabsPage(self.driver)
        self.main_page = MainPage(self.driver)
        self.bookmarks_page = BookmarksPage(self.driver)
        self.dashobard_page = DashboardPage(self.driver)
        self.history_page = HistoryPage(self.driver)
        self.test_url = "google.com"

    def teardown_class(self):
        self.tc.stop_browser()

    def setup_method(self, method):
        self.tc.start_test(True)

    def teardown_method(self, method):
        test_info = get_test_info()
        self.tc.stop_test(test_info)

    ### Tests ###
    @pytest.mark.smoke
    def test_1welcome_guide(self):
        self.welcome_guide.skip_guide()
        Assert.true(self.ts.is_element_visible(self.bottom_bar._menu_icon))

    def test_2open_site(self):
        """Test check if I can load page in app"""
        self.ts.click_and_wait(self.url_bar.address_field)
        Assert.true(self.ts.is_element_visible(self.url_bar._cancel))
        Assert.true(self.ts.is_element_visible(self.main_page._keyboard_locator))
        url_replace_text = self.url_bar.address_field_text.text
        self.url_bar.address_field_text.send_keys(self.test_url)
        self.ts.click_and_wait(self.main_page.go_button)
        url_text = self.url_bar.address_field_text.text
        self.ts.click_and_wait(self.bottom_bar.bookmarks_icon)
        Assert.not_equal(url_text,url_replace_text, 'Site is not loaded')

    def test_3new_tab_dialog(self):
        #Test check if user click on new tab button - dialog is shown with plus icon
        self.ts.click_and_wait(self.bottom_bar.tabs_icon)
        self.ts.click_and_wait(self.tabs_page.plus_button)
        self.ts.click_and_wait(self.bottom_bar.tabs_icon)
        Assert.equal(len(self.tabs_page.tabs_list), 2, 'New tab is not created')

    def test_4bookmark_dialog(self):
        #Test open bookmarks dialig, need to add later assertion for added site
        self.ts.click_and_wait(self.bottom_bar.tabs_icon)
        self.ts.click_and_wait(self.main_page.bookmark_button)
        Assert.true(self.ts.is_element_visible(self.bookmarks_page._bookmark_dialog))
        #TODO Assertions checking that site added to bookmarks

    def test_5dashboard_dialog(self):
        #Test open dashboard dialig, need to add later assertion for added site
        self.ts.click_and_wait(self.main_page.dashboard_button)
        Assert.true(self.ts.is_element_visible(self.dashobard_page._dashboard_dialog))
        #TODO Assertions checking that site added to dashboards

    def test_6history_dialog(self):
        #Test open history dialig, need to add later assertion for loaded site
        self.ts.click_and_wait(self.main_page.history_button)
        Assert.true(self.ts.is_element_visible(self.history_page._history_dialog))
        #TODO Assertions checking that site is shown in history
