#ifndef __SACI_CONTROL_H__
#define __SACI_CONTROL_H__

#include <System.h>
using namespace std;

class CommLink;

//! Class to contain APV25 
class SaciControl : public System {

   public:

      //! Constructor
      SaciControl ( CommLink *commLink_, string defFile );

      //! Deconstructor
      ~SaciControl ( );

};
#endif
