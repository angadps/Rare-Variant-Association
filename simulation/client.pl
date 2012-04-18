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
my $ANNOTATE = "./vcfCodingSnps.v1.5";
my $ENCRYPT="$CURR_DIR/encrypt.pl";

my $programOptions; 
my $username=""; 
my @cases=""; 
my @controls=""; 
my $output=""; 
my $key="key";
my $weightfile="";
my $gene_ref="";
my $ref="";

$programOptions = GetOptions (
	"user:s" => \$username,
	"cases:s{,}" => \@cases,
	"controls:s{,}" => \@controls,
	"weight:s" => \$weightfile,
	"gene_ref:s" => \$gene_ref,
	"ref:s" => \$ref,
	"out:s" => \$output);

my @ANNOT_CASE = (1 .. scalar(@cases)-1);
my @ANNOT_CONTROL = (1 .. scalar(@controls)-1);

for(my $cai=1;$cai<scalar(@cases);$cai++) {
	$ANNOT_CASE[$cai-1] = $cases[$cai]."_annotated.vcf";
}
for(my $coi=1;$coi<scalar(@controls);$coi++) {
	$ANNOT_CONTROL[$coi-1] = $controls[$coi]."_annotated.vcf";
}

	##### Submit annotated files for encryption, public key, username, genelist (same as that used in annotation) and weights files MUST be provided.
	print "Beginning encryption of data now\n";
	my @arguments = ("perl", $ENCRYPT); # calls encrypt.pl script
	if ($username eq "") {die "Username not provided\n";}
	else	{ @arguments = (@arguments, "-user", $username);}
	if ($key eq "") {die "keyfile not provided\n";}
	else	{ @arguments = (@arguments, "-keyfile", $key);}
	if (scalar(@ANNOT_CASE) eq 0) {die "case file not provided\n";}
	else	{ @arguments = (@arguments, "-case", @ANNOT_CASE);}
	if (scalar(@ANNOT_CONTROL) eq 0) {die "conrol file not provided\n";}
	else	{ @arguments = (@arguments, "-control", @ANNOT_CONTROL);}
	if ($output eq "") {die "output dir not provided\n";}
	else	{ @arguments = (@arguments, "-out", $output);}
	if ($gene_ref eq "") {die "genelist not provided\n";}
        else     { @arguments = (@arguments, "-genelist", $gene_ref);}
 	if ($weightfile eq "") {die "weightfile not provided\n";}
        else  { @arguments = (@arguments, "-weight", $weightfile);}
	print "Encryption command: @arguments\n";
	if (system(@arguments) != 0) { die "Encryption failed\n"; } #UNDO
	print "\n\nEncryption Successful. Sending data to server for association testing.\n";

