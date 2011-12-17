#!/usr/bin/perl -w
use strict;
# use warnings;
use Getopt::Long;
use Switch;
use File::Spec;
use IO::Socket;
use Sys::Hostname;

eval 'exec /usr/bin/perl -x $0 ${1+"$@"};'
if 0;
use Cwd;
my $CURR_DIR = &Cwd::cwd();
my $REGISTER = "$CURR_DIR/decidekey1.pl";
my $GENKEY="$CURR_DIR/decidekey2.pl";
my $ENCRYPT="$CURR_DIR/encrypt.pl";
my $DECRYPT="$CURR_DIR/decryptScores.pl";
my $localhost = hostname;
my $VCF_SNP_DIR = "$CURR_DIR/../vcfCodingSnps.v1.5";
my $ANNOTATE = "./vcfCodingSnps.v1.5";

# Socket to receive data
# Port number should tally across
my $receive_socket = new IO::Socket::INET (
				LocalHost => $localhost, 
				LocalPort => '7090', 
				Proto => 'tcp', 
				Listen => 1, 
				Reuse => 1, 
				); 
die "Could not create receive socket: $!\n" unless $receive_socket;

my $programOptions; 
my $flag_run; 
my $flag_help;
my $username=""; 
my $password=""; 
my @cases=""; 
my @controls=""; 
my $output=""; 
my $key="key";
my $genelist="";
my $weightfile="";
my $gene_ref="";
my $ref="";

sub help_routine() {
		print "\nHelp Options..\n";
		print "\n (2) Run: \n\t ./engine.PL --run --user=S --pwd=S --gene_ref=S --ref=S --cases=S{,} --controls=S{,} --weight=S";
		print "\n (6) Help: \n\t ./engine.PL --help\n\n";
}

if ( @ARGV > 0 ) {
	$programOptions = GetOptions (
			"run" => \$flag_run,
			"user:s" => \$username,
			"pwd:s" => \$password,
			"cases:s{,}" => \@cases,
			"controls:s{,}" => \@controls,
			"weight:s" => \$weightfile,
			"gene_ref:s" => \$gene_ref,
			"ref:s" => \$ref,
			"keyfile:s" => \$key,
			"help|?" => \$flag_help);
	
	if ($flag_help) {
		help_routine();
	}
	elsif ($flag_run)
	{
		print "\n\n\n";
		print "Beginning Registration now..\n";
		if($username eq "" || $password eq "") {die "Username not provided\n"};

		my $len = 32;

#########################################
#					#
# Server name needs to be set here!!!	#
#					#
#########################################

# Port number should tally across

my $server_socket = new IO::Socket::INET (
				PeerAddr => 'login1.titan',
				PeerPort => '7090',
				Proto => 'tcp',
				);
die "Could not create server socket: $!\n" unless $server_socket;

		my @reg_details = ($username, "\t", $password, "\t", $localhost, "\n");
		foreach (@reg_details) {
			print $server_socket $_;}

		my $new_sock;
		my $ser_sock = $receive_socket->accept();
		my $ret = <$ser_sock>;
		chomp $ret;
		if($ret eq 11) { die "Username: $username already exists\n";}
		elsif($ret eq 22) { die "Server: $localhost already exists\n";}
		elsif($ret ne 0) { die "Registration failed for unknown error\n";}

		my $line = <$ser_sock>;
		chomp $line;
		my @keyex_details = split(/\t/, $line);
		my $FIRST = $keyex_details[0];
		my $next_host = $keyex_details[1];
		print "Registration complete. Beginning key generation now..\n";

                my @arguments = ("perl", $REGISTER, $username, $password);
                if(system(@arguments) != 0) {
			print $server_socket "0\t$localhost";
			die "Partkey generation failed\n";
		}

		my @part1 = "";
		my $partkey_file = $username."_KeyPart1";
		if( (open Mykey, "<", $partkey_file) ==0) {
			print $server_socket "0\t$localhost";
			die "Cannot open $partkey_file\n";}
		my @part2 = <Mykey>;
		close(Mykey);

		if($FIRST == 1)
		{
			my $dummy_username = "random_user";
			my $dummy_password = "random_password";
			my @arguments = ("perl", $REGISTER, $dummy_username, $dummy_password);
			if(system(@arguments) != 0) {
			print $server_socket "0\t$localhost";
			die "Partkey generation failed\n";
			}
			my $partkey_file = $dummy_username."_KeyPart1";
			if( (open Mykey, "<", $partkey_file) ==0) {
			print $server_socket "0\t$localhost";
			die "Cannot open $partkey_file\n";}
			@part1 = <Mykey>;
			close(Mykey);
		} else {
			$new_sock = $receive_socket->accept();
			my $i = 0;my $n = 0;
			binmode $new_sock;my @part = "";
			for($i=0;$i<$len;$i++){
				$n = read $new_sock, $part[$i], 1;
			}
			@part1 = join('', @part);
			print "Partkey received for initiation\n";
			my $sep = "";
			#if (((read $new_sock, $sep, 1) == 1)&&($sep eq "\n")) {
			#} else {
			#	print $server_socket "0\t$localhost";
			#	die "No proper separator before weights file\n";
			#}
			my $mylen = readline $new_sock;
			chomp $mylen;
			print "Reading $mylen bytes\n";
			if(open(Wt, ">", $weightfile)==0) {
				print $server_socket "0\t$localhost";
				die "Cannot open $weightfile\n";}
			for($i=0;$i<$mylen;$i++) {
				read $new_sock, $sep, 1;
				print Wt $sep;
			}
			close(Wt);
			print "Weights file received\n";
		}

		@arguments = ("perl", $GENKEY); # calls encrypt.pl script
		@arguments = (@arguments, @part1);
		@arguments = (@arguments, @part2);
		if(system (@arguments) != 0) {  #calls decidekey2.pl script
			print $server_socket "0\t$localhost";
			die "Key generation failed\n";
			}

		if(open(Sharekey, "<", "send_key") ==0) {
			print $server_socket "0\t$localhost";
			die "Cannot open send_key\n"; }
			my $i = 0;my $n = 0;my @send_key = "";
			binmode Sharekey; my $s = "";
			while(($n = read Sharekey, $s, 1) != 0)
				{$send_key[$i++]=$s; }
		close(Sharekey);
		sleep(1);
my $send_socket = new IO::Socket::INET (
				PeerAddr => $next_host,
				PeerPort => '7090',
				Proto => 'tcp',
				);
if(!$send_socket) {
			print $server_socket "0\t$localhost";
die "Could not create send socket: $!\n"; }
		foreach(@send_key){
			print $send_socket $_;}
		print "Partkey sent\n";
			my $flen = -s $weightfile;
			$flen.= "\n";
			print $send_socket $flen;
			if(open(Wt, "<", $weightfile) == 0) {
				print $server_socket "0\t$localhost";
				die "Cannot open weights file\n"; }
			while(<Wt>) {
				print $send_socket $_;
			}
			close(Wt);
			print "Weights file sent\n";
		if($FIRST == 1)
		{
			$new_sock = $receive_socket->accept();
			my $sep = "";
			#if (((read $new_sock, $sep, 1) == 1)&&($sep eq "\n")) {
			#} else {
			#	print $server_socket "0\t$localhost";
			#	die "No proper separator before weights file\n";
			#}
			my $mylen = readline $new_sock;
			chomp $mylen;
			print "Reading $mylen bytes\n";
			for($i=0;$i<$mylen;$i++) {
				read $new_sock, $sep, 1;
			}
			print "Weights file received\n";
		}
		my @final_key = "";$i=0;
			binmode $new_sock;my @part = "";
			for($i=0;$i<$len;$i++){
				$n = read $new_sock, $part[$i], 1;
			}
				@final_key = join('', @part);
			print "Final key received\n";

		if(open(Final, ">", $key) == 0) {
			print $server_socket "0\t$localhost";
			die "Cannot open file key to write final key into\n"; }
		print Final @final_key;
		close(Final);
		foreach(@final_key){
			print $send_socket $_;}

		print $server_socket "1\t$localhost\n";

		if($FIRST == 1) {
			my $part = "";
			read $new_sock, $part, $len;
		}

		print "Key generation complete. Proceeding to annotation\n";

		my $temp_file = "temp_gene_list_$username";
		unlink($temp_file);

		my @ANNOT_CASE = (1 .. scalar(@cases)-1);
		my @CASE_GENE_LIST = (1 .. scalar(@cases)-1);
	for(my $cai=1;$cai<scalar(@cases);$cai++) {
		#my @annot = ("qsub -sync y -l mem=8G,time=1:: ./example_run.sh");
		$ANNOT_CASE[$cai-1] = $cases[$cai]."case.vcf";
		$CASE_GENE_LIST[$cai-1] = $gene_ref.".case".$cai;
		print "\nBeginning annotation for $cases[$cai]. It may be a while so please be patient\n";
		my @annot = ($ANNOTATE, "-s", $cases[$cai], "-g", $gene_ref, "-r", $ref, "-o", $ANNOT_CASE[$cai-1], "-l", $CASE_GENE_LIST[$cai-1]);
		print(@annot);
		system(@annot) or die "Annot case failed\n"; #UNDO
		`cat $CASE_GENE_LIST[$cai-1] >> $temp_file`;
		print "\n\nAnnotation complete for $cases[$cai]\n";
	}
		my @ANNOT_CONTROL = (1 .. scalar(@controls)-1);
		my @CONTROL_GENE_LIST = (1 .. scalar(@controls)-1);
	for(my $coi=1;$coi<scalar(@controls);$coi++) {
		$ANNOT_CONTROL[$coi-1] = $controls[$coi]."control.vcf";
		$CONTROL_GENE_LIST[$coi-1] = $gene_ref.".control".$coi;
		print "\nBeginning annotation for $controls[$coi]. It may be a while so please be patient\n";
		my @annot = ($ANNOTATE, "-s", $controls[$coi], "-g", $gene_ref, "-r", $ref, "-o", $ANNOT_CONTROL[$coi-1], "-l", $CONTROL_GENE_LIST[$coi-1]);
		system(@annot) or die "Annot control failed\n"; #UNDO
		`cat $CONTROL_GENE_LIST[$coi-1] >> $temp_file`;
		print "\n\nAnnotation complete for $controls[$coi]\n";
	}
		$genelist = "genelist_$username.txt";
		`grep "ucsc_name" $temp_file | sort -u > $genelist`; #UNDO
		`grep -v "ucsc_name" $temp_file | sort -u >> $genelist`; #UNDO
		unlink($temp_file);

		##### Submit annotated files for encryption, public key, username, genelist (same as that used in annotation) and weights files MUST be provided.
		print "Beginning encryption of data now\n";
		$output = $username."_out";
		@arguments = ("perl", $ENCRYPT); # calls encrypt.pl script
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
		if ($genelist eq "") {die "genelist not provided\n";}
                   else     { @arguments = (@arguments, "-genelist", $genelist);}
 		if ($weightfile eq "") {die "weightfile not provided\n";}
                      else  { @arguments = (@arguments, "-weight", $weightfile);}
print "Encryption command: @arguments\n";
		if (system(@arguments) != 0) { die "Encryption failed\n"; } #UNDO
		print "\n\nEncryption Successful. Sending data to server for association testing.\n";

		unlink("$username.tar");
		my @zip = ("tar", "-c", "--checkpoint=1000", "-f", "$username.tar", $output);
		if(system(@zip)!=0){die "@zip failed\n";} #UNDO
		print "File tar complete\n";
		unlink("$username.tar.gz");
		@zip = ("gzip", "$username.tar");
		if(system(@zip)!=0){die "@zip failed\n";} #UNDO
		print "File zip complete\n";

		my $term = "XXX\n";
		print $server_socket $term;
		print "Initiated transfer\n";
		my $filesize = -s "$username.tar.gz";
		$filesize = $filesize."\n";
		print $server_socket $filesize;
		print "Sending $filesize bytes\n";
		open ZIP_FILE, "$username.tar.gz";
		while (<ZIP_FILE>) {
		    print $server_socket $_;
		}
		close ZIP_FILE;
		print "Data sent. Waiting for Scores file!\n";

		for (my $ct = 0; $ct < 40; $ct++) {
			print "Waited $ct min\n";
			sleep(60); #UNDO
		}
		my $part = "";
		$n = read $ser_sock, $term, 4;
		chomp $term;
		if($term ne "XXX") {die "XXX not received";}
		$n = read $ser_sock, $term, 4;
		chomp $term;

		my $score_file = "Score_$username.txt";
		unlink($score_file);
		open SCORE_FILE, ">", $score_file or die "Can't open: $!";
		$n = 0;
		binmode $ser_sock;$part = "";
		for(my $j=0;$j<$term;$j++) {
			$n = read $ser_sock, $part, 1;
			if($n == 0) { die "Premature file exit\n"; }
			print SCORE_FILE $part;
		}

		close SCORE_FILE;
		print "Scores file received. Decrypting...\n";

		@arguments = ("perl",$DECRYPT,  
				"-keyfile", $key,
				"-out", "Scores.txt",
				"-scores", $score_file);
		`@arguments`;
		print "\n\nDecryption Successful\n";
	}
	else {
		help_routine();
	}
}
else {
		help_routine();
}

exit 0;

