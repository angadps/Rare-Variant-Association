#!/bin/sh
#$ -cwd

for i in `seq 2 2`
do
	qsub ./make_vcf.sh $i
done

