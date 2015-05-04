//-----------------------------------------------------------------------------
// File          : JesdRx.cpp
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
#include <JesdRx.h>
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
JesdRx::JesdRx ( uint32_t linkConfig, uint32_t baseAddress, uint32_t index, Device *parent, uint32_t addrSize ) : 
                        Device(linkConfig,baseAddress,"JesdRx",index,parent) {

   // Description
   desc_ = "Common JESD interface object.";

   // Create Registers: name, address
   RegisterLink *rl;
   
   addRegisterLink(rl = new RegisterLink("Enable",           baseAddress_ + (0x00*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Enables the RX modules: 0x3 - enables both modules at a time");
   
   
   addRegisterLink(rl = new RegisterLink("SysrefDelay",      baseAddress_ + (0x01*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Sets the synchronisation delay in clock cycles");

   addRegisterLink(rl = new RegisterLink("AXISTrigger",      baseAddress_ + (0x02*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Triggers the AXI stream transfer: 0x3 - triggers both modules at a time");
   
   
   addRegisterLink(rl = new RegisterLink("AXISpacketSize",   baseAddress_ + (0x03*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Data packet size (when enabled packets are being sent continuously)"); 

   
   
   addRegisterLink(rl = new RegisterLink("L1Test",      baseAddress_ + (0x12*addrSize), 1, 2,
                                "L1Align",         Variable::Configuration, 0, 0xf,
                                "L1Delay",         Variable::Configuration, 8, 0xf));
                                
   addRegisterLink(rl = new RegisterLink("L2Test",      baseAddress_ + (0x13*addrSize), 1, 2,
                                "L2Align",         Variable::Configuration, 0, 0xf,
                                "L2Delay",         Variable::Configuration, 8, 0xf));
   
   addRegisterLink(rl = new RegisterLink("L1Status",    baseAddress_ + (0x10*addrSize), 1, 10,
                                "L1GTXRdy",        Variable::Status, 0, 0x1,
                                "L1DataValid",     Variable::Status, 1, 0x1, 
                                "L1IlasActive",    Variable::Status, 2, 0x1,
                                "L1nSync",         Variable::Status, 3, 0x1,                                 
                                "L1RxBuffUfl",     Variable::Status, 4, 0x1,
                                "L1RxBuffOfl",     Variable::Status, 5, 0x1,                                 
                                "L1AlignErr",      Variable::Status, 6, 0x1,
                                "L1RxEnabled",     Variable::Status, 7, 0x1,
                                "L1DisparityErr",  Variable::Status, 8, 0xF,
                                "L1DecErr",        Variable::Status, 12,0xF));                                                      
                                
   addRegisterLink(rl = new RegisterLink("L2Status",     baseAddress_ + (0x11*addrSize), 1, 10,
                                "L2GTXRdy",        Variable::Status, 0, 0x1,
                                "L2DataValid",     Variable::Status, 1, 0x1, 
                                "L2IlasActive",    Variable::Status, 2, 0x1,
                                "L2nSync",         Variable::Status, 3, 0x1,                                 
                                "L2RxBuffUfl",     Variable::Status, 4, 0x1,
                                "L2RxBuffOfl",     Variable::Status, 5, 0x1,                                 
                                "L2AlignErr",      Variable::Status, 6, 0x1,
                                "L2RxEnabled",     Variable::Status, 7, 0x1,                                "L1DisparityErr",  Variable::Status, 8, 0xF,
                                "L2DisparityErr",  Variable::Status, 8, 0xF,
                                "L2DecErr",        Variable::Status, 12,0xF));
   // Variables

   //Commands


}

// Deconstructor
JesdRx::~JesdRx ( ) { }

// Process Commands


