#!/bin/sh
#$ -cwd
#!/usr/bin/perl -w

job=$1
Data="Data_run"
PI_limit=10
ds_limit=100
num_var=10
VCF="$PWD/vcfCodingSnps.v1.5"
gene_ref="/ifs/scratch/c2b2/ip_lab/aps2157/privacy/code/simulation/data/RefSeqGenes.txt"
#REF="/ifs/scratch/c2b2/ip_lab/aps2157/privacy/code/simulation/data/bcm_hg18.fasta"
REF="/ifs/scratch/c2b2/ip_lab/aps2157/privacy/code/simulation/data/human_g1k_v37.fasta"

let "n_var=2**$num_var"

if [[ $job -eq 0 ]]
then
	echo "$0 [1|2|3|4|5|6]"
fi

if [[ $job -eq 1 || $job -eq 4 || $job -eq 6 ]]
then
for stat in "case" "ctrl"
do
for pi in `seq 1 $PI_limit`
do
	dir="$PWD/$Data/PI-$pi/var-$n_var"
	for ds in `seq 1 $ds_limit`
	do
		file=$dir/${stat}_$ds
		#echo "qsub -b y -l mem=8G,time=1:: -o $file.out -e $file.err $VCF -s $file.vcf -g $gene_ref -r $REF -o ${file}_annotated.vcf -l $file.log"
		qsub -b y -hard -l mem=8G,time=1:: -o $file.out -e $file.err $VCF -s $file.vcf -g $gene_ref -r $REF -o ${file}_annotated.vcf -l $file.log
	done
done
done
fi
if [[ $job -eq 2 || $job -eq 4 || $job -eq 5 || $job -eq 6 ]]
then

for pi in `seq 1 $PI_limit`
do
	dir="$PWD/$Data/PI-$pi/var-$n_var"
	for ds in `seq 1 $ds_limit`
	do
		head -1 $dir/ctrl_${ds}.log > $dir/ds_${ds}.log
		grep -hav "ucsc_name" $dir/ctrl_${ds}.log $dir/case_${ds}.log | awk '{for(i=1;i<=NF;i++) {if(i==1){split($1,chr,"_");printf chr[1];} else printf "\t%s",$i;}printf "\n";}' | sort -u >> $dir/ds_${ds}.log
		#rm $dir/ctrl_${ds}.log $dir/case_${ds}.log
	done
	echo "Genelist preparation for user $pi complete"
done

let "num_var_c=$num_var-1"
for n_add_ind in `seq 0 $num_var_c`
do
	let "n_add_var=2**$n_add_ind"
	for pi in `seq 1 $PI_limit`
	do
		srcdir="$PWD/$Data/PI-$pi/var-$n_var"
		destdir="$PWD/$Data/PI-$pi/var-$n_add_var"
		mkdir -p $destdir
		for ds in `seq 1 $ds_limit`
		do
			cp $srcdir/ctrl_${ds}_annotated.vcf $destdir/ctrl_${ds}_annotated.vcf
			grep ^'#' $srcdir/case_${ds}_annotated.vcf > $destdir/case_${ds}_annotated.vcf
			grep -v ^'#' $srcdir/case_${ds}_annotated.vcf | awk -v nvar=$n_add_var '{if(match($3,"rs")==0) print $0; else if(nvar>0) {print $0; nvar--;}}' >> $destdir/case_${ds}_annotated.vcf
		done
	done
	echo "vcf generation for var-$n_add_var complete"
done
fi
if [[ $job -eq 3 || $job -eq 5 || $job -eq 6 ]]
then

for n_add_ind in `seq 0 $num_var`
do
	let "n_add_var=2**$n_add_ind"
	for pi in `seq 1 $PI_limit`
	do
		qsub -t 1-$ds_limit ./run_client.sh $n_add_var $pi $n_var
	done
	while [[ -n `qstat | grep run_client` ]]
	do
		echo `qstat | grep -c run_client` jobs waiting on variant count $n_add_var ...
		sleep 100
	done
done
fi

