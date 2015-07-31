//-----------------------------------------------------------------------------
// File          : Adc16Dx370.cpp
// Author        : Uros legat <ulegat@slac.stanford.edu>
//                            <uros.legat@cosylab.com>
// Created       : 27/04/2015
// Project       : 
//-----------------------------------------------------------------------------
// Description :
//    Device container for Adc16Dx370
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
   uint32_t i;
   RegisterLink *rl;
   stringstream tmp;
   
   // Description
   desc_ = "ADC data acquisition control";

   // Create Registers: name, address
   for (i=START_ADDR;i<=END_ADDR;i++) {
      tmp.str("");
      tmp << "AdcReg0x" << hex << setw(4) << setfill('0') << hex << i;
      addRegisterLink(rl = new RegisterLink(tmp.str(), (baseAddress_+ (i*addrSize)), Variable::Configuration));
      rl->getVariable()->setPerInstance(true);                                                                                  
   }   

   // Variables
   getVariable("Enabled")->setHidden(true);
   
   
   //Commands
}

// Deconstructor
Adc16Dx370::~Adc16Dx370 ( ) { }

// Process Commands


