#!/bin/bash
set -e

#script to run ITSx in a timely fashion through true parallelization.  The ITSx script as avialable from the UNITE group website doesn't put each search in parallel, so if using primers specific to some taxonomic group, it can still take a very long time to run.

## check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
		echo "
		This script takes an input fasta file and processes it using
		the most excellent ITSx utility in parallel.  Command will 
		not execute if output directory already exists.		

		Output will be the name of the sequence file minus the fasta
		extension plus _ITSx_output (e.g. seqs_ITSx_output for the
		above usage example).

		Usage (order is important!!):
		ITSx_parallel.sh <InputFasta> <ThreadsToUse> <ITSx options>

		Example:
		ITSx_parallel.sh seqs.fna 20 -t F --complement F --preserve T

		ITSx options should be entered just as described in the ITSx
		manual.  The example here limits the search to fungal HMMer
		profiles, searches the sequences in a single direction only
		(saves time if your sequences are properly oriented), and
		preserves the fasta headers.

		Requires the following dependencies to run:
		1) QIIME 1.8.0 or later (qiime.org)
		2) HMMer v3+ (http://hmmer.janelia.org/)
		3) ITSx (http://microbiology.se/software/itsx/)
		4) Fasta-splitter.pl (http://kirill-kryukov.com/study/tools/fasta-splitter/)
		
		Citing ITSx: http://microbiology.se/software/itsx/
		"
		exit 0
	fi 

## if less than three arguments supplied, display usage 

	if [  "$#" -le 2 ] ;
	then 
		echo "
		Usage (order is important!!):
		ITSx_parallel.sh <InputFasta> <ThreadsToUse> <ITSx options>
		"
		exit 1
	fi

##Extract input name and extension to variables

	seqfile=$(basename "$1")
	seqextension="${1##*.}"
	seqname="${1%.*}"
	seqbase=$(basename $seqfile .fna)

## Define directories and move into working directory

	home=$(pwd)
	infile=$(readlink -f $1)
	workdir=$(dirname $infile)

	cd $workdir

## Check to see if requested output directory exists

	if [[ -d ${seqfile}\_ITSx_output ]]; then
		echo "
		Output directory already exists.
		(${seqfile}_ITSx_output).  
		Choose a different output name and try again.

		Exiting
		"
		exit 1
	fi

		echo "
		Beginning parallel ITSx processing.  This can take a while...
		"

## Make output subdirectories and extract input name and extension to variables

	mkdir $seqfile\_ITSx_output
	outdir=$seqfile\_ITSx_output

## Log search start

	echo "
---

Parallel ITSx script starting..." >> $outdir/ITSx_parallel_log.txt
	date >> $outdir/ITSx_parallel_log.txt
	echo "
---
	" >> $outdir/ITSx_parallel_log.txt

## Split input using fasta-splitter command

	fasta-splitter.pl --n-parts $2 $infile
	wait

## Move split input to output directory and construct subdirectory structure for separate processing

	for splitseq in $seqbase.part-* ; do
		( mv $splitseq $outdir ) &
	wait
	done

	for fasta in $outdir/$seqbase.part-*.$seqextension ; do
    		base=$(basename $fasta .$seqextension)
    		mkdir $outdir/$base\_ITSx_tmp
    		mv $fasta $outdir/$base\_ITSx_tmp/
	wait
	done


## Log that files have been split and moved as needed
	echo "
file splitting achieved" >> $outdir/ITSx_parallel_log.txt
	date >> $outdir/ITSx_parallel_log.txt
	echo "
---
	" >> $outdir/ITSx_parallel_log.txt

## parallel ITSx command

	for dir in $outdir/*\_ITSx_tmp; do
		dirbase=$(basename $dir \_ITSx_tmp)
		( cd $dir/ && sleep 1 && `ITSx -i $dirbase.$seqextension -o $dirbase\_$2 ${@:3}` && sleep 1 && cd .. ) &
	done
	wait

## compile results

	for dir1 in $outdir/*\_ITSx_tmp; do
		dirbase1=$(basename $dir1 \_ITSx_tmp)
		( cat $dir1/$dirbase1\_$2_no_detections.txt >> $outdir/$seqbase\_no_detections.txt ) &
		( cat $dir1/$dirbase1\_$2.ITS1.fasta >> $outdir/$seqbase\_ITS1only.fasta ) &
		( cat $dir1/$dirbase1\_$2.ITS2.fasta >> $outdir/$seqbase\_ITS2only.fasta ) &
	done
	wait

## Remove temporary files (split input and separate ITSx searches)

	rm -r $outdir/$seqbase.part-*

## Filter input sequences with no_detections file

	`filter_fasta.py -f $infile -o ./$seqbase\_ITSx_filtered.$seqextension -s $outdir/$seqbase\_no_detections.txt -n`
	wait

## Log that ITSx searches have completed

	echo "
parallel ITSx processing completed" >> $outdir/ITSx_parallel_log.txt
	date >> $outdir/ITSx_parallel_log.txt
	echo "
---" >> $outdir/ITSx_parallel_log.txt


	echo "
******************************************
ITSx steps finished
"

## Make detections files for full, ITS1, and ITS2 trimmed sequences
## Full detections:

	countfull=`head ./$seqbase\_ITSx_filtered.$seqextension | grep ">.*" | wc -l`
	if [[ $countfull != 0 ]]; then
		grep ">.*" ./$seqbase\_ITSx_filtered.$seqextension > $outdir/full.seqids1.txt
		sed "s/>//" < $outdir/full.seqids1.txt > $outdir/$seqbase\_full_ITSx_filtered.seqids.txt
		rm $outdir/full.seqids1.txt

## ITS1 detections:
		countITS1=`head $outdir/$seqbase\_ITS1only.fasta | grep ">.*" | wc -l`
		if [[ $countITS1 == 0 ]]; then
		echo "
		No ITS1 detections made...
		"
		echo "
No ITS1 detections made
" >> $outdir/ITSx_parallel_log.txt
		else
			grep ">.*" $outdir/$seqbase\_ITS1only.fasta > $outdir/ITS1.seqids1.txt
			sed "s/>//" < $outdir/ITS1.seqids1.txt > $outdir/ITS1.seqids.txt
			rm $outdir/ITS1.seqids1.txt
		fi

## ITS2 detections:
		countITS2=`head $outdir/$seqbase\_ITS2only.fasta | grep ">.*" | wc -l`
		if [[ $countITS2 == 0 ]]; then
		echo "
		No ITS2 detections made...
		"
		echo "
No ITS2 detections made
" >> $outdir/ITSx_parallel_log.txt
		else
			grep ">.*" $outdir/$seqbase\_ITS2only.fasta > $outdir/ITS2.seqids1.txt
			sed "s/>//" < $outdir/ITS2.seqids1.txt > $outdir/ITS2.seqids.txt
			rm $outdir/ITS2.seqids1.txt
		fi
		
	else
		echo "
		No ITS profiles matched in full sequences.  No detections attempted for ITS1 and ITS2.
"
echo "
No ITS profiles matched in full sequences.  No detections attempted for ITS1 and ITS2.
"  >> $outdir/ITSx_parallel_log.txt
	fi

## Describe outputs in log file:
echo "
---

List of output files 
(in this output directory $outdir)

 1. ${seqbase}_ITSx_filtered.fna: original fasta file, filtered according to sequence ids within the no_detections file (located in same directory as input file).
 2. ${seqbase}_ITSx_filtered.seqids.txt: list of sequence identifiers found within the filtered fasta with complete sequences.
 3. ${seqbase}_ITS1only.fasta: fasta file containing only ITS1 sequences from input file.
 4. ${seqbase}_ITS1.seqids.txt: list of sequence identifiers found within the ITS1 fasta file.
 5. ${seqbase}_ITS2only.fasta: fasta file containing only ITS2 sequences from input file.
 6. ${seqbase}_ITS2.seqids.txt: list of sequence identifiers found within the ITS2 fasta file.
 7. ${seqbase}_no_detections.txt: List of sequence identifiers that failed to match ITS HMMer profiles.
" >> $outdir/ITSx_parallel_log.txt

echo "
******************************************
*** Parallel ITSx processing completed ***
******************************************

"

