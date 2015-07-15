//-----------------------------------------------------------------------------
// File          : Dac38J84.cpp
// Author        : Uros legat <ulegat@slac.stanford.edu>
//                            <uros.legat@cosylab.com>
// Created       : 27/04/2015
// Project       : 
//-----------------------------------------------------------------------------
// Description :
//    Device container for Dac38J84
//-----------------------------------------------------------------------------
// Copyright (c) 2015 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 27/04/2015: created
//-----------------------------------------------------------------------------
#include <Dac38J84.h>
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
Dac38J84::Dac38J84 ( uint32_t linkConfig, uint32_t baseAddress, uint32_t index, Device *parent, uint32_t addrSize ) : 
                        Device(linkConfig,baseAddress,"Dac38J84",index,parent) {

   // Description
   desc_ = "ADC data acquisition control";

   // Create Registers: name, address
   RegisterLink *rl;
   
   addRegisterLink(rl = new RegisterLink("CONFIG_0", baseAddress_ + (0x00*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Various configuration");
   
   addRegisterLink(rl = new RegisterLink("CONFIG_127", baseAddress_ + (0x80*addrSize), Variable::Status));
   rl->getVariable()->setDescription("Errors, Vendor id, version");
   
   // Variables
   getVariable("Enabled")->setHidden(true);
   
   //Commands
}

// Deconstructor
Dac38J84::~Dac38J84 ( ) { }

// Process Commands


