#!/bin/sh
#$ -cwd
# -l mem=1G,time=4::

Data="Data_run"
n_add_var=$1
pi=$2
n_var=$3
ds=$SGE_TASK_ID

dir="$Data/PI-$pi/var-$n_add_var"
gene_dir="$Data/PI-$pi/var-$n_var"
output="$dir/ds${ds}_out"
weights="data/weights.txt"
ref="data/bcm_hg18.fasta"

mkdir -p $output
perl client.pl -user="user$pi" -cases=$dir/case_$ds -controls=$dir/ctrl_$ds -weight=$weights -gene_ref=$gene_dir/ds_${ds}.log -ref=$ref -out=$output

