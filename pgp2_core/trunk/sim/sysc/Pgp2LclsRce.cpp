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
// Copyright (c) 2009 by SLAC National Accelerator Laboratory. All rights reserved.
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
