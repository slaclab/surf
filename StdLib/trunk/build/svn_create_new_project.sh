#!/bin/sh

if [ $# -ne 1 ]
then
   echo ""
   echo "Usage: svn_create_new_project.sh NewProjectName"
   echo ""
   exit;
fi

echo ""
echo "---------------------------------------"
echo "Creating new project: $1"
echo "---------------------------------------"
echo ""

## SVN Path Variables
BASE="file:///afs/slac/g/reseng/svn/repos/"
PROJ="$BASE/$1"
TRUNK="$PROJ/trunk"
TAGS="$PROJ/tags"
BRANCHES="$PROJ/branches"
SOFTWARE="$TRUNK/software"
FIRMWARE="$TRUNK/firmware"
MODULES="$FIRMWARE/modules"
TARGETS="$FIRMWARE/targets"

svn mkdir -m "Creating new project: $1" $PROJ $TRUNK $TAGS $BRANCHES $SOFTWARE $FIRMWARE $MODULES $TARGETS
echo "---------------------------------------"
echo "Added the following the SVN repository:"
echo "   $PROJ"
echo "   $TRUNK"
echo "   $TAGS"
echo "   $BRANCHES"
echo "   $SOFTWARE"
echo "   $FIRMWARE"
echo "   $MODULES"
echo "   $TARGETS"
echo "---------------------------------------"


echo "---------------------------------------"
echo "Checking out the new SVN project:"
svn checkout $TRUNK $1
echo "---------------------------------------"

## Local Variables
PROJ="$PWD/$1"
FIRMWARE="$PROJ/firmware"
MODULES="$FIRMWARE/modules"

echo "---------------------------------------"
echo "Adding common firmware externals to project directory:"
STDLIB="^/StdLib/trunk StdLib"
MGTLIB="^/MgtLib/trunk MgtLib"
PGP2BLIB="^/pgp2b_core/trunk pgp2b"
ETHLIB="^/FirmwareCoreLibrary/trunk/EthernetLib EthernetLib"

echo $STDLIB   >  temp.txt
echo $MGTLIB   >> temp.txt
echo $PGP2BLIB >> temp.txt
echo $ETHLIB   >> temp.txt

svn propset svn:externals -F temp.txt $MODULES 
svn copy $BASE/ExampleProject/trunk/firmware/setup_env.csh $FIRMWARE/setup_env.csh 

rm -f temp.txt

svn update $PROJ
svn commit $PROJ -m "Adding common external to new project: $1"
echo "---------------------------------------"
