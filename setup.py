
from distutils.core import setup
from git import Repo

repo = Repo()

# Get version before adding version file
rawVer = repo.git.describe('--tags')

fields = rawVer.split('-')

if len(fields) == 1:
    pyVer = fields[0]
else:
    pyVer = fields[0] + '.dev' + fields[1]

# append version constant to package init
with open('python/surf/__init__.py','a') as vf:
    vf.write(f'\n__version__="{pyVer}"\n')

setup (
   name='surf',
   version=pyVer,
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

