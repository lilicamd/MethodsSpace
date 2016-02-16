#!/bin/bash
echo "Version 15DEC2015, LM"

t1=$(date +"%s")

if [ $1 -lt 1 ]
then
	echo 'Var $1 is blank, return.'
	exit 1
fi
	
clear
echo "==== Run all registration steps on section $1 :"

# Input files and description:
COLOR="Blue"
COLOR_SHORT="B"
FIXED="$1bf_p_n.nii" #blockface
FIXED_PTS="./In/$1bf_pts.nii" #landmarks in blockface space
FIXED_MASK="$1bf_p_nMask.nii" #mask in blockface space
MOVING="$1_x2.5${COLOR_SHORT}_n.nii" #cell-stain image, blue channel
MOVING_PTS="./In/$1_x2.5_pts.nii" #landmarks in cell-stain space
MOVING_MASK="$1_x2.5_z0bMask.nii" #mask in cell-stain space
REFSPACE=$FIXED #output reference space
#REFSPACE="./$1bf_p_n_2x5.nii" #output reference space

read -p "== BlockFaceImage Default Spacing: " -e -i "0.016" SP_BFI
#SP_BFI=0.0135 
echo $SP_BFI
echo $SP_BFI >> ./In/$1spacingParaBFI.txt

#read -p "== Run Step0, -preregistration- (y/n/q)?" choice
choice="y"
case "$choice" in 
  y|Y ) 
		echo "yes, create 5 new files"
		gzip -d -f ./In/$1*_pts.nii.gz
		# Convert Tiff files to Nifti
		if [ -e ./In/$1_x2.5${COLOR_SHORT}.tif ]; then
			$ANTSPATH/ImageMath 2 $MOVING + ./In/$1_x2.5${COLOR_SHORT}.tif 0
		else
			echo "WARNING - Missing MOVING ./In/$1_x2.5${COLOR_SHORT}.tif\n"
		fi
		if [ -e ./In/$1_x2.5_z0bMask.tif ]; then	
			$ANTSPATH/ImageMath 2 $MOVING_MASK + ./In/$1_x2.5_z0bMask.tif 0
		else
			echo "WARNING - Missing MOVING_MASK ./In/$1_x2.5_z0bMask.tif\n"
		fi
		if [ -e ./In/$1bf_p.tif ]; then
			$ANTSPATH/ImageMath 2 $FIXED + ./In/$1bf_p.tif 0
		else
			echo "WARNING - Missing FIXED ./In/$1bf_p.tif\n"
		fi
		if [ -e ./In/$1bf_pMask.tif ]; then
			$ANTSPATH/ImageMath 2 $FIXED_MASK + ./In/$1bf_pMask.tif 0
		else
			echo "WARNING - Missing FIXED_MASK ./In/$1bf_pMask.tif\n"
		fi
		# Fix the voxel spacing #$SH_PO/SetVoxelSpacing.sh ./$1_x2.5B_n.nii	use AFNI not ANTs
		if [ -e $MOVING ]; then
			$SH_PO/SetVoxelSpacing.sh -a $MOVING
		else
			echo "WARNING - Missing MOVING file $MOVING\n"
		fi
		if [ -e $MOVING_MASK ]; then
			$SH_PO/SetVoxelSpacing.sh -a $MOVING_MASK
		else
			echo "WARNING - Missing MOVING_MASK file $MOVING_MASK\n"
		fi
		if [ -e $MOVING_PTS ]; then
			$SH_PO/SetVoxelSpacing.sh -a $MOVING_PTS
		else
			echo "WARNING - Missing MOVING_PTS file $MOVING_PTS\n"
		fi
		if [ -e $FIXED ]; then
			$SH_PO/SetVoxelSpacing.sh -a -m $SP_BFI $FIXED
		else
			echo "WARNING - Missing FIXED file $FIXED\n"
		fi
		if [ -e $FIXED_MASK ]; then
			$SH_PO/SetVoxelSpacing.sh -a -m $SP_BFI $FIXED_MASK
		else
			echo "WARNING - Missing FIXED_MASK file $FIXED_MASK\n"
		fi
		if [ -e $FIXED_PTS ]; then
			$SH_PO/SetVoxelSpacing.sh -a -m $SP_BFI $FIXED_PTS
		else
			echo "WARNING - Missing FIXED_PTS file $FIXED_PTS\n"
		fi
#		if [ -e $FIXED ]; then
#			$ANTSPATH/ResampleImageBySpacing 2 $FIXED $REFSPACE 0.0036 0.0036 #0.004	 0.004
#		else
#			echo "WARNING - Can't make FIXED in REFSPACE as missing FIXED file $FIXED\n"
#		fi
		;;
  n|N ) 
		echo "no, skip Step0"
		;;
  q|Q ) 
		echo "quit"
		exit 1
		;;
  * ) echo "invalid";;
esac

#read -p "== Run Step1SyN, -registration with SyNQuick- (y/n/q)?" choice
choice="y"
case "$choice" in 
	y|Y ) 
		echo "yes, create 7 new files outSyN*"
		$ANTSPATH/antsRegistrationSyNQuick.sh -d 2 -f $FIXED -m $MOVING -o $1outSyN -n 6
		# get regisCheck image
		gzip -d -f $1outSyNWarped.nii.gz
		$ANTSPATH/ConvertToJpg $1outSyNWarped.nii $1outSyNWarped.nii.jpg
		$ANTSPATH/ImageMath 2 $1regisCheckSyN.nii - $FIXED $1outSyNWarped.nii
		$ANTSPATH/ConvertToJpg $1regisCheckSyN.nii $1regisCheckSyN.nii$SP_BFI.jpg
		;;
	n|N ) 
		echo "no, skip step1SyN"
		;;
	q|Q ) 
		echo "quit"
		exit 1
		;;
	* ) echo "invalid";;
esac

#read -p "== Run Step1A, -registration with landmarks- (y/n/q)?" choice
choice="y"
case "$choice" in 
  y|Y ) 
		echo "yes, create 7 new files $1out1NoMask"
		clear
		$SH_PO/JointRegistration.sh -i -o ./$1out -a -f $FIXED $FIXED_PTS $MOVING $MOVING_PTS $REFSPACE
		$ANTSPATH/WarpImageMultiTransform 2 $MOVING ./LandmarkAffineOnly.nii ./LandmarkAffine_auto.txt -R $REFSPACE
		# get regisCheck image
		gzip -d -f ./$1out*deformed.nii.gz
		find ./ -name '*out*deformed.nii' -exec sh -c '${ANTSPATH}/ConvertToJpg "$0" "$0".jpg' {} \;
		if [ -e ./$1out_deformed.nii ]; then
			$ANTSPATH/ImageMath 2 ./$1regisCheck$SP_BFI.nii - $REFSPACE ./$1out_deformed.nii
			$ANTSPATH/ConvertToJpg ./$1regisCheck$SP_BFI.nii ./$1regisCheck$SP_BFI.nii.jpg
		else
			echo "ERROR - Missing output file ./$1out_deformed.nii\n"
		fi
		;;
  n|N ) 
		echo "no, skip step 1A"
		;;
  q|Q ) 
		echo "quit"
		exit 1
		;;
  * ) echo "invalid";;
esac

#read -p "== Run Step1B, -registration with mask- (y/n/q)?" choice
choice="n"
case "$choice" in 
  y|Y ) 
		echo "yes, create out2WithCSMask* files"
		$SH_PO/JointRegistration.sh -o ./$1out2 -a -f -m ./In/$1bf_p_CSMask.nii -i $FIXED $FIXED_PTS $MOVING $MOVING_PTS $REFSPACE # *out2WithCSMask_WithLMAffine
		mv LandmarkAffine_auto.txt ./$1
		$ANTSPATH/WarpImageMultiTransform 2 $MOVING ./LandmarkAffineOnly.nii ./LandmarkAffine_auto.txt -R $REFSPACE
		# get regisCheck image
		gzip -d -f ./$1out*deformed.nii.gz
		find ./$1 -name '*out2*deformed.nii' -exec sh -c '${ANTSPATH}/ConvertToJpg "$0" "$0".jpg' {} \;
		$SH_PO/JointRegistration.sh -o ./$1out1 -a -f -i -m ./In/$1bf_p_CSMask.nii $FIXED $FIXED_PTS $MOVING $MOVING_PTS $REFSPACE # *out3WithCSMask_WithAutoAffine
		gzip -d -f ./$1out3*deformed.nii.gz
		find ./$1 -name '*out3*deformed.nii' -exec sh -c '${ANTSPATH}/ConvertToJpg "$0" "$0".jpg' {} \;
		;;
  n|N ) 
		echo "no, skip step 1B"
		;;
  q|Q ) 
		echo "quit"
		exit 1
		;;
  * ) echo "invalid";;
esac

#read -p "== Run Step2, -postregistration, apply transforms to cell points- (y/n/q)?" choice
choice="y"
case "$choice" in 
  y|Y ) 
		echo "yes, apply registration to tracer positive cells"
		# apply S1 transforms
		$ANTSPATH/antsApplyTransformsToPoints -d 2 -i ./In/$1_xy2p5xRed_mmIn.csv -t "[./$1outSyN0GenericAffine.mat,1]" -t ./$1outSyN1InverseWarp.nii.gz -o ./In/$1_xySyN_Red_mmOutS1.csv
		# apply S2 transforms
		$ANTSPATH/antsApplyTransformsToPoints -d 2 -i ./In/$1_xy2p5xRed_mmIn.csv -t "[./$1outAffine.txt,1]" -t ./$1outInverseWarp.nii.gz -o ./In/$1_xyBFI_Red_mmOutS2.csv
		#apply transforms to RGB
		$ANTSPATH/ImageMath 2 ./$1_x2.5_z0b.nii + ./In/$1_x2.5_z0b.tif 0
		$SH_PO/SetVoxelSpacing.sh -a ./$1_x2.5_z0b.nii
		$ANTSPATH/WarpImageMultiTransform 2 ./$1_x2.5_z0b.nii ./$1regisS1.nii ./$1outSyN1Warp.nii.gz ./$1outSyN0GenericAffine.mat -R $REFSPACE
		$ANTSPATH/WarpImageMultiTransform 2 ./$1_x2.5_z0b.nii ./$1regisS2.nii ./$1outWarp.nii.gz ./$1outAffine.txt -R $REFSPACE
		#$ANTSPATH/WarpImageMultiTransform 2 ./$1_x2.5_z0b.nii ./$1regisS2inverse.nii -i ./$1outAffine.txt ./$1outInverseWarp.nii.gz -R $REFSPACE
		$ANTSPATH/ConvertToJpg ./$1regisS1.nii ./$1_regisS1.nii.jpg
		$ANTSPATH/ConvertToJpg ./$1regisS2.nii ./$1_regisS2.nii.jpg
		#$ANTSPATH/ConvertToJpg ./$1regisS2inverse.nii ./$1_regisS2inverse.nii.jpg
		;;
  n|N ) 
		echo "no, skip Step2"
		;;
  q|Q ) 
		echo "quit"
		exit 1
		;;
  * ) echo "invalid";;
esac

# 4test
$ANTSPATH/PrintHeader $MOVING|grep Spacing
$ANTSPATH/PrintHeader $MOVING_PTS|grep Spacing
$ANTSPATH/PrintHeader $FIXED|grep Spacing
$ANTSPATH/PrintHeader $FIXED_PTS|grep Spacing
$ANTSPATH/PrintHeader $REFSPACE|grep Spacing


echo "==== Done all steps."

t2=$(date +"%s")
t3=$(($t2-$t1))
echo "Runtime: $((t3 / 60)) m and $((t3 % 60)) s."
date


