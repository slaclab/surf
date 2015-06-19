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

   addRegisterLink(rl = new RegisterLink("CommonControl",    baseAddress_ + (0x04*addrSize), 1, 4,
                                "SubClass",              Variable::Configuration, 0, 0x1,
                                "ReplaceEnable",         Variable::Configuration, 1, 0x1,
                                "ResetGTs",              Variable::Configuration, 2, 0x1,
                                "ClearErrors",           Variable::Configuration, 3, 0x1));   
     
   addRegisterLink(rl = new RegisterLink("L1_Test",      baseAddress_ + (0x20*addrSize), 1, 2,
                                "L1_Align",         Variable::Configuration, 0, 0xf,
                                "L1_Delay",         Variable::Configuration, 8, 0xf));
                                
   addRegisterLink(rl = new RegisterLink("L2_Test",      baseAddress_ + (0x21*addrSize), 1, 2,
                                "L2_Align",         Variable::Configuration, 0, 0xf,
                                "L2_Delay",         Variable::Configuration, 8, 0xf));
                              
   addRegisterLink(rl = new RegisterLink("L1_Test_thr",      baseAddress_ + (0x30*addrSize), 1, 2,
                                "L1_Threshold_Low",         Variable::Configuration, 0,  0xffff,
                                "L1_Threshold_High",        Variable::Configuration, 16, 0xffff));
                                
   addRegisterLink(rl = new RegisterLink("L1_Test_thr",      baseAddress_ + (0x31*addrSize), 1, 2,
                                "L2_Threshold_Low",         Variable::Configuration, 0,  0xffff,
                                "L2_Threshold_High",        Variable::Configuration, 16, 0xffff));

   addRegisterLink(rl = new RegisterLink("L1_Status",    baseAddress_ + (0x10*addrSize), 1, 12,
                                "L1_GTXReady",       Variable::Status, 0, 0x1,
                                "L1_DataValid",     Variable::Status, 1, 0x1, 
                                "L1_AlignErr",      Variable::Status, 2, 0x1,
                                "L1_nSync",         Variable::Status, 3, 0x1,                                 
                                "L1_RxBuffUfl",     Variable::Status, 4, 0x1,
                                "L1_RxBuffOfl",     Variable::Status, 5, 0x1,                                 
                                "L1_PositionErr",   Variable::Status, 6, 0x1,
                                "L1_RxEnabled",     Variable::Status, 7, 0x1,
                                "L1_SysRefDetected",Variable::Status, 8, 0x1,
                                "L1_CommaDetected", Variable::Status, 9, 0x1,                               
                                "L1_DisparityErr",  Variable::Status, 10,0xF,
                                "L1_DecErr",        Variable::Status, 14,0xF));                                                      
                                
   addRegisterLink(rl = new RegisterLink("L2_Status",     baseAddress_ + (0x11*addrSize), 1, 12,
                                "L2_GTXRdy",        Variable::Status, 0, 0x1,
                                "L2_DataValid",     Variable::Status, 1, 0x1, 
                                "L2_AlignErr",      Variable::Status, 2, 0x1,
                                "L2_nSync",         Variable::Status, 3, 0x1,                                 
                                "L2_RxBuffUfl",     Variable::Status, 4, 0x1,
                                "L2_RxBuffOfl",     Variable::Status, 5, 0x1,                                 
                                "L2_PositionErr",   Variable::Status, 6, 0x1,
                                "L2_RxEnabled",     Variable::Status, 7, 0x1,
                                "L2_SysRefDetected",Variable::Status, 8, 0x1,
                                "L2_CommaDetected", Variable::Status, 9, 0x1,                               
                                "L2_DisparityErr",  Variable::Status, 10,0xF,
                                "L2_DecErr",        Variable::Status, 14,0xF));
   // Variables

   //Commands


}

// Deconstructor
JesdRx::~JesdRx ( ) { }

// Process Commands


