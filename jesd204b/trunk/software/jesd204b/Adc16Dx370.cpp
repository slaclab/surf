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
   for (i=ADC_START_ADDR;i<=ADC_END_ADDR;i++) {
      if      (i==0x01) {
         // Skip reserved
      }
      else if (i>=0x7 && i<=0xB) {
         // Skip reserved
      }
      else if (i>=0x16 && i<=0x18) {
         // Skip reserved
      }
      else if (i>=0x1A && i<=0x3A) {
         // Skip reserved
      }
      else if (i>=0x3E && i<=0x46) {
         // Skip reserved
      }
      else if (i>=0x48 && i<=0x5F) {
         // Skip reserved
      }
      else if (i>=0x64 && i<=0x6B) {
         // Skip reserved
      }
      else if (i==0x6C) {
         // Status register
         addRegisterLink(rl = new RegisterLink("ADC_Status",    baseAddress_ + (0x6C*addrSize), 1, 7,
                                "Clock_ready",           Variable::Status, 0, 0x1,
                                "Calibration_done",      Variable::Status, 1, 0x1, 
                                "PLL_lock",              Variable::Status, 2, 0x1,
                                "Aligned_to_sysref",     Variable::Status, 3, 0x1,                                 
                                "Realigned_to_sysref",   Variable::Status, 4, 0x1,
                                "Sync_form_FPGA",        Variable::Status, 5, 0x1,                                 
                                "Link_active",           Variable::Status, 6, 0x1));                                
      }
      else if (i>=0x6D && i<=0x6F) {
         // Skip reserved
      }
      else if (i==0x71) {
         // Skip reserved
      }
      else {
         tmp.str("");
         tmp << "AdcReg0x" << hex << setw(4) << setfill('0') << hex << i;
         addRegisterLink(rl = new RegisterLink(tmp.str(), (baseAddress_+ (i*addrSize)), Variable::Configuration));
         rl->getVariable()->setPerInstance(true);
      }
   }  

   

   // Variables
   getVariable("Enabled")->setHidden(true);
   
   
   //Commands
}

// Deconstructor
Adc16Dx370::~Adc16Dx370 ( ) { }

// Process Commands


