# /usr/bin/env python
# -*- coding: utf-8 -*-
"""
@author: Vojtech Burian
"""


class Page(object):
    """ Base class for all Pages """
    def __init__(self, driver):
        self.driver = driver