#!/usr/bin/perl
#Rajan Banerjee
#reb2143
#This perl script reads in a password from a user and performs MD5 hexes to hash the password.
#That hash is then bitwise XOR'ed to the hashes of the current date, time, and a random number.
#The result is saved to a file.

use Digest::MD5 qw(md5_hex);

if(@ARGV<1){ die "not enough arguments have been passed\n";} #checks that user gave an input file

my $localtime = localtime;		
my @localtime =  split(/\s/,$localtime);
my $date = "$localtime[1]" . ' ' . "$localtime[2]" . ' '."$localtime[4]"; #creates a string for the date as in mmm dd yyyy
my $user = $ARGV[0];  #takes the user's name, so that can add a check if needed
my $pw = $ARGV[1];	#takes pw from command line args to generate key

#generates md5_hex hashes of the password, current time, the date, and a random number

my $passHash = md5_hex($pw);  
my $dateHash = md5_hex($date);
my $timeHash = md5_hex($localtime[3]);
my $randHash = md5_hex(rand);

#performs a bitwise XOR on the hashes and prints them to a file.

my $keyPart1 = ((($passHass^$dateHash)^$timeHash)^$randHash);
open OUT1, ">", "$ARGV[0]_KeyPart1" or die "Can't open $ARGV[2]\n"; 
$keyPart1 =~ s#/#//#;
print OUT1 "$keyPart1";
close OUT1;
