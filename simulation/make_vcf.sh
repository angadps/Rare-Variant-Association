#!/bin/sh
#$ -cwd
# -l mem=1G,time=2::

# Usage: <./make_vcf_awk.sh 1>

data="Data_run"
ds_limit=100
PI_limit=10
var_ind=10
ind_limit=50
var_len=1000
large_file="sample_1024.txt"

genome_file="data/RefSeqGenes.txt"
genome_len=`grep -vc ^'#' $genome_file`
header="#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT"
case_header=$header
ctrl_header=$header

line="##fileformat=VCFv4.0\n##INFO=<ID=DP,Number=1,Type=Integer,Description=\"Total Depth\">\n##INFO=<ID=HM2,Number=0,Type=Flag,Description=\"HapMap2 membership\">\n##INFO=<ID=HM3,Number=0,Type=Flag,Description=\"HapMap3 membership\">\n##INFO=<ID=AA,Number=1,Type=String,Description=\"Ancestral Allele, ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/pilot_data/technical/reference/ancestral_alignments/README\">\n##reference=human_b36_both.fasta\n##INFO=<ID=AC,Number=1,Type=Integer,Description=\"total number of alternate alleles in called genotypes\">\n##INFO=<ID=AN,Number=1,Type=Integer,Description=\"total number of alleles in called genotypes\">\n##FORMAT=<ID=GT,Number=1,Type=String,Description=\"Genotype\">\n##FORMAT=<ID=DP,Number=1,Type=Integer,Description=\"Read Depth from MOSAIK BAM\">"

snpid="."
refbase="A"
altbase="C"
qual="."
filter="PASS"
info="AA=A;AC=10;AN=150;DP=1000"
format="GT:DP"

snpinfo="\t$snpid\t$refbase\t$altbase\t$qual\t$filter\t$info\t$format"

for ind in `seq 1 $ind_limit`
do
	case_header=$case_header"\tCASE"$ind
	ctrl_header=$ctrl_header"\tCTRL"$ind
done

let "n_var=2**$var_ind"
for ds in `seq 1 $ds_limit`
do
	rnd_line=`awk -v len="$genome_len" 'BEGIN{srand();line=int(rand()*len)+2; print line}'`
	if [[ $rnd_line -lt 3 ]]
	then
		let "rnd_line=$rnd_line+3"
	elif [[ $rnd_line -gt $genome_len ]]
	then
		let "rnd_line=$rnd_line-10"
	fi
	for PI in `seq 1 $PI_limit`
	do
		dir=$data"/PI-"$PI"/var-"$n_var
		ctrl_input_file=$dir"/ctrl_"$ds".txt"
		case_input_file=$dir"/case_"$ds".txt"
		ctrl_output_file=$dir"/ctrl_"$ds".vcf"
		case_output_file=$dir"/case_"$ds".vcf"

		echo -e $line > $ctrl_output_file
		echo -e $ctrl_header >> $ctrl_output_file
		echo -e $line > $case_output_file
		echo -e $case_header >> $case_output_file

		rm -f temp_vcf_$n_var
		head -$rnd_line $genome_file | tail -1 | awk '{print $1}' > $dir"/ds_"$ds".gene"
		chr=`head -$rnd_line $genome_file | tail -1 | awk '{print $2}' | cut -d'_' -f1`
		start=`head -$rnd_line $genome_file | tail -1 | awk '{print $4}'`
		end=`head -$rnd_line $genome_file | tail -1 | awk '{print $5}'`
		rsnpinfo="\t$refbase\t$altbase\t$qual\t$filter\t$info\t$format"
		head -$n_var $large_file | awk -v chr=$chr -v start=$start -v end=$end -v snp="$rsnpinfo" -v ind=$ind_limit 'BEGIN {srand();ct=1;}{id=int(rand()*ind)+1; pos=start+int(rand()*(end-start)); printf chr; printf "\t"; printf pos; printf "\trs%05d",ct++; printf snp; for (i=1;i<=NF;i++) {if(i==id) { if(rand()>0.1) printf "\t0|1:10"; else printf "\t1|1:10";} else { if($i==0) {printf "\t0|0:10"} else if($i==1) {printf "\t0|1:10"} else if($i==2) {printf "\t1|1:10"} else {printf "\tProblematic $i"}}} printf "\n"}' >> temp_vcf_$n_var

		tail -$var_len $case_input_file | awk -v genome="$genome_file" -v snp="$snpinfo" 'BEGIN {srand(); if(getline < genome > 0) ; while(getline < genome > 0) {j++;for(i=1;i<=5;i++) {arr[j,i]=$i}}} {line=int(rand()*j)+1; chrs=arr[line,2];split(chrs,chr,"_");start=arr[line,4];end=arr[line,5];pos=start+int(rand()*(end-start));printf chr[1]; printf "\t"; printf pos; printf snp; for (i=1;i<=NF;i++) {if($i==0) {printf "\t0|0:10"} else if($i==1) {printf "\t0|1:10"} else if($i==2) {printf "\t1|1:10"} else {printf "\tProblematic $i"}}printf "\n"}' >> temp_vcf_$n_var
		grep -v chrY temp_vcf_$n_var | grep -v chrM | grep -v chrX | sort -k 1.4n -k 2,2n >> $case_output_file
		grep chrX temp_vcf_$n_var | sort -k 2,2n >> $case_output_file
		grep chrY temp_vcf_$n_var | sort -k 2,2n >> $case_output_file
		grep chrM temp_vcf_$n_var | sort -k 2,2n >> $case_output_file

		tail -$var_len $ctrl_input_file | awk -v genome="$genome_file" -v snp="$snpinfo" 'BEGIN {srand(); if(getline < genome > 0) ; while(getline < genome > 0) {j++;for(i=1;i<=5;i++) {arr[j,i]=$i}}} {line=int(rand()*j+1); chrs=arr[line,2];split(chrs,chr,"_");start=arr[line,4];end=arr[line,5];pos=start+int(rand()*(end-start));printf chr[1]; printf "\t"; printf pos; printf snp; for (i=1;i<=NF;i++) {if($i==0) {printf "\t0|0:10"} else if($i==1) {printf "\t0|1:10"} else if($i==2) {printf "\t1|1:10"} else {printf "\tProblematic $i"}}printf "\n"}' | sort -k 1.4n -k 2,2n > temp_vcf_$n_var
		grep -v chrY temp_vcf_$n_var | grep -v chrM | grep -v chrX >> $ctrl_output_file
		grep chrX temp_vcf_$n_var >> $ctrl_output_file
		grep chrY temp_vcf_$n_var >> $ctrl_output_file
		grep chrM temp_vcf_$n_var >> $ctrl_output_file
		rm temp_vcf_$n_var
	done
done

