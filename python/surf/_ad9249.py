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

    def __init__(self, name, offset=0, memBase=None, hidden=False, chips=1):
        super(self.__class__, self).__init__(name, "Configuration of Ad9249 ADC",
                                             0x1000, memBase, offset, hidden)

        PDWN_ADDR = int(pow(2,11))
        
        # First add all of the powerdown GPIOs
        if chips == 1:
            self.add(pr.Variable(name = "Pdwn",
                                 description = "Power down chip ",
                                 offset = PDWN_ADDR,
                                 bitSize = 1,
                                 bitOffset = 0,
                                 base = 'bool',
                                 mode = "RW"))
            self.add(Ad9249ConfigGroup("Bank0Config", 0x0000));
            self.add(Ad9249ConfigGroup("Bank1Config", 0x0200));
        else:
            for i in range(chips):
                self.add(pr.Variable(name = "Pdwn" + chip,
                                     description = "Power down chip " + chip,
                                     offset = PDWN_ADDR + (i*4),
                                     bitSize = 1,
                                     bitOffset = 0,
                                     base = 'bool',
                                     mode = "RW"))
                self.add(Ad9249ChipConfig("Ad9249Chip"+chip, 0))
  

class Ad9249ReadoutGroup(pr.Device):
    def __init__(self, name, offset=0, memBase=None, hidden=False, channels=8):

        assert (channels > 0 and channels <= 8), "channels (%r) must be between 0 and 8" % (channels)
        
        super(self.__class__, self).__init__(name, "Configure readout of 1 bank of an AD9249",
                                             0x10000, memBase, offset, hidden)
        
        for i in xrange(channels):
            self.add(pr.Variable(name="ChannelDelay["+str(i)+"]",
                                 description = "IDELAY value for serial channel " + str(i),
                                 offset = i*4,
                                 bitSize = 5,
                                 bitOffset = 0,
                                 base = 'hex',
                                 mode = 'RW'))

        self.add(pr.Variable(name="FrameDelay",
                                 description = "IDELAY value for FCO",
                                 offset = 0x20,
                                 bitSize = 5,
                                 bitOffset = 0,
                                 base = 'hex',
                                 mode = 'RW'))

        self.add(pr.Variable(name="LostLockCount",
                             description = "Number of times that frame lock has been lost since reset",
                             offset = 0x30,
                             bitSize = 16,
                             bitOffset = 0,
                             base = 'int',
                             mode = "RO"))
        
        self.add(pr.Variable(name="Locked",
                             description = "Readout has locked on to the frame boundary",
                             offset = 0x30,
                             bitSize = 1,
                             bitOffset = 16,
                             base = 'bool',
                             mode = "RO"))
        
        self.add(pr.Variable(name="AdcFrame",
                             description = "Last deserialized FCO value for debug",
                             offset = 0x34,
                             bitSize = 16,
                             bitOffset = 0,
                             base = 'hex',
                             mode = "RO"))

        for i in xrange(channels):
            self.add(pr.Variable(name="AdcChannel{:d}".format(i),
                                 description = 'Last deserialized channel {:d} ADC value for debug'.format(i),
                                 offset = 0x80 + (i*4),
                                 bitSize = 32,
                                 bitOffset = 0,
                                 base = 'hex',
                                 mode = "RO"))
            
        # How does this reg reset back to 0?
        self.add(pr.Command(name="LostLockCountReset",
                             description = "Reset LostLockCount",
                             offset = 0x38,
                             bitSize = 1,
                             bitOffset = 0))

        

        
                             
        
        
