#!/bin/bash
#echo "Version 5OCT2015, CS, LM"
# SetVoxelSpacing [options] input.nii
# Options:
#    -m #  manually set the spacing to be #

if [ -z ${ANTSPATH+x} ]; 
then 
  echo "Guessing an ANTSPATH of /usr/local/ants"
  ANTSPATH = /usr/local/ants/ 
fi

if [ ! -s ${ANTSPATH}/ANTS ];
then
  echo "Cannot find ANTS in $ANTSPATH"
  exit
fi

SPACING=0
USEAFNI=0

while getopts "am:" OPT
  do
  case $OPT in
      h) #help
        echo "SetVoxelSpacing [-a] input.nii"
        echo " Options:"
        echo "    -a    use AFNI rather than ANTS to change spacing"
        echo "    -m #  manually set the spacing to be # rather than automatic"
        exit 0
        ;;
      m) #manual spacing
        SPACING=$OPTARG
		echo "Manual spacing: $SPACING"
        ;;
      a) # Use afni
        USEAFNI=1
   esac
done

# Shift so the $1 and such will be correct given any getopts
shift $((OPTIND-1))

if [ $# -lt 1  ];
then
  echo "Not enough parameters -- call with -h for help"
  exit
fi

FNAME=$1
echo $FNAME

if [ $SPACING == 0 ];
then
  case "$FNAME" in
    *bf*)
      SPACING=0.015 #0.0144 #0.016
      ;;
    *625*)
      SPACING=0.0144 #0.016
      ;;
    *x2.5*)
      SPACING=0.0036 #0.004
      ;;
    *x10*)
      SPACING=0.0009 #0.001
      ;;
    *x40*)
      SPACING=0.000226 #0.00025
      ;;
    *) # getopts issues an error message
      echo "cannot guess spacing from filename"
      exit 1
      ;;
  esac
fi

if [ $USEAFNI == 1 ];
then
  3drefit -xdel $SPACING -ydel $SPACING $FNAME
else
  $ANTSPATH/SetSpacing 3 $FNAME $FNAME $SPACING $SPACING 1
fi
