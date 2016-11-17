import pyrogue as pr


class Ad9249ConfigGroup(pr.Device):
    def __init__(self, name, offset=0, memBase=None, hidden=False):
        super(self.__class__, self).__init__(name, "Configure one side of an AD9249 ADC",
                                             0x200, memBase, offset, hidden)

        # AD9249 bank configuration registers
        self.add(pr.Variable(name="ChipId", offset=0x04, bitSize=8, bitOffset=0, mode="RO"))
        self.add(pr.Variable(name="ChipGrade", offset=0x08, bitSize=3, bitOffset=4, mode="RO"))
        self.add(pr.Variable(name="ExternalPdwnMode", offset=0x20, bitSize=1, bitOffset=5,
                             enum = {0:"Full Power Down", 1: "Standby"}))
        self.add(pr.Variable(name="InternalPdwnMode", offset=0x20, bitSize=2, bitOffset=0,
                             enum = {0:"Chip Run", 1: "Full Power Down", 2: "Standby", 3: "Digital Reset"}))
        self.add(pr.Variable(name="DutyCycleStabilizer", offset=0x24, bitSize=1, bitOffset=0,
                             enum = {0:"Off", 1: "On"}))

class Ad9249ChipConfig(pr.Device):
    def __init__(self, name, offset=0, memBase=None, hidden=False):
        super(self.__class__, self).__init__(name, "Configure one side of an AD9249 ADC",
                                             0x400, memBase, offset, hidden)

        self.add(Ad9249ConfigGroup("Bank0Config", 0x0000));
        self.add(Ad9249ConfigGroup("Bank1Config", 0x0200));        

        
class Ad9249Config(pr.Device):

    def __init__(self, name, memBase, offset, hidden=False, chips=1):
        super(self.__class__, self).__init__(name, "Configuration of Ad9249 ADC",
                                             0x1000, memBase, offset, hidden)

        PDWN_ADDR = int(pow(2,10))
        
        # First add all of the powerdown GPIOs
        for i in range(chips):
            chip = str(i) if chips > 1 else ""
            self.add(pr.Variable(name = "Pdwn" + chip,
                                 description = "Power down chip " + chip,
                                 offset = PDWN_ADDR + (i*4),
                                 bitSize = 1,
                                 bitOffset = 0,
                                 base = 'bool',
                                 mode = "RW"))

            self.add(Ad9249ChipConfig("Ad9249Chip"+chip, 0))
  

