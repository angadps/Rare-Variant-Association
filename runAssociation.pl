#!/usr/bin/perl
#Rajan Banerjee reb2143
#This script will run association tests on all genes.

my $length = scalar(@ARGV);
my $out; #The output file
my $dir; #The directory containing the gene files 
my $info; #The file  mapping a gene to a number directory

for($i=0;$i<=($length-1);$i++){
#This logic control loops through all the command line arguments
#if a regonized flag is passed, the next command line argument is 
#used as information that flag signals.

if($ARGV[$i] eq -out){
	$i++;
	$out=$ARGV[$i];
}

if($ARGV[$i] eq -info){
$i++;
$info = $ARGV[$i];
}

if($ARGV[$i] eq -dir){
$i++;
$dir = $ARGV[$i];
}
}

$info = "$dir/info.txt";
open(info, "<", "$info") or die "Info file cannot be opened!";
open scores, ">", "$out" or die "Output file cannot be opened!";
my $GN = `wc -l $info`;

#$GN = `find $dir -type d | wc -l`;  #Counts the numbered gene files in the given directory, GN will also count the directory itself, so it is one greater than the number needed

for($i=1;$i<=$GN;$i++){ #run the association test on each of the numbered gene directories
my $line = <info>;
chomp $line;
my @gene = split(/\t/, $line);

$output = `/ifs/scratch/c2b2/ip_lab/aps2157/privacy/code/R/R-2.13.2/bin/Rscript --slave rareVariantTests.R -p 1000 -n 0 -a $gene[0].data.pheno -b $gene[0].data.wt -c $gene[0].data.geno`;
#$output = `/nfs/apps/R/2.9.0/bin/Rscript --slave /ifs/scratch/c2b2/ip_lab/reb2143/rareVariantTests.R -p 100000 -n 0 -a $dir/gene$i/data.pheno -b $dir/gene$i/data.wt -c $dir/gene$i/data.geno`;

#The following takes the output of the tests, and obtains the relavent madison-browning association score.
my @array = split(/\n/,$output);
my @score = split(/\s/,$array[13]);

#if($score<=0.1){  #if uncommented, this if statement will remove all genes that do not meet a certain significance threshold. In this case alpha =.1
print scores "$gene[1]\t$score[5]\n";
#}
}
close info;
close scores;
