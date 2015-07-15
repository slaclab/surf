//-----------------------------------------------------------------------------
// File          : Adc16Dx370.cpp
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
#include <Adc16Dx370.h>
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
Adc16Dx370::Adc16Dx370 ( uint32_t linkConfig, uint32_t baseAddress, uint32_t index, Device *parent, uint32_t addrSize ) : 
                        Device(linkConfig,baseAddress,"Adc16Dx370",index,parent) {

   // Description
   desc_ = "ADC data acquisition control";

   // Create Registers: name, address
   RegisterLink *rl;
   
   addRegisterLink(rl = new RegisterLink("CONFIG_A", baseAddress_ + (0x00*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Reset etc.");
   
   addRegisterLink(rl = new RegisterLink("DEVICE_CONFIG", baseAddress_ + (0x02*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Device configuration.");

   addRegisterLink(rl = new RegisterLink("CHIP_TYPE",      baseAddress_ + (0x03*addrSize), Variable::Status));
   rl->getVariable()->setDescription("Type");

   addRegisterLink(rl = new RegisterLink("CHIP_ID_0",   baseAddress_ + (0x04*addrSize), Variable::Status));
   rl->getVariable()->setDescription("ID byte 0");
   
   addRegisterLink(rl = new RegisterLink("CHIP_ID_1",   baseAddress_ + (0x05*addrSize), Variable::Status));
   rl->getVariable()->setDescription("ID byte 1");

   addRegisterLink(rl = new RegisterLink("CHIP_VERSION",    baseAddress_ + (0x06*addrSize), Variable::Status));
   rl->getVariable()->setDescription("Version");                                                   
   
   addRegisterLink(rl = new RegisterLink("SPI_CFG",    baseAddress_ + (0x10*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Output voltage level always 1 (3V)");

   // Variables
   getVariable("Enabled")->setHidden(true);
   
   
   //Commands
}

// Deconstructor
Adc16Dx370::~Adc16Dx370 ( ) { }

// Process Commands


