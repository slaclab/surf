//----------------------------------------------------------------------------------------
// Title         : PGP Virtual Channel, SystemC LCLS RCE Model
// Project       : PGP Version 2
//----------------------------------------------------------------------------------------
// File          : Pgp2LclsRce.cpp
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 12/02/2009
//----------------------------------------------------------------------------------------
// Description:
// Class to model LCLS RCE operations
//----------------------------------------------------------------------------------------
// This file is part of 'SLAC PGP2 Core'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC PGP2 Core', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//----------------------------------------------------------------------------------------
// Modification history:
// 12/02/2009: created.
//----------------------------------------------------------------------------------------
#include "Pgp2LclsRce.h"
#include <iomanip>
using namespace std;


void Pgp2LclsRce::runThread() {

   // Initial pause
   wait(10,SC_NS);

   while ( pgpLinkReady.read() == 0 ) wait(10,SC_NS);

   










   while (1) wait(1,SC_MS);

}
