#!/bin/sh
#!/bin/awk

if [[ $5 == "" ]]
then
	echo "Usage $0 <Control file> <new file> <snp count> <heterozygote count> <alternate homogygote count>"
fi

ctrl=$1
case=$2
per_snps=$3
per_alt=$4
per_alt2=$5
temp_file="temp.sim"
tab="	"

`grep -v ^'#' $ctrl > $temp_file`

lines=`grep -cv '#' $ctrl`
inds=`tail -1 $ctrl | awk '{print NF}'`
let "inds = $inds - 9"
let "snps = $lines * $per_snps"
let "snps = $snps/100"
let "alt = $inds * $per_alt"
let "alt = $alt / 100"
let "alt2 = $inds * $per_alt2"
let "alt2 = $alt2 / 100"

for i in `seq 1 $snps`
do
	chr=$RANDOM
	let "chr=$chr%22 + 1"
	pre=`tail -1 $ctrl | cut -f 1 | grep chr`

	if [[ -n $pre ]]
	then
		pre="chr"
	fi

	flag=0
	while [[ $flag -eq 0 ]]
	do
		pos=`cat /dev/urandom|od -N3 -An -i | tr -d ' '`
		lchr=`cut -f 1 $ctrl | grep -v ^'#' | grep -w "$pre$chr"`
		pchr=`cut -f 2 $ctrl | grep -v ^'#' | grep -w $pos`
		if [[ -z $lchr || -z $pchr ]]
		then
			flag=1
		fi
	done

	snpid="."
	refbase="A"
	altbase="C"
	qual="."
	filter="PASS"
	info="AA=A;AC=10;AN=150;DP=1000"
	format="GT:DP"

	#rand_outer=$((`cat /dev/urandom|od -N3 -An -i` % 100))
	rand_outer=$[ ($RANDOM % 101) ]
	if [[ $rand_outer -le $per_alt ]]
	then
		geno=""
		for it in `seq 1 $inds`
		do
			rand_inner=$[($RANDOM%101)]
			if [[ $rand_inner -le 30 ]]
			then
				gt="0/1:10"
			elif [[ $rand_inner -le 60 ]]
			then
				gt="1/0:10"
			elif [[ $rand_inner -le 90 ]]
			then
				gt="./.:10"
			elif [[ $rand_inner -le 95 ]]
			then
				gt="1/1:10"
			else
				gt="0/0:10"
			fi
			geno=$geno$tab$gt
		done
	elif [[ $rand_outer -le `expr $per_alt + $per_alt2` ]]
	then
		geno=""
		for it in `seq 1 $inds`
		do
			rand_inner=$[($RANDOM%101)]
			if [[ $rand_inner -le 90 ]]
			then
				gt="1/1:10"
			elif [[ $rand_inner -le 95 ]]
			then
				gt="0/0:10"
			else
				gt="0/1:10"
			fi
			geno=$geno$tab$gt
		done
	else
		geno=""
		for it in `seq 1 $inds`
		do
			rand_inner=$[($RANDOM%101)]
			if [[ $rand_inner -le 90 ]]
			then
				gt="0/0:10"
			elif [[ $rand_inner -le 95 ]]
			then
				gt="1/1:10"
			else
				gt="1/0:10"
			fi
			geno=$geno$tab$gt
		done
	fi
	newsnp="$pre$chr$tab$pos$tab$snpid$tab$refbase$tab$altbase$tab$qual$tab$filter$tab$info$tab$format$geno"
	printf "$newsnp\n" >> $temp_file
done

`grep ^'#' $ctrl > $case`
`sort -k 1,1n -k 2,2n $temp_file >> $case`
`rm -rf $temp_file`

