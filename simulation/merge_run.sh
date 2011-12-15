#!/bin/sh
#$ -cwd
# -l mem=1G,time=4::

src_dir=$1
dest_dir=$2
score=$3
gene_file=$4
power_file=$5
op=1

perl engine.pl -src=$src_dir -dest=$dest_dir -score=$score -op=$op

