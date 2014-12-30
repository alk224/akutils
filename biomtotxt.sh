#!/bin/bash

# check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
		echo "
		Usage:
		biomtotxt.sh InputBiomTable

		This script takes an OTU table produced in QIIME (biom format) and returns
		the same table in tab-delimited format (.txt).  It assumes you are using
		the version of biom found in a typical QIIME install on a Linux system.
		It will	retain the metadata field \"taxonomy\".
		"
		exit 0
	fi 

# if more or less than one arguments supplied, display usage 

	if [  "$#" -ne 1 ] ;
	then 
		echo "
		Usage:
		biomtotxt.sh InputBiomTable.biom
		"
		exit 1
	fi 

#Check if supplied input has .biom extension before proceeding

	if [[ "$1" != *.biom ]]; then
		echo "
		Input file must have .biom extension.  Are you sure you are using a valid
		biom table from QIIME?
		"
		exit 1
	fi
## Extract OTU table basename for naming txt file output

	biombase=`basename "$1" | cut -d. -f1`
	biomextension="${1##*.}"
	biomname="${1%.*}"
	biomdir=$(dirname $1)

#Check if txt format table already exists with the same input name

	if [[ -f "$biomname.txt" ]]; then
		echo "
		A file exists with your input name and .txt extension.  Aborting
		conversion.  Delete the conflicting .txt file or change the name
		of your input file to proceed with biom to txt conversion.
		"
		exit 1
	fi

#Biom convert command

	`biom convert -i $1 -o $biomdir/$biombase.txt --header-key taxonomy -b`
	echo "
	Succussfully converted $biombase.$biomextension to $biombase.biom
	"

