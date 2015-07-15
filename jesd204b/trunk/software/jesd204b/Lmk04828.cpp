//-----------------------------------------------------------------------------
// File          : Lmk04828.cpp
// Author        : Uros legat <ulegat@slac.stanford.edu>
//                            <uros.legat@cosylab.com>
// Created       : 27/04/2015
// Project       : 
//-----------------------------------------------------------------------------
// Description :
//    Device container for Lmk04828
//-----------------------------------------------------------------------------
// Copyright (c) 2015 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 27/04/2015: created
//-----------------------------------------------------------------------------
#include <Lmk04828.h>
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
Lmk04828::Lmk04828 ( uint32_t linkConfig, uint32_t baseAddress, uint32_t index, Device *parent, uint32_t addrSize ) : 
                        Device(linkConfig,baseAddress,"Lmk04828",index,parent) {

   // Description
   desc_ = "ADC data acquisition control";

   // Create Registers: name, address
   RegisterLink *rl;
   
   addRegisterLink(rl = new RegisterLink("CONFIG_0", baseAddress_ + (0x00*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Reset etc.");
   
   addRegisterLink(rl = new RegisterLink("CONFIG_1", baseAddress_ + (0x02*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Powerdown");
   
   addRegisterLink(rl = new RegisterLink("CONFIG_2", baseAddress_ + (0x03*addrSize), Variable::Status));
   rl->getVariable()->setDescription("Device Type");
   
   // Variables
   getVariable("Enabled")->setHidden(true);
      
   //Commands
}

// Deconstructor
Lmk04828::~Lmk04828 ( ) { }

// Process Commands


