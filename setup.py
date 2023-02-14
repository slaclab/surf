
from distutils.core import setup
from git import Repo

repo = Repo()

# Get version before adding version file
ver = repo.git.describe('--tags')
ver = ver.replace('-', '+', 1) # https://github.com/pypa/setuptools/issues/3772

# append version constant to package init
with open('python/surf/__init__.py','a') as vf:
    vf.write(f'\n__version__="{ver}"\n')

setup (
   name='surf',
   version=ver,
   packages=['surf',
             'surf/axi',
             'surf/devices',
             'surf/ethernet',
             'surf/misc',
             'surf/protocols',
             'surf/xilinx',
             'surf/devices/analog_devices',
             'surf/devices/cypress',
             'surf/devices/intel',
             'surf/devices/linear',
             'surf/devices/microchip',
             'surf/devices/micron',
             'surf/devices/nxp',
             'surf/devices/silabs',
             'surf/devices/ti',
             'surf/devices/transceivers',
             'surf/ethernet/gige',
             'surf/ethernet/mac',
             'surf/ethernet/ten_gig',
             'surf/ethernet/udp',
             'surf/ethernet/xaui',
             'surf/protocols/batcher',
             'surf/protocols/clink',
             'surf/protocols/i2c',
             'surf/protocols/jesd204b',
             'surf/protocols/pgp',
             'surf/protocols/rssi',
             'surf/protocols/ssi', ],
   package_dir={'':'python'},
)

