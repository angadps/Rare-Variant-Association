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

sort -k 2,2nr ${score}.decrypted > ${score}.decrypted.sorted

actual_gene=`<$gene_file`
top_score=`head -1 ${score}.decrypted.sorted | cut -f 2`
top_genes=`awk -v top=$top_score '{if($2==top) print $1}' ${score}.decrypted.sorted`

if [[ -n `echo $top_genes | grep $actual_gene` ]]
then
	power=`<$power_file`
	let "power=$power+1"
	echo $power > $power_file
fi


