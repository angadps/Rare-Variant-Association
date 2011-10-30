#!/usr/bin/perl
#Rajan Banerjee reb2143
#This script will run association tests on all genes.

my $length = scalar(@ARGV);
my $out; #The output file
my $dir; #The directory containing the gene files 
my $info; #The file  mapping a gene to a number directory

for($i=0;$i<=($length-1);$i++){

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
my $complete = 0;
my $thresh = 0;

#$GN = `find $dir -type d | wc -l`;  #Counts the numbered gene files in the given directory, GN will also count the directory itself, so it is one greater than the number needed

#for($i=1;$i<=$GN;$i++){ #run the association test on each of the numbered gene directories
while(1) {
        binmode info; my $gene_name = "";
        if(($n = read info, $gene_name, 8)!=8) {
                if($n == 0) {last;}
                else { die "Gene name not in required format\n";}
        }
        my $sep = "";
        if(($n = read info, $sep, 1)!=1) {
                die "No proper separator after $gene_name. Cannot map\n"; }
        if($sep ne "	") {
                die "No proper separator after $gene_name. Cannot map\n"; }

        my $s = "";my $i = 0;my @gene = "";
        while(($n = read info, $s, 1)!=0) {
                if($s ne "\n") {
                        $gene[$i++] = $s;
                } else { last;}
        }
        if($n == 0) {
                die "No proper separator after @gene. Cannot map\n"; }
	#my $gene_loc = $dir;
	my $gene_loc = join('', @gene);
	

$output = `/ifs/scratch/c2b2/ip_lab/aps2157/privacy/code/R/R-2.13.2/bin/Rscript --slave rareVariantTests.R -p 1 -n 0 -a "$gene_loc.data.pheno" -b "$gene_loc.data.wt" -c "$gene_loc.data.geno"`;
#$output = `/nfs/apps/R/2.9.0/bin/Rscript --slave /ifs/scratch/c2b2/ip_lab/reb2143/rareVariantTests.R -p 100000 -n 0 -a $dir/gene$i/data.pheno -b $dir/gene$i/data.wt -c $dir/gene$i/data.geno`;

	$complete ++;
	if($complete > $thresh) {
		print "Association $complete complete\n";
		$thresh+= 1000;
	}
#The following takes the output of the tests, and obtains the relavent madison-browning association score.
my @array = split(/\n/,$output);
my @score = split(/\s/,$array[13]);

#if($score<=0.1){  #if uncommented, this if statement will remove all genes that do not meet a certain significance threshold. In this case alpha =.1
print scores "$gene_name\t$score[5]\n";
#}
}
close info;
close scores;
