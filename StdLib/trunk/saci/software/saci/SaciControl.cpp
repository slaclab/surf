#include <SaciControl.h>
#include <CntrlFpga.h>
#include <Register.h>
#include <Variable.h>
#include <Command.h>
#include <CommLink.h>
#include <sstream>
#include <iostream>
#include <string>
#include <iomanip>
using namespace std;

// Constructor
SaciControl::SaciControl ( CommLink *commLink, string defFile ) : System("SaciControl",commLink) {

   // Description
   desc_ = "Saci Control";
   
   // Data mask, lane 0, vc 0
   commLink->setDataMask(0x11);

   if ( defFile == "" ) defaults_ = "xml/defaults.xml";
   else defaults_ = defFile;

   // Add sub-devices
   addDevice(new CntrlFpga(0, 0, this));
}

// Deconstructor
SaciControl::~SaciControl ( ) { }

