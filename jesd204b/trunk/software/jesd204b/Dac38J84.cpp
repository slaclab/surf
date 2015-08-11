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
   Command      *c;
   
  // Description
   desc_ = "DAC data acquisition control";

   // Create Registers: name, address
   for (i=DAC_START_ADDR;i<=DAC_END_ADDR;i++) {
      if (i==0x07) {
         // Temp an lane skew status
         addRegisterLink(rl = new RegisterLink("IntStatus",    baseAddress_ + (0x07*addrSize), 1, 2,
                                "LaneBufferDelay",       Variable::Status, 0, 0x1f,
                                "Temperature",           Variable::Status, 8, 0xff));                                
      }   
      else if (i>=0x1C && i<=0x1D) {
         // Skip reserved
      }      
      else if (i==0x21) {
         // Skip reserved
      }
      else if (i>=0x27 && i<=0x2C) {
         // Skip reserved
      }
      else if (i>=0x35 && i<=0x3A) {
         // Skip reserved
      }
      else if (i==0x40) {
         // Skip reserved
      }
      else if (i==0x41) {
         // Link1 err count
         addRegisterLink(rl = new RegisterLink("L1ErrCnt",    baseAddress_ + (0x41*addrSize), Variable::Status)); 
      }
      else if (i==0x42) {
         // Link2 err count
         addRegisterLink(rl = new RegisterLink("L2ErrCnt",    baseAddress_ + (0x42*addrSize), Variable::Status)); 
      }
      else if (i>=0x43 && i<=0x45) {
         // Skip lanes 3-4
      }
      else if (i==0x50) {
         // Skip Not used
      }
      else if (i==0x53) {
         // Skip Not used
      }
      else if (i==0x56) {
         // Skip Not used
      }
      else if (i==0x59) {
         // Skip Not used
      }
      else if (i==0x5D) {
         // Skip reserved
      }
      else if (i==0x5E) {
         // Skip Not used
      }
      else if (i>=0x62 && i<=0x63) {
         // Skip reserved
      }
      else if (i==0x64) {
         addRegisterLink(rl = new RegisterLink("L1SERDES_alarm",    baseAddress_ + (0x64 *addrSize), 1, 12,
                           "L1ReadFifoEmpty",            Variable::Status, 0,  0x1,
                           "L1ReadFifoUnderflow",        Variable::Status, 1,  0x1, 
                           "L1ReadFifoFull",             Variable::Status, 2,  0x1,
                           "L1ReadFifoOverflow",         Variable::Status, 3,  0x1,                                
                           "L1DispErr",                  Variable::Status, 8,  0x1,
                           "L1NotitableErr",             Variable::Status, 9,  0x1, 
                           "L1CodeSyncErr",              Variable::Status, 10, 0x1,
                           "L1FirstDataMatchErr",        Variable::Status, 11, 0x1,
                           "L1ElasticBuffOverflow",      Variable::Status, 12, 0x1,
                           "L1LinkConfigErr",            Variable::Status, 13, 0x1, 
                           "L1FrameAlignErr",            Variable::Status, 14, 0x1,
                           "L1MultiFrameAlignErr",       Variable::Status, 15, 0x1));
      }
      else if (i==0x65) {
         addRegisterLink(rl = new RegisterLink("L2SERDES_alarm",    baseAddress_ + (0x65 *addrSize), 1, 12,
                           "L2ReadFifoEmpty",            Variable::Status, 0,  0x1,
                           "L2ReadFifoUnderflow",        Variable::Status, 1,  0x1, 
                           "L2ReadFifoFull",             Variable::Status, 2,  0x1,
                           "L2ReadFifoOverflow",         Variable::Status, 3,  0x1,                                
                           "L2DispErr",                  Variable::Status, 8,  0x1,
                           "L2NotitableErr",             Variable::Status, 9,  0x1, 
                           "L2CodeSyncErr",              Variable::Status, 10, 0x1,
                           "L2FirstDataMatchErr",        Variable::Status, 11, 0x1,
                           "L2ElasticBuffOverflow",      Variable::Status, 12, 0x1,
                           "L2LinkConfigErr",            Variable::Status, 13, 0x1, 
                           "L2FrameAlignErr",            Variable::Status, 14, 0x1,
                           "L2MultiFrameAlignErr",       Variable::Status, 15, 0x1)); 
      }
      else if (i==0x66) {
         addRegisterLink(rl = new RegisterLink("L3SERDES_alarm",    baseAddress_ + (i*addrSize), Variable::Status));
         getVariable("L3SERDES_alarm")->setHidden(true);
      }
      else if (i==0x67) {
         addRegisterLink(rl = new RegisterLink("L4SERDES_alarm",    baseAddress_ + (i*addrSize), Variable::Status));
         getVariable("L4SERDES_alarm")->setHidden(true);
      }
      else if (i==0x68) {
         addRegisterLink(rl = new RegisterLink("L5SERDES_alarm",    baseAddress_ + (i*addrSize), Variable::Status));
         getVariable("L5SERDES_alarm")->setHidden(true);
      }
      else if (i==0x69) {
         addRegisterLink(rl = new RegisterLink("L6SERDES_alarm",    baseAddress_ + (i*addrSize), Variable::Status));
         getVariable("L6SERDES_alarm")->setHidden(true);
      }
      else if (i==0x6A) {
         addRegisterLink(rl = new RegisterLink("L7SERDES_alarm",    baseAddress_ + (i*addrSize), Variable::Status));
         getVariable("L7SERDES_alarm")->setHidden(true);
      }
      else if (i==0x6B) {
         addRegisterLink(rl = new RegisterLink("L8SERDES_alarm",    baseAddress_ + (i*addrSize), Variable::Status));
         getVariable("L8SERDES_alarm")->setHidden(true);
      }
      else if (i==0x6C) {
         addRegisterLink(rl = new RegisterLink("Syserf_alarm",    baseAddress_ + (0x6C*addrSize), 1, 3,
                        "Serdes1pllAlarm",           Variable::Status, 2, 0x1,
                        "Serdes0pllAlarm",           Variable::Status, 3, 0x1,
                        "SysRefAlarms",              Variable::Status,12, 0xf));
      }
      else if (i==0x6D) {
         addRegisterLink(rl = new RegisterLink("Lane_alarm",    baseAddress_ + (0x6D*addrSize), 1, 4,
                        "Lane1Loss",            Variable::Status, 0, 0x1,
                        "Lane2Loss",            Variable::Status, 1, 0x1,          
                        "Lane1Alarm",           Variable::Status, 8, 0x1,
                        "Lane2Alarm",           Variable::Status, 9, 0x1 ));
      }
      else if (i==0x7E) {
         // Skip reserved
      }
      else if (i==0x7F) {
         // Serials and IDs
         addRegisterLink(rl = new RegisterLink("IDs",    baseAddress_ + (0x7F*addrSize), Variable::Status)); 
      }
      else {
         tmp.str("");
         tmp << "DacReg" << hex << setw(4) << setfill('0') << hex << i;
         addRegisterLink(rl = new RegisterLink(tmp.str(), (baseAddress_+ (i*addrSize)), Variable::Configuration));
         rl->getVariable()->setPerInstance(true);
      }
   }  
   
   // Variables
   getVariable("Enabled")->setHidden(true);
   
   //Commands
   addCommand(c = new Command("ClearDACAlarms"));
   c->setDescription("Clear all the DAC alarms.");
   
   addCommand(c = new Command("InitDAC_JESD"));
   c->setDescription("Initialialization sequence for the DAC JESD core");
}

// Deconstructor
Dac38J84::~Dac38J84 ( ) { }

// Process Commands
void Dac38J84::command(string name, string arg) {
   if (name == "ClearDACAlarms") clrAlarms();
   else if (name == "InitDAC_JESD") initDac();
   else Device::command(name,arg);
}

//! Clear alarms
void Dac38J84::clrAlarms () {

   Register *r;
   
   REGISTER_LOCK
   
   r = getRegister("L1SERDES_alarm");
   r->set(0x0,0,0xffff);
   writeRegister(r, true, false);
   r = getRegister("L2SERDES_alarm");
   r->set(0x0,0,0xffff);
   writeRegister(r, true, false);
   r = getRegister("L3SERDES_alarm");
   r->set(0x0,0,0xffff);
   writeRegister(r, true, false);
   r = getRegister("L4SERDES_alarm");
   r->set(0x0,0,0xffff);
   writeRegister(r, true, false);
   r = getRegister("L5SERDES_alarm");
   r->set(0x0,0,0xffff);
   writeRegister(r, true, false);
   r = getRegister("L6SERDES_alarm");
   r->set(0x0,0,0xffff);
   writeRegister(r, true, false);
   r = getRegister("L7SERDES_alarm");
   r->set(0x0,0,0xffff);
   writeRegister(r, true, false);
   r = getRegister("L8SERDES_alarm");
   r->set(0x0,0,0xffff);
   writeRegister(r, true, false);
   r = getRegister("Syserf_alarm");
   r->set(0x0,0,0xffff);
   writeRegister(r, true, false);
   
   REGISTER_UNLOCK

}

//! Initialisation process
void Dac38J84::initDac () {

   Register *r;
   
   REGISTER_LOCK
   
   // Disable TX
   r = getRegister("DacReg0003");
   r->set(0x0,0,0x1);
   writeRegister(r, true, false);
   
   // Disable and initialize JESD
   r = getRegister("DacReg004a");
   r->set(0x1E,0,0x1f);
   writeRegister(r, true, false);
   
   // Enable JESD
   r = getRegister("DacReg004a");
   r->set(0x01,0,0x1f);
   writeRegister(r, true, false);
   
   // Enable TX
   r = getRegister("DacReg0003");
   r->set(0x1,0,0x1);
   writeRegister(r, true, false);
   
   REGISTER_UNLOCK

}






