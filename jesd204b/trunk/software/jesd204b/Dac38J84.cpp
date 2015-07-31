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
   uint32_t i;
   RegisterLink *rl;
   stringstream tmp;
   
  // Description
   desc_ = "DAC data acquisition control";

   // Create Registers: name, address
   for (i=START_ADDR;i<=END_ADDR;i++) {
      tmp.str("");
      tmp << "DacReg" << hex << setw(4) << setfill('0') << hex << i;
      addRegisterLink(rl = new RegisterLink(tmp.str(), (baseAddress_+ (i*addrSize)), Variable::Configuration));
      rl->getVariable()->setPerInstance(true);                                                                              
   }  

   // Variables
   getVariable("Enabled")->setHidden(true);
   
   //Commands
}

// Deconstructor
Dac38J84::~Dac38J84 ( ) { }

// Process Commands


