#!/bin/sh
#$ -cwd

num_var=10
Data=$1
OP=assoc_output
let "n_var=2**$num_var"
ds_limit=100

CURR_DIR=$PWD

for n_add_ind in `seq 0 $num_var`
do
	let "n_add_var=2**$n_add_ind"
	any_power_file=$Data/$OP/var-$n_add_var.rank.any
	only_power_file=$Data/$OP/var-$n_add_var.rank.only
	echo 0 > $any_power_file
	echo 0 > $only_power_file
	for ds in `seq 1 $ds_limit`
	do
		score_file=$Data/$OP/var-${n_add_var}_ds${ds}.txt
		gene_file=$Data/PI-1/var-$n_var/ds_$ds.gene
		actual_gene=`<$gene_file`
		top_score=`head -1 ${score_file}.decrypted.sorted | cut -f 2`
		second_score=`head -2 ${score_file}.decrypted.sorted | tail -1 | cut -f 2`
		gene_score=`grep $actual_gene ${score_file}.decrypted.sorted | cut -f 2`
		#top_genes=`awk -v top=$top_score '{if($2==top) print $1}' ${score_file}.decrypted.sorted`
		if [[ $gene_score == $top_score ]]
		then
			power=`<$any_power_file`
			let "power=$power+1"
			echo $power > $any_power_file
			if [[ $second_score != $top_score ]]
			then
				power=`<$only_power_file`
				let "power=$power+1"
				echo $power > $only_power_file
			fi
		fi
	done
done

for n_add_ind in `seq 0 $num_var`
do
	let "n_add_var=2**$n_add_ind"
	only_power_file=$Data/$OP/var-$n_add_var.rank.pi.only
	max_power_file=$Data/$OP/var-$n_add_var.rank.pi.max
	any_power_file=$Data/$OP/var-$n_add_var.rank.pi.any
	echo 0 > $only_power_file
	echo 0 > $max_power_file
	echo 0 > $any_power_file
	rm $Data/$OP/score_list-var-${n_add_var}_ds*.txt

	for pin in `seq 1 10`
	do
		for ds in `seq 1 $ds_limit`
		do
			score_file=$Data/$OP/PI-${pin}-var-${n_add_var}_ds${ds}.txt
			gene_file=$Data/PI-${pin}/var-$n_var/ds_$ds.gene
			score_list_file=$Data/$OP/score_list-var-${n_add_var}_ds${ds}.txt
			#qsub -hard -l mem=1G,time=5:: assoc_run.sh $srcdir $destdir $score_file $gene_file $power_file 2
			actual_gene=`<$gene_file`
			top_score=`head -1 ${score_file}.decrypted.sorted | cut -f 2`
			second_score=`head -2 ${score_file}.decrypted.sorted | tail -1 | cut -f 2`
			gene_score=`grep $actual_gene ${score_file}.decrypted.sorted | cut -f 2`
			head -1 ${score_file}.decrypted.sorted >> $score_list_file
			if [[ $gene_score == $top_score ]]
			then
				if [[ $second_score != $top_score ]]
				then
					power=`<$only_power_file`
					let "power=$power+1"
					echo $power > $only_power_file
				fi
			fi
		done
	done
	power=`<$only_power_file`
	let "power=$power/10"
	echo $power > $only_power_file

	for ds in `seq 1 $ds_limit`
	do
		gene_file=$Data/PI-1/var-$n_var/ds_$ds.gene
		score_list_file=$Data/$OP/score_list-var-${n_add_var}_ds${ds}.txt
		actual_gene=`<$gene_file`
		if [[ -n `grep $actual_gene $score_list_file` ]]
		then
			power=`<$any_power_file`
			let "power=$power+1"
			echo $power > $any_power_file
		fi
		max_scoring_gene=`sort $score_list_file | uniq -c | awk '{sub(/^[ \t]+/,"");print;}' | tr ' ' '\t' | sort -k1,1nr | head -1 | cut -f 2`
		max_score=`sort $score_list_file | uniq -c | awk '{sub(/^[ \t]+/,"");print;}' | tr ' ' '\t' | sort -k1,1nr | head -1 | cut -f 1`
		second_max_score=`sort $score_list_file | uniq -c | awk '{sub(/^[ \t]+/,"");print;}' | tr ' ' '\t' | sort -k1,1nr | head -2 | tail -1 | cut -f 1`
		if [[ $max_scoring_gene == $actual_gene ]]
		then
			if [[ $max_score -gt $second_max_score ]]
			then
				power=`<$max_power_file`
				let "power=$power+1"
				echo $power > $max_power_file
			fi
		fi
	done
done

pool_only_rank_file=$Data/$OP/pooled_test_with_unique_top_ranks
pool_any_rank_file=$Data/$OP/pooled_test_with_a_top_rank
unpool_only_rank_file=$Data/$OP/unpooled_test_with_unique_top_ranks
unpool_max_rank_file=$Data/$OP/unpooled_test_with_maximal_set_of_top_ranks
unpool_any_rank_file=$Data/$OP/unpooled_test_with_a_top_rank

rm $pool_only_rank_file
rm $pool_any_rank_file
rm $unpool_only_rank_file
rm $unpool_max_rank_file
rm $unpool_any_rank_file

for n_add_ind in `seq 0 $num_var`
do
	let "n_add_var=2**$n_add_ind"
	pool_only_power_file=$Data/$OP/var-$n_add_var.rank.only
	pool_any_power_file=$Data/$OP/var-$n_add_var.rank.any
	unpool_only_power_file=$Data/$OP/var-$n_add_var.rank.pi.only
	unpool_max_power_file=$Data/$OP/var-$n_add_var.rank.pi.max
	unpool_any_power_file=$Data/$OP/var-$n_add_var.rank.pi.any

	echo $n_add_var `cat $pool_only_power_file` | tr ' ' '\t' >> $pool_only_rank_file
	echo $n_add_var `cat $pool_any_power_file` | tr ' ' '\t' >> $pool_any_rank_file
	echo $n_add_var `cat $unpool_only_power_file` | tr ' ' '\t' >> $unpool_only_rank_file
	echo $n_add_var `cat $unpool_max_power_file` | tr ' ' '\t' >> $unpool_max_rank_file
	echo $n_add_var `cat $unpool_any_power_file` | tr ' ' '\t' >> $unpool_any_rank_file
done

echo Plot using gnuplot now...

