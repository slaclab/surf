#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

# import pyrogue             as pr
import surf.devices.silabs as silabs

class Si5394Page0(silabs.Si5345Page0):
    def __init__(self,name="Page0",**kwargs):
        super().__init__(name=name,**kwargs)

class Si5394Page1(silabs.Si5345Page1):
    def __init__(self,name="Page1",**kwargs):
        super().__init__(name=name,**kwargs)

class Si5394Page2(silabs.Si5345Page2):
    def __init__(self,name="Page2",**kwargs):
        super().__init__(name=name,**kwargs)

class Si5394Page3(silabs.Si5345Page3):
    def __init__(self,name="Page3",**kwargs):
        super().__init__(name=name,**kwargs)

class Si5394Page4(silabs.Si5345Page4):
    def __init__(self,name="Page4",**kwargs):
        super().__init__(name=name,**kwargs)

class Si5394Page5(silabs.Si5345Page5):
    def __init__(self,name="Page5",**kwargs):
        super().__init__(name=name,**kwargs)

# class Si5394Page6(silabs.Si5345Page6):
    # def __init__(self,name="Page6",**kwargs):
        # super().__init__(name=name,**kwargs)

# class Si5394Page7(silabs.Si5345Page7):
    # def __init__(self,name="Page7",**kwargs):
        # super().__init__(name=name,**kwargs)

# class Si5394Page8(silabs.Si5345Page8):
    # def __init__(self,name="Page8",**kwargs):
        # super().__init__(name=name,**kwargs)

class Si5394Page9(silabs.Si5345Page9):
    def __init__(self,name="Page9",**kwargs):
        super().__init__(name=name,**kwargs)

class Si5394PageA(silabs.Si5345PageA):
    def __init__(self,name="PageA",**kwargs):
        super().__init__(name=name,**kwargs)

class Si5394PageB(silabs.Si5345PageB):
    def __init__(self,name="PageB",**kwargs):
        super().__init__(name=name,**kwargs)
