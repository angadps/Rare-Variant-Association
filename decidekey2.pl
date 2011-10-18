#!/usr/bin/perl
#Rajan Banerjee
#reb2143
#This perl script reads in two files generated from executing the first part of the DecideKey process
#Then bitwise XOR's are completed on the hashes contained in the files.

use Digest::MD5 qw(md5_hex);

if(@ARGV<2){ die "not enough arguments have been passed\n";} #checks that user gave two input file
#open(FH1, $ARGV[0]);
#open(FH2, $ARGV[1]);
open out, ">", "send_key" or die "Can't open key file!";

my $partA = $ARGV[0];
my $partB = $ARGV[1];

my $key = $partA^$partB;

#print $key;

print out "$key";
