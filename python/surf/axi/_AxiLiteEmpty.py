#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AxiEmpty Module as a placeholder for future module
#-----------------------------------------------------------------------------
# File       : AxiLiteEmpty.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue AxiEmpty Module as a placeholder for future module
#-----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the rogue software platform, including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

class AxiLiteEmpty(pr.Device):
    def __init__(   self,       
            name        = "AxiEmpty",
            description = "AxiEmpty Module as a placeholder for future module",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)  
