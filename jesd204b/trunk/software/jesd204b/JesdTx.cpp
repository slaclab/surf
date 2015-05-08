//-----------------------------------------------------------------------------
// File          : JesdTx.cpp
// Author        : Uros legat <ulegat@slac.stanford.edu>
//                            <uros.legat@cosylab.com>
// Created       : 27/04/2015
// Project       : 
//-----------------------------------------------------------------------------
// Description :
//    Device container for Jesd204b
//-----------------------------------------------------------------------------
// Copyright (c) 2015 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 27/04/2015: created
//-----------------------------------------------------------------------------
#include <JesdTx.h>
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
JesdTx::JesdTx ( uint32_t linkConfig, uint32_t baseAddress, uint32_t index, Device *parent, uint32_t addrSize ) : 
                        Device(linkConfig,baseAddress,"JesdTx",index,parent) {

   // Description
   desc_ = "Common JESD interface object.";

   // Create Registers: name, address
   RegisterLink *rl;
   
   addRegisterLink(rl = new RegisterLink("Enable",           baseAddress_ + (0x00*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Enables the Tx modules: 0x3 - enables both modules at a time");
   
   
   addRegisterLink(rl = new RegisterLink("SysrefDelay",      baseAddress_ + (0x01*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Sets the synchronisation delay in clock cycles");

   addRegisterLink(rl = new RegisterLink("AXISTrigger",      baseAddress_ + (0x02*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Triggers the AXI stream transfer: 0x3 - triggers both modules at a time");
   
   
   addRegisterLink(rl = new RegisterLink("AXISpacketSize",   baseAddress_ + (0x03*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Data packet size (when enabled packets are being sent continuously)"); 

   addRegisterLink(rl = new RegisterLink("ReplaceEnable",    baseAddress_ + (0x04*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Enable character replacement module(if disabled the transmitter will not emit control characters). Default '1'.");

     
   addRegisterLink(rl = new RegisterLink("L1_Status",    baseAddress_ + (0x10*addrSize), 1, 4,
                                "L1_GTXRdy",        Variable::Status, 0, 0x1,
                                "L1_DataValid",     Variable::Status, 1, 0x1, 
                                "L1_IlasActive",    Variable::Status, 2, 0x1,
                                "L1_nSync",         Variable::Status, 3, 0x1));                                                      
                                
   addRegisterLink(rl = new RegisterLink("L2_Status",     baseAddress_ + (0x11*addrSize), 1, 4,
                                "L2_GTXRdy",        Variable::Status, 0, 0x1,
                                "L2_DataValid",     Variable::Status, 1, 0x1, 
                                "L2_IlasActive",    Variable::Status, 2, 0x1,
                                "L2_nSync",         Variable::Status, 3, 0x1));
   // Variables

   //Commands


}

// Deconstructor
JesdTx::~JesdTx ( ) { }

// Process Commands


