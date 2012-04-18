#!/bin/sh
#$ -cwd

job=$1
Data="Data_run"
num_var=10
ds_limit=100
PI_limit=10
UN="unmerged"
IP="assoc_inp"
OP="assoc_output"

let "n_var=2**$num_var"
if [[ $job -eq 0 ]]
then
	echo "$0 [1|2|3|4|5|6]"
fi

if [[ $job -eq 1 || $job -eq 4 || $job -eq 6 ]]
then
for n_add_ind in `seq 0 $num_var`
do
	let "n_add_var=2**$n_add_ind"
	for ds in `seq 1 $ds_limit`
	do
		srcdir=$Data/$UN/var-$n_add_var/ds${ds}_out
		mkdir -p $srcdir
		for pi in `seq 1 $PI_limit`
		do
			unmergeddir=$Data/PI-$pi/var-$n_add_var/ds${ds}_out
			#rm -rf $srcdir/PI_$pi
			mv $unmergeddir $srcdir/PI_$pi
		done
	done
	echo var-$n_add_var files moved
done
echo "All files moved"
fi

if [[ $job -eq 2 || $job -eq 4 || $job -eq 5 || $job -eq 6 ]]
then
mkdir -p $Data/$OP
for n_add_ind in `seq 0 $num_var`
do
	let "n_add_var=2**$n_add_ind"
	power_file=$Data/$OP/var-$n_add_var.rank
	for ds1 in `seq 1 10`
	do
		for ds2 in `seq 1 10`
		do
			let "ds=((ds1-1)*10)+ds2"
			#for ds in `seq 1 $ds_limit`
			#do
			srcdir=$Data/$UN/var-$n_add_var/ds${ds}_out
			destdir=$Data/$IP/var-$n_add_var/ds${ds}_out
			rm -rf $destdir
			score_file=$Data/$OP/var-${n_add_var}_ds${ds}.txt
			gene_file=$Data/PI-1/var-$n_var/ds_$ds.gene
			op=1
			#rm -rf $destdir
			mkdir -p $destdir
			sh merge_run.sh $srcdir $destdir $score_file $gene_file $power_file &
			#done
		done
		while [[ `ps -ef | grep aps | grep -c merge_r` -gt 1 ]]
		do
			ps -ef | grep aps | grep -c merge_r
			sleep 100
		done
	done
done
fi

if [[ $job -eq 3 || $job -eq 5 || $job -eq 6 ]]
then
mkdir -p $Data/$OP
for n_add_ind in `seq 0 $num_var`
do
	let "n_add_var=2**$n_add_ind"
	power_file=$Data/$OP/var-$n_add_var.rank
	echo 0 > $power_file
	for ds in `seq 1 $ds_limit`
	do
		srcdir=$Data/$UN/var-$n_add_var/ds${ds}_out
		destdir=$Data/$IP/var-$n_add_var/ds${ds}_out
		score_file=$Data/$OP/var-${n_add_var}_ds${ds}.txt
		gene_file=$Data/PI-1/var-$n_var/ds_$ds.gene
		op=2
		#rm -rf $destdir
		mkdir -p $destdir
		qsub -l mem=1G,time=60:: -hard assoc_run.sh $srcdir $destdir $score_file $gene_file $power_file 1
	done
done
fi


if [[ $job -eq 7 ]]
then
mkdir -p $Data/$OP
for n_add_ind in `seq 0 $num_var`
do
	let "n_add_var=2**$n_add_ind"
	power_file=$Data/$OP/PI-1-var-$n_add_var.rank
	echo 0 > $power_file
	for ds in `seq 1 $ds_limit`
	do
		srcdir=$Data/$UN/var-$n_add_var/ds${ds}_out
		destdir=$Data/$UN/var-$n_add_var/ds${ds}_out/PI_1
		score_file=$Data/$OP/PI-1-var-${n_add_var}_ds${ds}.txt
		gene_file=$Data/PI-1/var-$n_var/ds_$ds.gene
		op=2
		#rm -rf $destdir
		mkdir -p $destdir
		qsub -hard -l mem=1G,time=60:: assoc_run.sh $srcdir $destdir $score_file $gene_file $power_file 2
	done
done
fi

