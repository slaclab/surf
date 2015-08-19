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
   uint32_t i;
   RegisterLink *rl;
   stringstream tmp; 
   
   Command      *c;
   
  // Description
   desc_ = "LMK data acquisition control";
   
   for (i=START_ADDR;i<=END_ADDR;i++) {
      if      (i==0x102) {
         // Skip reserved
      }
      else if (i==0x10a) {
         // Skip reserved
      }
      else if (i==0x112) {
         // Skip reserved
      } 
      else if (i==0x122) {
         // Skip reserved
      } 
      else if (i==0x12a) {
         // Skip reserved
      } 
      else if (i==0x132) {
         // Skip reserved
      }
      else if (i>=0x16f && i<=0x172) {
         // Skip reserved
      }
      else if (i>=0x175 && i<=0x17b) {
         // Skip reserved
      }      
      else {
         tmp.str("");
         tmp << "LmkReg" << hex << setw(4) << setfill('0') << hex << i;
         addRegisterLink(rl = new RegisterLink(tmp.str(), (baseAddress_+ (i*addrSize)), Variable::Configuration));
         rl->getVariable()->setPerInstance(true);
      
      }
   }

   // Variables
   getVariable("Enabled")->setHidden(true);
   
   //Commands
   addCommand(c = new Command("SyncClks"));
   c->setDescription("Synchronise LMK internal counters. Warning this function will power off and power on all the system clocks ");
}

// Deconstructor
Lmk04828::~Lmk04828 ( ) { }

// Process Commands
void Lmk04828::command(string name, string arg) {
   if (name == "SyncClks") SyncClks();
   else Device::command(name,arg);
}

//! Synchronise internal counters
//! Warning this function will power off and power on all the system clocks 
 void Lmk04828::SyncClks () {

   Register *r;
   
   REGISTER_LOCK

      // Turn on normal SYNC
      r = getRegister("LmkReg0139");
      r->set(0x0,0,0x3);
      writeRegister(r, true);
      
      // Poweron SYNC
      r = getRegister("LmkReg0144");
      r->set(0x0,0,0xff);
      writeRegister(r, true);
      
      sleep(1);
      // Toggle Sync bit
      r = getRegister("LmkReg0143");
      r->set(0x1,5,0x1);
      writeRegister(r, true);
      r = getRegister("LmkReg0143");
      r->set(0x0,5,0x1);
      writeRegister(r, true);
      
      sleep(1);
      // Turn on normal continuous sysref
      r = getRegister("LmkReg0139");
      r->set(0x3,0,0x3);
      writeRegister(r, true);
      
      // Poweron down SYNC to not let it interfere
      r = getRegister("LmkReg0144");
      r->set(0xff,0,0xff);
      writeRegister(r, true);   
   
   REGISTER_UNLOCK

}

// //! Powerup the sysref lines.
// void Lmk04828::syarefOn () {

   // Register *r;
   
   // REGISTER_LOCK
   
   // r = getRegister("LmkReg0139");
   // r->set(0x3,0,0x3);
   // writeRegister(r, true);
   
   // r = getRegister("LmkReg0106");
   // r->set(0x0,0,0x1);
   // writeRegister(r, true);

   // r = getRegister("LmkReg010e");
   // r->set(0x0,0,0x1);
   // writeRegister(r, true);
   
   // r = getRegister("LmkReg0116");
   // r->set(0x0,0,0x1);
   // writeRegister(r, true);
   
   // r = getRegister("LmkReg011e");
   // r->set(0x0,0,0x1);
   // writeRegister(r, true);
   
   // r = getRegister("LmkReg0126");
   // r->set(0x0,0,0x1);
   // writeRegister(r, true);
   
   // r = getRegister("LmkReg012e");
   // r->set(0x0,0,0x1);
   // writeRegister(r, true);
   
   // r = getRegister("LmkReg0136");
   // r->set(0x0,0,0x1);
   // writeRegister(r, true);
   
   // REGISTER_UNLOCK
// }


