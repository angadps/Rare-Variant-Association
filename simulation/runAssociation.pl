#!/usr/bin/perl
#Rajan Banerjee reb2143
#This script will run association tests on all genes.

my $length = scalar(@ARGV);
my $out; #The output file
my $dir; #The directory containing the gene files 
my $info; #The file  mapping a gene to a number directory
my $type;

for($i=0;$i<=($length-1);$i++){

if($ARGV[$i] eq -type){
	$i++;
	$type=$ARGV[$i];
}

if($ARGV[$i] eq -out){
	$i++;
	$out=$ARGV[$i];
}

if($ARGV[$i] eq -dir){
$i++;
$dir = $ARGV[$i];
}
}

$info = "$dir/info.txt";
open(info, "<", "$info") or die "Info file cannot be opened!";
open scores, ">", "$out" or die "Output file cannot be opened!";
my $complete = 0;
my $thresh = 0;
while(1) {
        binmode info; my $gene_name = "";
        if(($n = read info, $gene_name, 8)!=8) {
                if($n == 0) {print "No more genes\n\n"; last;}
                else { print "Gene name $gene_name not in required format\n"; } # die "Gene name not in required format\n"; 
        }
        my $sep = "";
        if(($n = read info, $sep, 1)!=1) {
                print "No proper separator after $gene_name. Cannot map\n"; } # die "No separator after $gene_name, $n\n";
        if($sep ne "	") {
                print "No proper separator after $gene_name. Cannot map\n"; } # die "No proper separator after $gene_name, $sep\n";
        my $s = "";my $i = 0;my @gene = "";
        while(($n = read info, $s, 1)!=0) {
                if($s ne "\n") {
                        $gene[$i++] = $s;
                } #elsif(scalar(@gene)==0) {print "No more weights @gene";}
		else {last;}
        }
        if($n == 0) {
                print "No proper gene path @gene. Cannot map\n"; } # die "No separator after @gene\n";
	my $gene_loc = join('', @gene);
if($type==1) {
$output = `/ifs/scratch/c2b2/ip_lab/aps2157/privacy/code/R/R-2.13.2/bin/Rscript --slave rareVariantTests.R -p 100000 -n 0 -a "$gene_loc.data.pheno" -b "$gene_loc.data.wt" -c "$gene_loc.data.geno"`;} elsif($type==2) {
$output = `/ifs/scratch/c2b2/ip_lab/aps2157/privacy/code/R/R-2.13.2/bin/Rscript --slave rareVariantTests.R -p 100000 -n 0 -a "$dir/$gene_loc.data.pheno" -b "$dir/$gene_loc.data.wt" -c "$dir/$gene_loc.data.geno"`; }
#$output = `/nfs/apps/R/2.9.0/bin/Rscript --slave /ifs/scratch/c2b2/ip_lab/reb2143/rareVariantTests.R -p 100000 -n 0 -a $dir/gene$i/data.pheno -b $dir/gene$i/data.wt -c $dir/gene$i/data.geno`;
#print "output: $output\n";
	$complete ++;
	if($complete > $thresh) {
		print "Association $complete complete\n";
		$thresh+= 1000;
	}
#The following takes the output of the tests, and obtains the relavent madison-browning association score.
my @array = split(/\n/,$output);
my @score = split(/\s/,$array[6]);
#if($score<=0.1){  #if uncommented, this if statement will remove all genes that do not meet a certain significance threshold. In this case alpha =.1
my $vtscore = substr(join('',@score),1);

print scores "$gene_name\t$vtscore\n";
#}
}
close info;
close scores;

