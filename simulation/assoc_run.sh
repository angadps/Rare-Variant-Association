#!/bin/sh
#$ -cwd
####$ -l mem=1G,time=60::

src_dir=$1
dest_dir=$2
score=$3
gene_file=$4
power_file=$5
op=2
type=$6

perl engine.pl -src=$src_dir -dest=$dest_dir -score=$score -op=$op -type=$type

sort -k 2,2gr ${score}.decrypted > ${score}.decrypted.sorted

