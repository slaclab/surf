/*
Hamming Generator - Generates VHDL package with hamming encoder and decoder
Copyright (C) 2006  Alexandre de Morais Amory (amamory at gmail.com)

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA
http://www.fsf.org/licensing/licenses/gpl.txt
*/
#include "hamm_sec_gen.h"
#include <math.h>
#include <sstream>
#include <fstream>
#include <iostream>

#include <cstring>
using namespace std;

HammingSec::HammingSec(int dBits)
{
    dataBits = dBits;
    // minus 1 parity since this code does not detect two errors
    parityBits  = GetParityBits(dataBits)-1;
}

HammingSec::~HammingSec()
{
  fclose(fp);
}

//---------------------------------------------------------------------------
// MAIN FUNCTIONS
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
//  Main Function
void HammingSec::GeneratePackageFile(string targetFile)
{
  if ((fp = fopen(targetFile.c_str(),"w"))==NULL){
    printf("\nERROR: file \"%s\" cannot be created!!\n",targetFile.c_str());
    exit(0);
  }

// writing the package, subtypes and functions
fprintf(fp,"LIBRARY ieee;\n"
"USE ieee.std_logic_1164.all;\n"
"USE ieee.std_logic_unsigned.all;\n\n"
"PACKAGE hamm_package_%dbit IS\n"
"\tSUBTYPE parity_ham_%dbit IS std_logic_vector(%d DOWNTO 0);\n"
"\tSUBTYPE data_ham_%dbit IS std_logic_vector(%d DOWNTO 0);\n"
"\tSUBTYPE coded_ham_%dbit IS std_logic_vector(%d DOWNTO 0);\n\n"
"\tFUNCTION hamming_encoder_%dbit(data_in:data_ham_%dbit) RETURN parity_ham_%dbit;\n"
"\tFUNCTION hamming_decoder_%dbit(data_parity_in:coded_ham_%dbit) RETURN data_ham_%dbit;\n"
"END hamm_package_%dbit;\n\n",dataBits,dataBits,parityBits,dataBits,dataBits-1,dataBits,dataBits+parityBits,
dataBits,dataBits,dataBits,dataBits,dataBits,dataBits,dataBits);

// writing the package body
fprintf(fp,"PACKAGE BODY hamm_package_%dbit IS\n\n"
"---------------------\n"
"-- HAMMING ENCODER --\n"
"---------------------\n"
"FUNCTION hamming_encoder_%dbit(data_in:data_ham_%dbit) RETURN parity_ham_%dbit  IS\n"
"\tVARIABLE parity: parity_ham_%dbit;\n"
"BEGIN\n",dataBits,dataBits,dataBits,dataBits,dataBits);

   GenerateGen();

fprintf(fp,"\n\tRETURN parity;\nEND;\n\n");

fprintf(fp,
"---------------------\n"
"-- HAMMING DECODER --\n"
"---------------------\n"
"FUNCTION hamming_decoder_%dbit(data_parity_in:coded_ham_%dbit) RETURN data_ham_%dbit IS\n"
"\tVARIABLE coded       : coded_ham_%dbit;\n"
"\tVARIABLE mask        : coded_ham_%dbit;\n"
"\tVARIABLE parity      : parity_ham_%dbit;\n"
"\tVARIABLE parity_in   : parity_ham_%dbit;\n"
"\tVARIABLE syn         : parity_ham_%dbit;\n"
"\tVARIABLE data_in     : data_ham_%dbit;\n"
"\tVARIABLE decoded     : data_ham_%dbit;\n"
"BEGIN\n\n"
"\tdata_in   := data_parity_in(%d DOWNTO %d);\n"
"\tparity_in := data_parity_in(%d DOWNTO 0);\n",dataBits,dataBits,
  dataBits,dataBits,dataBits,dataBits,dataBits,dataBits,dataBits,
  dataBits,dataBits+parityBits,parityBits+1,parityBits);

   GenerateGen();
   GenerateEnc();
   GenerateCorrector();

fprintf(fp,"\tRETURN decoded;\nEND;\nEND PACKAGE BODY;\n");

}

void HammingSec::GenerateTBFile(string targetFile){
   ofstream tbFile;

   tbFile.open(targetFile.c_str(),ios::out);
   if(tbFile.is_open()){
      tbFile << writeTB();
      tbFile.close();
   }else{
      cout << "WARNING: Could not create testbench.\n";
      exit(-1);
   }
}      

string HammingSec::writeTB(void){
   stringstream tbFile;
tbFile << "--================================================================--" << endl;
tbFile << "-- FAULT-TOLERANT REGISTER --" << endl;
tbFile << "--================================================================--" << endl;
tbFile << "library ieee;" << endl;
tbFile << "use ieee.std_logic_1164.all;" << endl;
tbFile << "use work.hamm_package_" << dataBits << "bit.all;" << endl << endl;

tbFile << "entity reg is" << endl;
tbFile << "port(" << endl;
tbFile << "  clock   : in  std_logic;" << endl;
tbFile << "  datain  : in  data_ham_" << dataBits << "bit;" << endl;
tbFile << "  dataout : out data_ham_" << dataBits << "bit" << endl;
tbFile << ");" << endl;
tbFile << "end reg;" << endl << endl;

tbFile << "architecture reg of reg is" << endl;
tbFile << "  signal temp : coded_ham_" << dataBits << "bit;" << endl;
tbFile << "begin" << endl;
tbFile << "   process(clock) " << endl;
tbFile << "   begin " << endl;
tbFile << "      if (clock'event and clock='1') then " << endl;
tbFile << "         temp <= (datain & hamming_encoder_" << dataBits << "bit(datain));" << endl;
tbFile << "      end if; " << endl;
tbFile << "   end process;" << endl;
   
tbFile << "   dataout <= hamming_decoder_" << dataBits << "bit(temp);" << endl;
tbFile << "end reg;" << endl << endl;

tbFile << "--================================================================--" << endl;
tbFile << "-- TB HAMMING  --" << endl;
tbFile << "--================================================================--" << endl;
tbFile << "library ieee,modelsim_lib;" << endl;
tbFile << "use ieee.std_logic_1164.all;" << endl;
tbFile << "use ieee.std_logic_arith.all;" << endl;
tbFile << "use work.hamm_package_" << dataBits << "bit.all;" << endl;
tbFile << "use modelsim_lib.util.all;" << endl << endl;

tbFile << "entity tb_hamming is" << endl;
tbFile << "end tb_hamming;" << endl << endl;

tbFile << "architecture tb_hamming of tb_hamming is" << endl;
tbFile << "  signal datain         : data_ham_" << dataBits << "bit;" << endl;
tbFile << "  signal dataout        : data_ham_" << dataBits << "bit;" << endl;
tbFile << "  signal clock          : std_logic := '0';" << endl;
tbFile << "begin" << endl << endl;

tbFile << "  clock <= not clock after 10 ns;" << endl << endl;
  
tbFile << "  faulty_reg: entity work.reg " << endl;
tbFile << "  port map(" << endl;
tbFile << "    clock => clock," << endl;
tbFile << "    datain => datain," << endl;
tbFile << "    dataout => dataout" << endl;
tbFile << "  );" << endl << endl;

tbFile << "  -- generate the input patterns" << endl;
tbFile << "  datain <= (others => '0');" << endl << endl;

tbFile << "  -- insert a single faults in the register" << endl;
tbFile << "  process" << endl;
tbFile << "  begin" << endl;
tbFile << "      wait for 100 ns;" << endl;
tbFile << "      for i in 0 to coded_ham_" << dataBits << "bit'high loop" << endl;
tbFile << "         signal_force(\"/tb_hamming/faulty_reg/temp(\" & integer'image(i) & \")\",\"1\", open, freeze);" << endl;
tbFile << "         wait for 10 ns;" << endl;
tbFile << "         signal_release(\"/tb_hamming/faulty_reg/temp(\" & integer'image(i) & \")\");" << endl;
tbFile << "         wait for 50 ns;" << endl;
tbFile << "      end loop;" << endl;
tbFile << "      report \"End of Simulation!\" severity failure;" << endl;
tbFile << "      wait;" << endl;
tbFile << "  end process;" << endl << endl;

tbFile << "  -- evaluate the output" << endl;
tbFile << "  process" << endl;
tbFile << "  begin" << endl;
tbFile << "    wait for 100 ns;" << endl;
tbFile << "    wait until clock'event and clock='0';" << endl;
tbFile << "    while true loop" << endl;
tbFile << "      if (datain /= dataout) then" << endl;
tbFile << "        report \"Error: output does not match!\"" << endl;
tbFile << "        severity note;" << endl;
tbFile << "      end if;" << endl;
tbFile << "      wait for 1 ns;" << endl;
tbFile << "    end loop;" << endl;
tbFile << "  end process;" << endl << endl;

tbFile << "end tb_hamming;" << endl;
return tbFile.str();

}

//---------------------------------------------------------------------------
// generate the Encoder
void HammingSec::GenerateEnc(void)
{
  int ParityVect[1000],x,last;

    // initialze parity vector
    ParityVect[0]=0;
    ParityVect[1]=1;
    ParityVect[2]=3;
    for(x=3, last=4;x<=(dataBits+parityBits);x++){
        last=ReturnIndex(last);
        ParityVect[x]=last-1;
    }

    // insert data lines
    for(int x=0;x<=(dataBits+parityBits);x++)
        fprintf(fp,"\tcoded(%d)\t:=\tdata_parity_in(%d);\n",ParityVect[x],x);
}
//---------------------------------------------------------------------------
// generate the hamming parity generator
void HammingSec::GenerateGen(void)
{
    int  offset,y,index,a;
    string aux;

    for (int x=0;x<=parityBits;x++)
    {
        offset=0;
        fprintf(fp,"\n\tparity(%d)\t:=\t",x);
        a=1;
        for(y=3;y<=dataBits+parityBits+1;y++){
          // if is not 4 or 8 or 16 or 32 ...
          if( ! PotOf2(y)){
            // if 2**(x-1) bit of y is setted then ...
            if (y & (int)pow((double)2,(double)(x))){
              fprintf(fp,"data_in(%d) ",offset);
              fprintf(fp,"XOR ");
              // insert a new line to avoid long lines
              if (((a % 5)==0)  && (a!=0)){
                fprintf(fp,"\n\t\t\t\t\t");
              }
              a++;
            }
            offset++;
          }
        }
        index=0;
        // ovewrite the last XOR
        if (((a-1) % 5)==0)
           index=-12;
        else index=-5;
        fseek(fp,index,SEEK_CUR);
        // put semicolon
        fprintf(fp,";");
    }
    fprintf(fp,"\n");
}
//---------------------------------------------------------------------------
// generate the corrector
void HammingSec::GenerateCorrector(void)
{   int ParityVect[1000],vetPotOf2[1000];
    int x,last;

    ParityVect[0]=0;
    ParityVect[1]=1;
    ParityVect[2]=3;
    // find the parity bits (potOf2(x)-1)
    for(x=3, last=4;x<=(dataBits+parityBits);x++)
    {   last=ReturnIndex(last);
        ParityVect[x]=last-1;
    }
    // get all non power of 2 bits
    for(x=3,last=0;x<=(dataBits+parityBits+1);x++)
    {   if(!PotOf2(x)){
          vetPotOf2[last]=x;
          last++;
        }
    }

    fprintf(fp,
    "\n\t-- syndorme generation\n"
    "\tsyn := parity XOR parity_in;\n");

    // generate CASE
    fprintf(fp,"\tCASE syn IS\n",parityBits);
    for (int i=0;i<dataBits;i++){
      fprintf(fp,"\t\tWHEN \"%s\" => mask := (%d => '1',others => '0');\n",
        toBit(vetPotOf2[i],parityBits+1).c_str(),
        vetPotOf2[i]-1);
    }
    fprintf(fp,
      "\t\tWHEN OTHERS =>  mask := (others => '0');\n"
      "\tEND CASE;\n\n");

    fprintf(fp,
    "\tcoded := coded XOR mask;\n\n"
    );

    // generate the decoder
    for(int x=0;x<dataBits;x++)
        fprintf(fp,"\tdecoded(%d)\t:=\tcoded(%d);\n", x,ParityVect[x+parityBits+1]);

}






//---------------------------------------------------------------------------
//  AUXILIAR FUNCTIONS
//---------------------------------------------------------------------------
//  return true if the value is 2 or 4 or 8 or 16 ....
bool HammingSec::PotOf2(int value)
{
  bool status  = false;
  int k = 1;

  while (pow((double)2,(double)k) < value)
        k ++;

    if (pow((double)2,(double)k) == value)
        status = true;
    else
      status = false;

  return status;
}
//---------------------------------------------------------------------------
//  used to fill a vector like this :0 1 2 4 8 16 3 5 6 7 9 10 12 13 14 15 17
//  the parity bits appear first in order. after the data bits appear in order
//  used in encoder and decoder functions
int HammingSec::GetParityBits(int databits)
{   int p=1;
    while (pow((double)2,(double)p)< (p+databits+1))
    { p++; }
    return p;
}
//---------------------------------------------------------------------------
int HammingSec::ReturnIndex(int last)
{   int aux=last+1;
    if(!PotOf2(last))
    {
        while(PotOf2(aux)&& (aux<=(dataBits+parityBits)))  aux++;
    }
    else
    {
        while(!PotOf2(aux)&& (aux<=(dataBits+parityBits)))  aux++;
        if (aux>(dataBits+parityBits))
            aux=3;
    }
    return aux;
}

string HammingSec::toBit(int number,int width){
  char *hexCStr;
  string hexStr;
  hexCStr = new char[width+1];

  // convert dec to HEX
  sprintf(hexCStr,"%X",number);
  hexStr=hexCStr;

  // convert HEX to bin
    string buffer,digit;
    char aux[200];
    strcpy(aux,hexStr.c_str());
    for(unsigned j=0;j<hexStr.length();j++){
  if (aux[j]=='0'){ digit = "0000";
  }else if (aux[j]=='1'){ digit = "0001";
  }else if (aux[j]=='2'){ digit = "0010";
  }else if (aux[j]=='3'){ digit = "0011";
  }else if (aux[j]=='4'){ digit = "0100";
  }else if (aux[j]=='5'){ digit = "0101";
  }else if (aux[j]=='6'){ digit = "0110";
  }else if (aux[j]=='7'){ digit = "0111";
  }else if (aux[j]=='8'){ digit = "1000";
  }else if (aux[j]=='9'){ digit = "1001";
  }else if (aux[j]=='A'){ digit = "1010";
  }else if (aux[j]=='B'){ digit = "1011";
  }else if (aux[j]=='C'){ digit = "1100";
  }else if (aux[j]=='D'){ digit = "1101";
  }else if (aux[j]=='E'){ digit = "1110";
  }else if (aux[j]=='F'){ digit = "1111";
  }
  buffer+=digit;
    }
    unsigned x = buffer.length();
    if (buffer.length()>width)
  buffer.erase(0,x-width);
    else if (buffer.length()<width){
  for(unsigned i=0;i<width-x;i++)
      buffer.insert(buffer.begin(),'0');
    }

  delete hexCStr;
  return buffer;
}
