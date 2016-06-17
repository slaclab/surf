#ifndef __SACI_ASIC_H__
#define __SACI_ASIC_H__

#include <Device.h>
using namespace std;

//! Class to contain Saci ASIC
class SaciAsic : public Device {

   public:

      //! Constructor
      /*! 
       * \param destination Device destination
       * \param baseAddress Device base address
       * \param index       Device index
       * \param parent      Parent device
      */
      SaciAsic ( uint destination, uint baseAddress, uint index, Device *parent );

      //! Deconstructor
      ~SaciAsic ( );

      //! Method to read status registers and update variables
      /*! 
       * Throws string on error.
      */
      void readStatus ( );

      //! Method to read configuration registers and update variables
      /*! 
       * Throws string on error.
      */
      void readConfig ( );

      //! Method to write configuration registers
      /*! 
       * Throws string on error.
       * \param force Write all registers if true, only stale if false
      */
      void writeConfig ( bool force );

      //! Verify hardware state of configuration
      void verifyConfig ( );

};
#endif
