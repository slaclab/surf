//-----------------------------------------------------------------------------
// File          : JesdRxDaq.cpp
// Author        : Uros legat <ulegat@slac.stanford.edu>
//                            <uros.legat@cosylab.com>
// Created       : 27/04/2015
// Project       : 
//-----------------------------------------------------------------------------
// Description :
//    Device container for Rx DAQ
//-----------------------------------------------------------------------------
// Copyright (c) 2015 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 27/04/2015: created
//-----------------------------------------------------------------------------
#include <JesdRxDaq.h>
#include <Register.h>
#include <RegisterLink.h>
#include <Variable.h>
#include <Command.h>
#include <sstream>
#include <iostream>
#include <string>
#include <iomanip>
using namespace std;

// Constructor
JesdRxDaq::JesdRxDaq ( uint32_t linkConfig, uint32_t baseAddress, uint32_t index, Device *parent, uint32_t addrSize ) : 
                        Device(linkConfig,baseAddress,"JesdRxDaq",index,parent) {

   // Description
   desc_ = "ADC data acquisition control";

   // Create Registers: name, address
   RegisterLink *rl;
   
   addRegisterLink(rl = new RegisterLink("SwDaqTrigger", baseAddress_ + (0x00*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Trigger data acquisition (bit0 - Auto clear register)");
   
   addRegisterLink(rl = new RegisterLink("DaqBusy", baseAddress_ + (0x01*addrSize), Variable::Status));
   rl->getVariable()->setDescription("Indicates that the data acquisition is in progress");

   addRegisterLink(rl = new RegisterLink("SampleDecimation", baseAddress_ + (0x02*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Reduces the sample rate (0 - SR, 1 - SR/2, 2 - SR/4, 2 - SR/6 etc)");

   addRegisterLink(rl = new RegisterLink("DaqBufferSize", baseAddress_ + (0x03*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Size of a single continuous data buffer"); 

   addRegisterLink(rl = new RegisterLink("S1ChannelSelect", baseAddress_ + (0x10*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Select channel for AXI stream 1 (0 - Disabled, 1 - Ch1, etc)");                                                    
   
   addRegisterLink(rl = new RegisterLink("S2ChannelSelect", baseAddress_ + (0x11*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Select channel for AXI stream 2 (0 - Disabled, 1 - Ch1, etc)");     

   // Variables
   getVariable("Enabled")->setHidden(true);
   //Commands
}

// Deconstructor
JesdRxDaq::~JesdRxDaq ( ) { }

// Process Commands


