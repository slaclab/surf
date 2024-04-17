import pyrogue as pr

import surf.ethernet.gige
import surf.xilinx

class GigEthGtx7(pr.Device):
    def __init__(self, gtxe2_read_only, **kwargs):
        super().__init__(**kwargs)

        self.add(surf.ethernet.gige.GigEthReg(
            offset = 0x0000))

        self.add(surf.xilinx.Gtxe2Channel(
            read_only = gtxe2_read_only,
            offset = 0x1000))
