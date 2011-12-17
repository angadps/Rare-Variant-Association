#!/usr/bin/perl
#Rajan Banerjee
#reb2143
#This will decrypt the information output by the runAssociation.pl script

use lib '/ifs/scratch/c2b2/ip_lab/reb2143/securityProject/Crypt'; #location of CBC.pm
use Crypt::CBC;


my $length = scalar(@ARGV);
my $out; #the output file
my $scores; #the output from runAssociation.pl
my $key; #the encryption key generated from DecideKey 1 and 2

for($i=0;$i<=($length-1);$i++){
#This logic control loops through all the command line arguments
#if a regonized flag is passed, the next command line argument is 
#used as information that flag signals.

if($ARGV[$i] eq -out){
	$i++;
	$out=$ARGV[$i];
	
}
if($ARGV[$i] eq -keyfile){
$i++;
$key = $ARGV[$i];
}
if($ARGV[$i] eq -scores){
$i++;
$scores = $ARGV[$i];
}

}
open(info, "<", "$scores") or die "Info file cannot be opened!";
open scores, ">", "$out" or die "Output file cannot be opened!";
print "Scores: $scores\nOut: $out\nKey: $key\n";

open key, "<", "$key" or die "Can't open key file $key!";


read(key,$key,8);
  $cipher = Crypt::CBC->new(-key         => "$key",
				'regenerate_key'  => 0,
				-iv => "$key",
				'prepend_iv' => 0,
                           ); 		#generates the cipher

while(1) {
	binmode info; my $gene_name = "";
	if(($n = read info, $gene_name, 8)!=8) {
		if($n == 0) {last;}
		else { die "Scores file gene name not in required format\n";}
	} else {
		$gene = $cipher->decrypt($gene_name); #decrypt the second column
	}
	my $sep = "";
	if(($n = read info, $sep, 1)!=1) {
		die "No separator after $gene. Cannot map\n"; }
	if($sep ne "	") {	
		die "No proper separator after $gene. Cannot map\n"; }

	my $s = "";my $i = 0;@gene_name = "";
	while(($n = read info, $s, 1)!=0) {
		if($s ne "\n") {
			$gene_name[$i++] = $s;
		} else { last;}
	}
	if($n == 0) {
		die "No proper separator after $gene_name. Cannot map\n"; }
	print scores "uc0$gene\t".join('',@gene_name)."\n";  #decrypts the inputted file.
}

close info;
close key;
close scores;



