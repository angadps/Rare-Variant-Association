#!/usr/bin/perl -w
use strict;
# use warnings;
use Getopt::Long;
use Switch;
use File::Spec;

eval 'exec /usr/bin/perl -x $0 ${1+"$@"};'
if 0;
use Cwd;
my $CURR_DIR = &Cwd::cwd();
my $MERGE="$CURR_DIR/mergeVtFiles.pl";
my $ASSOC="$CURR_DIR/runAssociation.pl";
my $DECRYPT="$CURR_DIR/decryptScores.pl";
my $MAX_USERS = 2;

my $programOptions; 
my $src_dir; 
my $dest_dir;
my $op; 
my $type;
my $info=""; 
my $key="key";

$programOptions = GetOptions (
	"src:s" => \$src_dir,
	"dest:s" => \$dest_dir,
	"op:s" => \$op,
	"type:s" => \$type,
	"score:s" => \$info);
	
my @arguments = ("perl", $MERGE,
	"-src", $src_dir,
	"-out", $dest_dir);

if($op eq 1) {
print "Merge command: @arguments\n";
system(@arguments); #{die "Merging failed\n";} #UNDO
if ($? != 0) {print "Merging failed\n";} else {
print "\n\nMerging Successful. Performing association testing now\n"; }
exit 0;
} elsif ($op eq 2) {
@arguments = ("perl", $ASSOC,
	"-out", $info,
	"-type", $type,
	"-dir", $dest_dir);

print "Assoc command: @arguments\n";
if(system(@arguments)!=0) {die "Association test failed\n";} #UNDO
print "\n\nAssociation Testing Successful.\n\n";

@arguments = ("perl",$DECRYPT,  # "/ifs/scratch/c2b2/ip_lab/sz2317/privacy/workingdir/decryptScores.pl",
		"-keyfile", $key,
		"-out", "$info.decrypted",
		"-scores", $info);
print "Decrypt command: @arguments\n";

if(system(@arguments)!=0) {die "Decryption failed\n";} #UNDO
print "\n\nDecryption Successful\n";
}

