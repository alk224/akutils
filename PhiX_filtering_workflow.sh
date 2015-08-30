#!/usr/bin/env bash
#
#  PhiX_filtering_workflow.sh - Remove PhiX contamination from MiSeq data
#
#  Version 1.1.0 (June 16, 2015)
#
#  Copyright (c) 2014-2015 Andrew Krohn
#
#  This software is provided 'as-is', without any express or implied
#  warranty. In no event will the authors be held liable for any damages
#  arising from the use of this software.
#
#  Permission is granted to anyone to use this software for any purpose,
#  including commercial applications, and to alter it and redistribute it
#  freely, subject to the following restrictions:
#
#  1. The origin of this software must not be misrepresented; you must not
#     claim that you wrote the original software. If you use this software
#     in a product, an acknowledgment in the product documentation would be
#     appreciated but is not required.
#  2. Altered source versions must be plainly marked as such, and must not be
#     misrepresented as being the original software.
#  3. This notice may not be removed or altered from any source distribution.
#

set -e

## Check whether user had supplied -h or --help. If yes display help 

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
	scriptdir="$( cd "$( dirname "$0" )" && pwd )"
	less $scriptdir/docs/PhiX_filtering_workflow.help
	exit 0
	fi 

## If config supplied, run config utility instead

	if [[ "$1" == "config" ]]; then
		akutils_config_utility.sh
		exit 0
	fi

## If different than 4 or 5 arguments supplied, display usage 

	if [[  "$#" -ne 4 ]] && [[  "$#" -ne 5 ]]; then 
		echo "
Usage (order is important):
PhiX_filtering_workflow.sh <output_directory> <mappingfile> <index> <read1> <read2>

	<read2> is optional
		"
		exit 1
	fi

## Define filter mode based on number of supplied inputs

	if [[  "$#" == 4 ]]; then
	mode=(single)
	elif [[  "$#" == 5 ]]; then
	mode=(paired)
	fi

## Define inputs and working directory
	workdir=$(pwd)
	outdir=($1)
	mapfile=($2)
	index=($3)
	read1=($4)
	read2=($5)

## Check to see if requested output directory exists

	if [[ -d $outdir ]]; then
		dirtest=$([ "$(ls -A $outdir)" ] && echo "Not Empty" || echo "Empty")
		echo "
Output directory already exists ($outdir).  Delete any contents prior to
beginning workflow or it will exit.
		"
		if [[ "$dirtest" == "Not Empty" ]]; then
		echo "
Output directory not empty.
Exiting.
		"
		exit 1
		fi
	else
		mkdir $outdir
	fi

## Define log file

	date0=`date +%Y%m%d_%I%M%p`
	log=($outdir/phix_filtering_workflow_$date0.log)

## Check for required dependencies:

scriptdir="$( cd "$( dirname "$0" )" && pwd )"

#echo "
#Checking for required dependencies...
#"

#for line in `cat $scriptdir/akutils_resources/phix_filtering_workflow.dependencies.list`; do
#	dependcount=`command -v $line 2>/dev/null | wc -w`
#	if [[ $dependcount == 0 ]]; then
#	echo "
#$line is not in your path.  Dependencies not satisfied.  Exiting.
#	"
#	exit 1
#	else
#	if [[ $dependcount -ge 1 ]]; then
#	echo "$line is in your path..."
#	fi
#	fi
#done
#echo "
#All dependencies satisfied.  Proceeding...
#"

##Read in variables from config file

	local_config_count=(`ls $workdir/akutils*.config 2>/dev/null | wc -w`)
	if [[ $local_config_count -ge 1 ]]; then

	config=`ls $workdir/akutils*.config`

	echo "Using local akutils config file:
$config"
	echo "
Referencing local akutils config file.
$config
	" >> $log
	else
		global_config_count=(`ls $scriptdir/akutils_resources/akutils*.config 2>/dev/null | wc -w`)
		if [[ $global_config_count -ge 1 ]]; then

		config=`ls $scriptdir/akutils_resources/akutils*.config`

		echo "Using global akutils config file.
$config"
		echo "
Referencing global akutils config file.
$config
		" >> $log
		fi
	fi

	refs=(`grep "Reference" $config | grep -v "#" | cut -f 2`)
	tax=(`grep "Taxonomy" $config | grep -v "#" | cut -f 2`)
	tree=(`grep "Tree" $config | grep -v "#" | cut -f 2`)
	chimera_refs=(`grep "Chimeras" $config | grep -v "#" | cut -f 2`)
	seqs=($outdir/split_libraries/seqs_chimera_filtered.fna)
	alignment_template=(`grep "Alignment_template" $config | grep -v "#" | cut -f 2`)
	alignment_lanemask=(`grep "Alignment_lanemask" $config | grep -v "#" | cut -f 2`)
	revcomp=(`grep "RC_seqs" $config | grep -v "#" | cut -f 2`)
	seqs=($outdir/split_libraries/seqs.fna)
	CPU_cores=(`grep "CPU_cores" $config | grep -v "#" | cut -f 2`)
	itsx_threads=($CPU_cores)
	itsx_options=(`grep "ITSx_options" $config | grep -v "#" | cut -f 2`)
	slqual=(`grep "Split_libraries_qvalue" $config | grep -v "#" | cut -f 2`)
	chimera_threads=($CPU_cores)
	otupicking_threads=($CPU_cores)
	taxassignment_threads=($CPU_cores)
	alignseqs_threads=($CPU_cores)
	min_overlap=(`grep "Min_overlap" $config | grep -v "#" | cut -f 2`)
	max_mismatch=(`grep "Max_mismatch" $config | grep -v "#" | cut -f 2`)
	mcf_threads=($CPU_cores)
	phix_index=($scriptdir/akutils_resources/PhiX/phix-k11-s1)
	smalt_threads=($CPU_cores)
	multx_errors=(`grep "Multx_errors" $config | grep -v "#" | cut -f 2`)
	rdp_confidence=(`grep "RDP_confidence" $config | grep -v "#" | cut -f 2`)
	rdp_max_memory=(`grep "RDP_max_memory" $config | grep -v "#" | cut -f 2`)

## Remove file extension if necessary from supplied smalt index for smalt command and get directory
	smaltbase=`basename "$phix_index" | cut -d. -f1`
	smaltdir=`dirname $phix_index`

## Log workflow start

	if [[ `echo $mode` == "single" ]]; then
	echo "
PhiX filtering workflow beginning in single read mode."
	echo "PhiX filtering workflow beginning in single read mode." >> $log
	
	elif [[ `echo $mode` == "paired" ]]; then
	echo "
PhiX filtering workflow beginning in paired read mode."
	echo "PhiX filtering workflow beginning in paired read mode." >> $log
	fi

	date "+%a %b %d %I:%M %p %Z %Y" >> $log
	res1=$(date +%s.%N)

## Make output directory for fastq-multx step

	mkdir $outdir/fastq-multx_output

## Extract barcodes information from mapping file

	grep -v "#" $mapfile | cut -f 1-3 > $outdir/fastq-multx_output/barcodes.fil
	barcodes=($outdir/fastq-multx_output/barcodes.fil)

## Fastq-multx command:

	echo "
Demultiplexing sample data with fastq-multx.  Allowing $multx_errors indexing
errors.
Mapping file: $mapfile"
	echo "
Demultiplexing data (fastq-multx):" >> $log
	date "+%a %b %d %I:%M %p %Z %Y" >> $log

	if [[ `echo $mode` == "single" ]]; then
	echo "	fastq-multx -m $multx_errors -x -B $barcodes $index $read1 -o $outdir/fastq-multx_output/index.%.fq -o $outdir/fastq-multx_output/read1.%.fq &>$outdir/fastq-multx_output/multx_log.txt" >> $log
	`fastq-multx -m $multx_errors -x -B $barcodes $index $read1 -o $outdir/fastq-multx_output/index.%.fq -o $outdir/fastq-multx_output/read1.%.fq &>$outdir/fastq-multx_output/multx_log.txt`
	
	elif [[ `echo $mode` == "paired" ]]; then
	echo "	fastq-multx -m $multx_errors -x -B $barcodes $index $read1 $read2 -o $outdir/fastq-multx_output/index.%.fq -o $outdir/fastq-multx_output/read1.%.fq -o $outdir/fastq-multx_output/read2.%.fq &>$outdir/fastq-multx_output/multx_log.txt" >> $log
	`fastq-multx -m $multx_errors -x -B $barcodes $index $read1 $read2 -o $outdir/fastq-multx_output/index.%.fq -o $outdir/fastq-multx_output/read1.%.fq -o $outdir/fastq-multx_output/read2.%.fq &>$outdir/fastq-multx_output/multx_log.txt`
	fi

## Remove unmatched sequences to save space (comment this out if you need to inspect them)

	echo "
Removing unmatched reads to save space."
	echo "
Removing unmatched reads:" >> $log
	date "+%a %b %d %I:%M %p %Z %Y" >> $log
	echo "	rm $outdir/fastq-multx_output/*unmatched.fq" >> $log

	rm $outdir/fastq-multx_output/*unmatched.fq

## Cat together multx results (in parallel)

	echo "
Remultiplexing demultiplexed data."
	echo "
Remultiplexing demultiplexed data:" >> $log
	date "+%a %b %d %I:%M %p %Z %Y" >> $log

	if [[ `echo $mode` == "single" ]]; then
	echo "	( cat $outdir/fastq-multx_output/index.*.fq > $outdir/fastq-multx_output/index.fastq ) &
	( cat $outdir/fastq-multx_output/read1.*.fq > $outdir/fastq-multx_output/read1.fastq ) &" >> $log

	( cat $outdir/fastq-multx_output/index.*.fq > $outdir/fastq-multx_output/index.fastq ) &
	( cat $outdir/fastq-multx_output/read1.*.fq > $outdir/fastq-multx_output/read1.fastq ) &

	elif [[ `echo $mode` == "paired" ]]; then
	echo "	( cat $outdir/fastq-multx_output/index.*.fq > $outdir/fastq-multx_output/index.fastq ) &
	( cat $outdir/fastq-multx_output/read1.*.fq > $outdir/fastq-multx_output/read1.fastq ) &
	( cat $outdir/fastq-multx_output/read2.*.fq > $outdir/fastq-multx_output/read2.fastq ) &" >> $log

	( cat $outdir/fastq-multx_output/index.*.fq > $outdir/fastq-multx_output/index.fastq ) &
	( cat $outdir/fastq-multx_output/read1.*.fq > $outdir/fastq-multx_output/read1.fastq ) &
	( cat $outdir/fastq-multx_output/read2.*.fq > $outdir/fastq-multx_output/read2.fastq ) &
	fi
	wait

## Define demultiplexed/remultiplexed read files

	idx=$outdir/fastq-multx_output/index.fastq
	rd1=$outdir/fastq-multx_output/read1.fastq
	if [[ `echo $mode` == "paired" ]]; then
	rd2=$outdir/fastq-multx_output/read2.fastq
	fi

## Remove demultiplexed components of read files (comment out if you need them, but they take up a lot of space)

	echo "
Removing redundant sequence files to save space."
	echo "
Removing extra files:" >> $log
	date "+%a %b %d %I:%M %p %Z %Y" >> $log
	echo "	rm $outdir/fastq-multx_output/*.fq" >> $log

	rm $outdir/fastq-multx_output/*.fq

## Smalt command to identify phix reads

	echo "
Smalt search of demultiplexed data."
	echo "
Smalt search of demultiplexed data:" >> $log
	date "+%a %b %d %I:%M %p %Z %Y" >> $log
	mkdir $outdir/smalt_output

	if [[ `echo $mode` == "single" ]]; then
	echo "	smalt map -n $smalt_threads -O -f sam:nohead -o $outdir/smalt_output/phix.mapped.sam $smaltdir/$smaltbase $rd1" >> $log
	`smalt map -n $smalt_threads -O -f sam:nohead -o $outdir/smalt_output/phix.mapped.sam $smaltdir/$smaltbase $rd1 &>>$log`

	elif [[ `echo $mode` == "paired" ]]; then
	echo "	smalt map -n $smalt_threads -O -f sam:nohead -o $outdir/smalt_output/phix.mapped.sam $smaltdir/$smaltbase $rd1 $rd2" >> $log
	`smalt map -n $smalt_threads -O -f sam:nohead -o $outdir/smalt_output/phix.mapped.sam $smaltdir/$smaltbase $rd1 $rd2 &>>$log`
	fi
	wait

#use grep to identify reads that are non-phix
	
	echo "
Screening smalt search for non-phix read pairs."
	echo "
Grep search of smalt output:" >> $log
	date "+%a %b %d %I:%M %p %Z %Y" >> $log

	if [[ `echo $mode` == "single" ]]; then
	echo "	egrep \".+\s4\s\" $outdir/smalt_output/phix.mapped.sam > $outdir/smalt_output/phix.unmapped.sam" >> $log
	egrep ".+\s4\s" $outdir/smalt_output/phix.mapped.sam > $outdir/smalt_output/phix.unmapped.sam

	elif [[ `echo $mode` == "paired" ]]; then
	echo "	egrep \".+\s77\s\" $outdir/smalt_output/phix.mapped.sam > $outdir/smalt_output/phix.unmapped.sam" >> $log
	egrep ".+\s77\s" $outdir/smalt_output/phix.mapped.sam > $outdir/smalt_output/phix.unmapped.sam
	fi
	wait

## Use filter_fasta.py to filter contaminating sequences out prior to joining

	echo "
Filtering phix reads from sample data."
	echo "
Filter phix reads with filter_fasta.py:" >> $log
	date "+%a %b %d %I:%M %p %Z %Y" >> $log

	if [[ `echo $mode` == "single" ]]; then
	echo "	( filter_fasta.py -f $outdir/fastq-multx_output/index.fastq -o $outdir/index.phixfiltered.fastq -s $outdir/smalt_output/phix.unmapped.sam ) &
	( filter_fasta.py -f $outdir/fastq-multx_output/read1.fastq -o $outdir/read1.phixfiltered.fastq -s $outdir/smalt_output/phix.unmapped.sam ) &" >> $log
	( filter_fasta.py -f $outdir/fastq-multx_output/index.fastq -o $outdir/index.phixfiltered.fastq -s $outdir/smalt_output/phix.unmapped.sam ) &
	( filter_fasta.py -f $outdir/fastq-multx_output/read1.fastq -o $outdir/read1.phixfiltered.fastq -s $outdir/smalt_output/phix.unmapped.sam ) &

	elif [[ `echo $mode` == "paired" ]]; then
	echo "	( filter_fasta.py -f $outdir/fastq-multx_output/index.fastq -o $outdir/index.phixfiltered.fastq -s $outdir/smalt_output/phix.unmapped.sam ) &
	( filter_fasta.py -f $outdir/fastq-multx_output/read1.fastq -o $outdir/read1.phixfiltered.fastq -s $outdir/smalt_output/phix.unmapped.sam ) &
	( filter_fasta.py -f $outdir/fastq-multx_output/read2.fastq -o $outdir/read2.phixfiltered.fastq -s $outdir/smalt_output/phix.unmapped.sam ) &" >> $log
	( filter_fasta.py -f $outdir/fastq-multx_output/index.fastq -o $outdir/index.phixfiltered.fastq -s $outdir/smalt_output/phix.unmapped.sam ) &
	( filter_fasta.py -f $outdir/fastq-multx_output/read1.fastq -o $outdir/read1.phixfiltered.fastq -s $outdir/smalt_output/phix.unmapped.sam ) &
	( filter_fasta.py -f $outdir/fastq-multx_output/read2.fastq -o $outdir/read2.phixfiltered.fastq -s $outdir/smalt_output/phix.unmapped.sam ) &
	fi
	wait

## Check for and remove empty fastq records

#	echo "
#Filtering empty fastq records from outputs." >> $log
#date "+%a %b %d %I:%M %p %Z %Y" >> $log
#	echo "
#Filtering empty fastq records from outputs."

#		emptycount=`grep -e "^$" $outdir/read1.phixfiltered0.fastq | wc -l`

#		if [[ $emptycount != 0 ]]; then

#		grep -B 1 -e "^$" $outdir/read1.phixfiltered0.fq > $outdir/empty.fastq.records
#		sed -i '/^\s*$/d' $outdir/empty.fastq.records
#		sed -i '/^\+/d' $outdir/empty.fastq.records
#		sed -i '/^\--/d' $outdir/empty.fastq.records
#		sed -i 's/^\@//' $outdir/empty.fastq.records
#		empties=`cat $outdir/empty.fastq.records | wc -l`
#	echo "
#Found $empties empty fastq records." >> $log
#	echo "
#Found $empties empty fastq records."

#	if [[ `echo $mode` == "single" ]]; then

#		( filter_fasta.py -f $outdir/read1.phixfiltered0.fastq -o $outdir/read1.phixfiltered.fq -s $outdir/empty.fastq.records -n ) &
#		( filter_fasta.py -f $outdir/index.phixfiltered0.fastq -o $outdir/index.phixfiltered.fq -s $outdir/empty.fastq.records -n ) &
#		wait

#	elif [[ `echo $mode` == "paired" ]]; then

#		( filter_fasta.py -f $outdir/read1.phixfiltered0.fastq -o $outdir/read1.phixfiltered.fq -s $outdir/empty.fastq.records -n ) &
#		( filter_fasta.py -f $outdir/read2.phixfiltered0.fastq -o $outdir/read2.phixfiltered.fq -s $outdir/empty.fastq.records -n ) &
#		( filter_fasta.py -f $outdir/index.phixfiltered0.fastq -o $outdir/index.phixfiltered.fq -s $outdir/empty.fastq.records -n ) &
#		wait
#	fi
#		fi

## Arithmetic and variable definitions to report PhiX contamintaion levels
	if [[ `echo $mode` == "single" ]]; then
	totalseqs=$(cat $outdir/smalt_output/phix.mapped.sam | wc -l)
	nonphixseqs=$(cat $outdir/smalt_output/phix.unmapped.sam | wc -l)
	phixseqs=$(($totalseqs-$nonphixseqs))
	nonphix100seqs=$(($nonphixseqs*100))
	datapercent=$(($nonphix100seqs/$totalseqs))
	contampercent=$((100-$datapercent))
	quotient=($phixseqs/$totalseqs)
	decimal=$(echo "scale=10; ${quotient}" | bc)
	elif [[ `echo $mode` == "paired" ]]; then
	totalseqs1=$(cat $outdir/smalt_output/phix.mapped.sam | wc -l)
	nonphixseqs=$(cat $outdir/smalt_output/phix.unmapped.sam | wc -l)
	totalseqs=$(($totalseqs1/2))
	phixseqs=$(($totalseqs-$nonphixseqs))
	nonphix100seqs=$(($nonphixseqs*100))
	datapercent=$(($nonphix100seqs/$totalseqs))
	contampercent=$((100-$datapercent))
	quotient=($phixseqs/$totalseqs)
	decimal=$(echo "scale=10; ${quotient}" | bc)
	fi

## Log results of PhiX filtering

	if [[ `echo $mode` == "single" ]]; then
	echo "
Processed $totalseqs single reads.
$phixseqs reads contained phix sequence.
Contamination level is approximately $contampercent percent.
Contamination level (decimal value): $decimal"

	echo "
Processed $totalseqs single reads.
$phixseqs reads contained PhiX174 sequence.
Contamination level is approximately $contampercent percent.
Contamination level (decimal value): $decimal" >> $log


	elif [[ `echo $mode` == "paired" ]]; then
	echo "
Processed $totalseqs read pairs.
$phixseqs read pairs contained phix sequence.
Contamination level is approximately $contampercent percent.
Contamination level (decimal value): $decimal"

	echo "
Processed $totalseqs read pairs.
$phixseqs read pairs contained PhiX174 sequence.
Contamination level is approximately $contampercent percent.
Contamination level (decimal value): $decimal" >> $log
	fi

## Remove excess files

	rm -r $outdir/smalt_output
	rm $outdir/fastq-multx_output/*.fastq


## Log script completion

res2=$(date +%s.%N)
dt=$(echo "$res2 - $res1" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Total runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`

echo "
Workflow steps completed.  Hooray!
$runtime
"
echo "
---

All workflow steps completed.  Hooray!" >> $log
date "+%a %b %d %I:%M %p %Z %Y" >> $log
echo "
$runtime 
" >> $log

exit 0
