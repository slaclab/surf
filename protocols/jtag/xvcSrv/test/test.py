#!/usr/bin/python3

import re
import io
import sys
import os
import array
import getopt
from socket import *;

def query():
  with socket(AF_INET,SOCK_STREAM) as sd:
    sd.connect(("localhost",2542))
    sd.send(bytearray('getinfo:','ascii'))
    return sd.recv(1000)


def ser(a, wrds, byts):
  for w in wrds:
    if byts > 4:
      n = 4
    else:
      n = byts
    for i in range(0,n):
      a.append( w % 256 )
      w = int(w / 256)
    byts = byts - 4

def mkvecs(f):
  patt = re.compile('^(r[[]4]:=)(.*)$',re.MULTILINE)
  with io.open(f,'r') as fd:
    fnd  = patt.findall( fd.read(1000) )
    bits = (int(fnd[0][1],16) % 0x100000) + 1;
    byts = int((bits + 7)/8)
    wrds = [ int(x[1],16) for x in fnd[1:] ]
    vec  = bytearray()
    ser(vec, [bits], 4)
    ser(vec, wrds[0::2], byts)
    ser(vec, wrds[1::2], byts)
    return vec

def sendfil(f):
  vecs = mkvecs(f)
  with socket(AF_INET,SOCK_STREAM) as sd:
    sd.connect(("localhost",2542))
    sd.send(bytearray('shift:','ascii'))
    sd.send(vecs)
    return sd.recv(1000)

def playfile(f):
  with socket(AF_INET,SOCK_STREAM) as sd:
    with io.open(f,'r') as rd:
      sd.connect(("localhost",2542))
      lenbits = re.compile("(^LENBITS:[ ]*)([0-9]+)[ ]*$")
      tdi     = re.compile("(^TDI[ ]*[:][ ]*)([^ ]+)[ ]*$")
      tms     = re.compile("(^TMS[ ]*[:][ ]*)([^ ]+)[ ]*$")
      tdo     = re.compile("(^TDO[ ]*[:][ ]*)([^ ]+)[ ]*$")
      m       = None
      while True:
        while None == m:
          l = rd.readline()
          if l == None or len(l) == 0:
             print("EOF -- Test PASSED")
             return;
          print("checking: ", l)
          m = lenbits.match(l)
        print("Got {} bits".format( m.group(2) ))
        bits = int(m.group(2))
        byts = int((bits + 7)/8)
        wrds = int((byts + 3)/4)
        arri = list()
        for i in range(0,wrds):
          l = rd.readline()
          if None == l:
             raise RuntimeError("Premature EOF")
          m = tms.match(l)
          if None == m:
             print(l)
             raise RuntimeError("EXPECTED TMS")
          arri.append( int( m.group(2), 16 ) )
          l = rd.readline()
          if None == l:
             raise RuntimeError("Premature EOF")
          m = tdi.match(l)
          if None == m:
             raise RuntimeError("EXPECTED TDI")
          arri.append( int( m.group(2), 16 ) )
        arro = list()
        for i in range(0,wrds):
          l = rd.readline()
          if None == l:
             raise RuntimeError("Premature EOF")
          m = tdo.match(l)
          if None == m:
             print(l)
             raise RuntimeError("EXPECTED TMS")
          arro.append( int( m.group(2), 16 ) )
        vec=bytearray()
        ser(vec, [bits], 4)
        ser(vec, arri[0::2], byts)
        ser(vec, arri[1::2], byts)
        sd.send(bytearray('shift:','ascii'))
        sd.send(vec)
        tmp=bytearray()
        ser(tmp, arro, byts)
        got=sd.recv(2000)
        if ( got != tmp ):
           if (len(got) != len(tmp)):
             print("Length mismatch: got {} exp {}".format(len(got), len(tmp)))
           raise RuntimeError("TDO MISMATCH")
        m = None


if __name__ == "__main__":
  (opts, args) = getopt.getopt(sys.argv[1:], "k")
  dokill = False
  for (o, a) in opts: 
    if o == '-k':
      dokill = True; 
  try:
    playfile('testData.txt')
  except:
    if dokill:
      os.kill( os.getpgid(0), 15 )
    raise
