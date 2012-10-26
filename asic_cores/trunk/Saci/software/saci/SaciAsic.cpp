#include <SaciAsic.h>
#include <Register.h>
#include <Variable.h>
#include <Command.h>
#include <sstream>
#include <iostream>
#include <string>
#include <iomanip>
using namespace std;

// Constructor
SaciAsic::SaciAsic ( uint destination, uint baseAddress, uint index, Device *parent ) : 
                     Device(destination,baseAddress,"saciAsic",index,parent) {

   stringstream tmp;
   
   // Description
   desc_    = "Saci ASIC Object.";
   /*   
   for (uint i=0; i < 2; i++) {
      for (uint j=0; j < 1024; j++) {
         tmp.str("");
         tmp << "Reg_" << setw(3) << setfill('0') << dec << i << "_" << setw(4) << setfill('0') << dec << j;
         addRegister(new Register(tmp.str(), baseAddress_ + i<<12+j));
         //cout << tmp.str() << ": " << baseAddress_ + i<<12+j << hex << endl;
      }
   }
   */

   addRegister(new Register("Reg_00_000", baseAddress_));
   addVariable(new Variable("Reg_00_000", Variable::Configuration));
   getVariable("Reg_00_000")->setDescription("Test Register");
   getVariable("Reg_00_000")->setPerInstance(true);
   
   addRegister(new Register("Reg_2A_AAA", baseAddress_ + (0x2aaaa)));
   addVariable(new Variable("Reg_2A_AAA", Variable::Configuration));
   getVariable("Reg_2A_AAA")->setDescription("Test Register");
   getVariable("Reg_2A_AAA")->setPerInstance(true);

   addRegister(new Register("Reg_55_555", baseAddress_ + (0x55555)));
   addVariable(new Variable("Reg_55_555", Variable::Configuration));
   getVariable("Reg_55_555")->setDescription("Test Register");
   getVariable("Reg_55_555")->setPerInstance(true);

   addRegister(new Register("Reg_7F_FFF", baseAddress_ + (0x7ffff)));
   addVariable(new Variable("Reg_7F_FFF", Variable::Configuration));
   getVariable("Reg_7F_FFF")->setDescription("Test Register");
   getVariable("Reg_7F_FFF")->setPerInstance(true);
}

// Deconstructor
SaciAsic::~SaciAsic ( ) { }

// Method to read status registers and update variables
void SaciAsic::readStatus ( ) {
   REGISTER_LOCK

        

   REGISTER_UNLOCK
}

// Method to read configuration registers and update variables
void SaciAsic::readConfig ( ) {
   REGISTER_LOCK

   readRegister(getRegister("Reg_00_000"));
   getVariable("Reg_00_000")->setInt(getRegister("Reg_00_000")->get());

   readRegister(getRegister("Reg_2A_AAA"));
   getVariable("Reg_2A_AAA")->setInt(getRegister("Reg_2A_AAA")->get());

   readRegister(getRegister("Reg_55_555"));
   getVariable("Reg_55_555")->setInt(getRegister("Reg_55_555")->get());
   
   readRegister(getRegister("Reg_7F_FFF"));
   getVariable("Reg_7F_FFF")->setInt(getRegister("Reg_7F_FFF")->get());

   
   REGISTER_UNLOCK
}

// Method to write configuration registers
void SaciAsic::writeConfig ( bool force ) {
   REGISTER_LOCK

   getRegister("Reg_00_000")->set(getVariable("Reg_00_000")->getInt());
   writeRegister(getRegister("Reg_00_000"),force);
   
   getRegister("Reg_2A_AAA")->set(getVariable("Reg_2A_AAA")->getInt());
   writeRegister(getRegister("Reg_2A_AAA"),force);
   
   getRegister("Reg_55_555")->set(getVariable("Reg_55_555")->getInt());
   writeRegister(getRegister("Reg_55_555"),force);
   
   getRegister("Reg_7F_FFF")->set(getVariable("Reg_7F_FFF")->getInt());
   writeRegister(getRegister("Reg_7F_FFF"),force);
   
 

   REGISTER_UNLOCK
}

// Verify hardware state of configuration
void SaciAsic::verifyConfig ( ) {
   REGISTER_LOCK

   verifyRegister(getRegister("Reg_00_000"));
   verifyRegister(getRegister("Reg_2A_AAA"));
   verifyRegister(getRegister("Reg_55_555"));
   verifyRegister(getRegister("Reg_7F_FFF"));
   
   REGISTER_UNLOCK
}

