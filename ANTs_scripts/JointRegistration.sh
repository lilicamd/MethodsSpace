#!/bin/bash
echo "v Oct5/2015 CS, add regis with mask, add -i -I option"
# JointRegistration [options] BlockFace.nii BlockFaceSeg.nii Histology.nii HistologySeg.nii OutputReference.nii
#  Options:
#      -f	      Extra fine tuning stages for Syn
#      -F steps   Manually specify the fine-tuning steps for Syn - 30x90x20 was default
#      -a         Extra steps for the affine
#      -w #	      Weighting of labels (0-1.0) 
#      -o prefix  Output prefix
#      -m fname   Name of mask file in atlas (block-face) space
#      -i         Pre-calculate an initial affine using the landmark / segmentations"
#      -I         Use a specified initial affine"


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


# Set our defaults
ITRS="30x90x20"
AFF_ITRS=""
OUT="reg"
LABEL_WEIGHT=0.75  # Grayscale gets 1.0 -- how much do points?
LABEL_PCT=0.5  # How many of the labeled pixels get used?
MASK_OPT=""  # Optional mask file
PRECALC_AFFINE=0
INIT_AFFINE=""


# reading command line arguments
while getopts "hfF:iI:aw:o:m:" OPT
  do
  case $OPT in
      h) #help
   echo "JointRegistration [options] BlockFace.nii BlockFaceSeg.nii Histology.nii HistologySeg.nii OutputReference.nii"
   echo "  Options:"
   echo "    -f         Extra fine tuning stages for the Syn warps"
   echo "    -F steps   Manually specify the fine-tuning steps for Syn - 30x90x20 was default"
   echo "    -a         Extra fine tuning stages for the affine"
   echo "    -w #       Weighting of labels (0-1.0) "
   echo "    -m fname   Mask file (1=good) in block-face space "
   echo "    -i         Pre-calculate an initial affine using the landmark / segmentations"
   echo "    -I         Use a specified initial affine"
   echo "    -o prefix  Output prefix"

   exit 0
   ;;
      f)  # syn tuning steps
   ITRS="10x50x100x20"
   ;;
      F)  # syn tuning steps
   ITRS=$OPTARG
   ;;
      a)  # extra affine steps
   AFF_ITRS="--number-of-affine-iterations 10000x10000x10000x10000x10000 "
   ;;
      w)  # fixed image
   LABEL_WEIGHT=$OPTARG
   ;;
      o)  # moving image
   OUT=$OPTARG
   ;;
	  m)  # mask image
   MASK_OPT="-x $OPTARG"
   ;;
      i)  # syn tuning steps
   INIT_AFFINE="-a LandmarkAffine_auto.txt"
   PRECALC_AFFINE=1
   ;;
      I)  # syn tuning steps
   INIT_AFFINE="-a $OPTARG"
   ;;

     \?) # getopts issues an error message
   echo "Unknown option -- call with -h to see options"
   exit 1
   ;;
  esac
done

# Shift so the $1 and such will be correct given any getopts
shift $((OPTIND-1))

if [ $# -lt 5  ];
then
  echo "Not enough parameters -- call with -h for help"
  exit
fi

FIXED=$1
FIXED_LABELS=$2
MOVING=$3
MOVING_LABELS=$4
REFSPACE=$5

echo "BF=$FIXED  BF_seg=$FIXED_LABELS"
echo "Hist=$MOVING  Hist_seg=$MOVING_LABELS"
echo "Ref space=$REFSPACE"
echo "Output prefix=$OUT"
echo "Weighting of labels=$LABEL_WEIGHT  Sampling pct=$LABEL_PCT"
echo "Mask=$MASK_OPT"
if [ $PRECALC_AFFINE -eq 1 ]; then
echo Pre-calculating LandmarkAffine.txt
  $ANTSPATH/ANTSUseLandmarkImagesToGetAffineTransform ${FIXED_LABELS} ${MOVING_LABELS} affine LandmarkAffine_auto.txt
fi
echo "Initial Affine=$INIT_AFFINE"

# Calculate the alignment
CMD="${ANTSPATH}ANTS 2  -o ${OUT} $MASK_OPT $AFF_ITRS $INIT_AFFINE -i ${ITRS} -t SyN[0.25]  -r Gauss[3,0]   \
  -m PSE[${FIXED},${MOVING},${FIXED_LABELS},${MOVING_LABELS},${LABEL_WEIGHT},${LABEL_PCT},10,0,10] \
  -m MI[${FIXED},${MOVING},1,32]"
echo $CMD
$CMD


# Apply to the histology
 ${ANTSPATH}WarpImageMultiTransform 2 $MOVING ${OUT}_deformed.nii.gz  ${OUT}Warp.nii.gz ${OUT}Affine.txt  -R $REFSPACE

# Apply to the labels
 ${ANTSPATH}WarpImageMultiTransform 2 $MOVING_LABELS  ${OUT}Seg_deformed.nii.gz   ${OUT}Warp.nii.gz ${OUT}Affine.txt  -R $REFSPACE --use-NN

