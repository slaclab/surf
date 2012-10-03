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

   // Description
   desc_    = "Saci ASIC Object.";

   addRegister(new Register("RegA", baseAddress_ + 0x00000008));

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




   REGISTER_UNLOCK
}

// Method to write configuration registers
void SaciAsic::writeConfig ( bool force ) {
   REGISTER_LOCK



   REGISTER_UNLOCK
}

// Verify hardware state of configuration
void SaciAsic::verifyConfig ( ) {
   REGISTER_LOCK




   REGISTER_UNLOCK
}

