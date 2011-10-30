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
my $MERGE="$CURR_DIR/mergeVtFiles.pl";
my $ASSOC="$CURR_DIR/runAssociation.pl";
my $MAX_USERS = 2;

my $programOptions; 
my $flag_register; 
my $flag_assoc; 
my $flag_help;
my $username=""; 
my $password=""; 
my @src_dir; 
my $dest_dir; 
my $info=""; 
my $flag_run;
my $localhost = hostname;

my $receive_socket = new IO::Socket::INET (
                                LocalHost => $localhost,
                                LocalPort => '7090',
                                Proto => 'tcp',
                                Listen => 1,
                                Reuse => 1,
                                );
die "Could not create receive socket: $!\n" unless $receive_socket;


sub help_routine()
{
		print "\n (1) New user Registration: \n\t ./engine.PL --register --user=S --pwd=S";
		print "\n (4) Run Association Tests: \n\t ./engine.PL --assoc --src=S --dest=S [--out=S]";
		print "\n (6) Help: \n\t ./engine.PL --help\n\n";
}

if ( @ARGV > 0 ) {
	$programOptions = GetOptions (
			"register" => \$flag_register,
			"assoc" => \$flag_assoc,
			"user:s" => \$username,
			"pwd:s" => \$password,
			"src:s{2}" => \@src_dir,
			"dest:s" => \$dest_dir,
			"score:s" => \$info,
			"help|?" => \$flag_help,
			"run" => \$flag_run);
	
	if ($flag_help) {
		help_routine();}
	elsif ($flag_run)
	{
		my $user_count = 0;
		my %send_socket = ();
		my $user_file = "user_list.txt";
		my %new_sock = ();

		unlink($user_file);
		open Userfile, ">", $user_file;
		my @user_list=();my @server_list=();

		print "\n\n\n";
		print "Awaiting client registration\n\n";
		while ($user_count != $MAX_USERS)
		{
			my $new_socket = $receive_socket->accept();
			my $line = "";
			$line = readline $new_socket;
			my @ret = "";
			@ret = "3\n";
			if (defined $line) {
				chomp $line;
				my @details = split(/\t/, $line);
				if(scalar(@details) < 3) {
					die "Insufficient login details: @details\n"; }
				else {
					my $userid=$details[0];my $server=$details[2];
					if(grep {$_ eq $userid} @user_list) {
						@ret = "11\n";
					} elsif(grep {$_ eq $server} @server_list) {
						@ret = "22\n";
					} else {
						@ret = "0\n";
						$user_count++;
						push(@user_list,$userid);
						push(@server_list,$server);
						print Userfile $line."\n";
					}

					my $ssend_socket = new IO::Socket::INET (
        					                 PeerAddr => $server,
       						                 PeerPort => '7090',
       						                 Proto => 'tcp',
       					                         );
					die "Could not create socket: $!\n" unless $ssend_socket;

					foreach (@ret) {
						print $ssend_socket $_;}
					$send_socket{$userid} = $ssend_socket;
					$new_sock{$userid} = $new_socket;
				}
			} else { die "Improper line read\n"; }
			print "Client $user_count registration complete\n";
		}
		close(Userfile);

		if((scalar(@server_list) != $MAX_USERS) || (scalar(@user_list) != $MAX_USERS)) {
			die "Incorrect number of users/servers found\n"; }

		print "Client registration complete. Beginning with key generation now\n";

		my $key_success = 0;
		my $start = int(rand($MAX_USERS));
		for(my $count=0;$count<$MAX_USERS;$count++) {
			my $index = ($start+$count)% $MAX_USERS;
			my $flag = ($count == $MAX_USERS-1 ? 1: 0);
			my $client = $send_socket{$user_list[$index]};
			print $client "$flag\t$server_list[($index+$MAX_USERS-1)% $MAX_USERS]\n";
			sleep(5);
		}

		print "Key generation triggered. Waiting on clients now\n";

		my %key_status = ();
		for(my $i=0;$i<$MAX_USERS;$i++) {
			my $status = readline ($new_sock{$user_list[$i]});
			chomp $status;
			my @stat = split(/\t/, $status);
			$key_status{$stat[1]} = $stat[0];
			$key_success = $key_success + $stat[0];
		}
		if($key_success != $MAX_USERS) {
			die "Key generation failed\n"; }
		print "Key generation succeeded. Proceeding to testing\n";

		# Code here for waiting for and accepting encrypted data

		print "\nWaiting for encrypted files now\n";
		my $src_dir = "assoc_input";
		#`rm -rf $src_dir`; #UNDO
		#`mkdir -p $src_dir`; #UNDO
		chdir $src_dir or die "Cannot cd to $src_dir";
		for (my $ct = 0; $ct < 0; $ct++) {
			print "Waited $ct min\n";
			sleep(60); #UNDO
		}
		for(my $i=0;$i<$MAX_USERS;$i++) {
			my $encryp_file = "$user_list[$i]";
			my $term = readline $new_sock{$user_list[$i]};
			chomp $term;
			if($term ne "XXX") {die "XXX not received";}
			print "Starting to read from user $i now\n";
			$term = readline $new_sock{$user_list[$i]};
			chomp $term;
			print "$term bytes to read\n";
			open ENCRYP_FILE, ">$encryp_file.tar.gz" or die "Can't open: $!";
			my $n = 0;
			binmode $new_sock{$user_list[$i]};my $part = "";
			for(my $j=0;$j<$term;$j++) {
				$n = read $new_sock{$user_list[$i]}, $part, 1;
				if($n == 0) { die "Premature file exit\n"; }
				print ENCRYP_FILE $part;
			}
			close ENCRYP_FILE;

			my @unzip = ("gunzip", "$encryp_file.tar.gz");
			#if(system(@unzip) !=0) {die "@unzip failed\n";} #UNDO
			print "gunzip complete on user $i\n";
			@unzip = ("tar", "-x", "--checkpoint=100", "-f", "$encryp_file.tar");
			#if(system(@unzip) !=0) {die "@unzip failed\n";} #UNDO

			print "Encrypted files received from user $i\n";
		}
		chdir ".." or die "Cannot cd to ..";
		print "Encrypted files received. Starting merge\n";

		$dest_dir = "assoc_output";
		#`rm -rf $dest_dir`; #UNDO
		#`mkdir -p $dest_dir`; #UNDO
		my @arguments = ("perl", $MERGE,
				"-src", $src_dir,
				"-out", $dest_dir);
		#if(system(@arguments)!=0) {die "Merging failed\n";} #UNDO
		print "\n\nMerging Successful. Performing association testing now\n";

		@arguments = ("perl $ASSOC -out Scores.txt -dir $dest_dir -info $dest_dir/info.txt");
		my $qsub1 = "#!/bin/sh\n";
		my $qsub2 = "#\$ -S /bin/sh\n";
		my $qsub3 = "#\$ -cwd\n";
		my $qsubfile = "assoc.sh";

		open Qsub, ">$qsubfile" or die "Cannot open $qsubfile\n";
		`chmod 777 $qsubfile`;
		print Qsub $qsub1;
		print Qsub $qsub2;
		print Qsub $qsub3;
		print Qsub "\n";
		print Qsub @arguments;
		close Qsub;

		my @qsubcom = ("qsub", "-sync", "y", "-l", "mem=4G,time=16::", "$qsubfile");
		print(@qsubcom);
		if(system(@qsubcom)!=0) {die "Association testing failed\n";}
		print "\n\nAssociation Testing Successful.\n\n";

#		unlink("Scores.txt.tar"); 
#		unlink("Scores.txt.tar.gz");
#		my @zip = ("tar", "-cf", "Scores.txt.tar", "Scores.txt");
#		if(system(@zip)!=0) {die "@zip failed\n";}
#		@zip = ("gzip", "Scores.txt.tar");
#		if(system(@zip)!=0) {die "gzip Scores.txt.tar failed\n";}
		print "Sending score files now\n";

		for(my $i=0;$i<$MAX_USERS;$i++) {
			my $client = $send_socket{$user_list[$i]};
			my $term = "XXX\n";
			print $client $term;
			my $filesize = -s "Scores.txt";
			$filesize = $filesize."\n";
			print $client $filesize;
			open SCORE_FILE, "Scores.txt" or die "Cannot open Scores.txt";
			while (<SCORE_FILE>) {
			    	print $client $_;
			}
			close SCORE_FILE;
			print "Scores file sent to user $i\n";
		}
		print "\n\nAll scores file sent. Exiting safely\n";
	}
	else {
		help_routine();
	}
}
else {
	help_routine();
}

exit 0;

