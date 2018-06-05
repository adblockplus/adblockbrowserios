import os

from shishito.shishito_runner import ShishitoRunner


class AdblockRunner(ShishitoRunner):
    """ Dedicated project runner, extends general SalsaRunner """

    def __init__(self):
        project_root = os.path.dirname(os.path.abspath(__file__))
        super(AdblockRunner, self).__init__(project_root)


runner = AdblockRunner()
runner.run_tests()
