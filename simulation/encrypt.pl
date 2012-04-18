#!/usr/bin/perl -w

## Requires installing the modules Crypt and its supporting modules and adding to the path.

use lib "/ifs/scratch/c2b2/ip_lab/aps2157/privacy/Crypt-CBC-2.22/lib/";
use lib "/ifs/scratch/c2b2/ip_lab/aps2157/privacy/Crypt-CBC-2.22/lib/perl5/site_perl";
use lib "/ifs/scratch/c2b2/ip_lab/aps2157/privacy/Crypt-CBC-2.22/lib/perl5/site_perl/5.8.8";
use Crypt::DES;
use Crypt::CBC;
use Crypt::CFB;
use Getopt::Long;
use Switch;
use POSIX qw/floor/;


## Other assumptions ->
# Input vcf files are annotated using vcfCodingSNPSv1.5 .
# All input vcf files have been validated, for e.g. using vcf-tools-validate
# Control files give Phenotype = -1 & Case files give Phenotype = 1
# Requires the genelist used for annotating the vcf files as input
# Requires a weights files, containing function category for annotation with their weights.
#
# VCF input : assumption that a line in VCF file has  9 fixed  fields i.e. chro, pos, ....  info, format.
#

{ package DATA;

	my $format="##fileformat=VCFv4.0\n";
	my $InfoField1 = "##FORMAT=<ID=GT,Number=1,Type=String,Description=\"Genotype\">\n";
	my $InfoField2 = "##INFO=<ID=.,Number=.,Type=Float,Description=\"Weight of functional category of annotation\">\n";
	my $num_fields=9;		# The number is actually 8, but we use 9 because of perl array numbering conventions
	my $gene_out_file="GeneInfo.txt";
	my $phenotype_file="Pheno.txt";
	my $num_dirs=10;

	my %chr_map = ("1" => 1, "2" => 2, "3" => 3, "4" => 4, "5" => 5, "6" => 6, "7" => 7, "8" => 8, "9" => 9, "10"=> 10, "11" => 11, "12" => 12, "13" => 13, "14" => 14, "15" => 15, "16" => 16, "17" => 17, "18" => 18, "19" => 19, "20" => 20, "21" => 21, "22" => 22, "23" => 23, "X" => 23, "Y" => 24, "M" => 25, "chr1" => 1, "chr2" => 2, "chr3" => 3, "chr4" => 4, "chr5" => 5, "chr6" => 6, "chr7" => 7, "chr8" => 8, "chr9" => 9, "chr10"=> 10, "chr11" => 11, "chr12" => 12, "chr13" => 13, "chr14" => 14, "chr15" => 15, "chr16" => 16, "chr17" => 17, "chr18" => 18, "chr19" => 19, "chr20" => 20, "chr21" => 21, "chr22" => 22, "chr23" => 23, "chrX" => 23, "chrY" => 24, "chrM" => 25);
	my $chr_max_len=1000000000;	# 1G or maximum possible length of any chromosome.

	my @input_file=(); 		# array of hashes {NAME, HANDLE, PHENOTYPE, Flag_read, @line, #IDstart, #IDend}
	my $output_dir="";		# Input parameter
	my $user;			# Reference pointing to structure 'user' containing user's information, key and cipher - Input parameter
	my $master_gene;		# Reference pointing to structure 'gene' containing list of genes, functional weights - Input parameter
	my %current_gene_pool=();	# a pool which maintains list of genes currently having open file handles. Once a gene is completely analysed,
					# its file handle is closed and removed from this hash
	my @gene_table=();		# This one for the VT files
	my @geneCount=((0)x$num_dirs);	# a counter of total number of genes encountered, aids in naming new vcf files as GeneXXX.vcf
	my @IDs=();			# Array of Individuals IDs filled while reading headers of all input vcf files
	my %IDhash=();			# Hash with key=> Individual ID, Value=> Phenotype 
	my @header=();			# Common header to be printed to new vcf files.
	my %od_table=();
	my $od_count = 0;
	my $chr_count = 0;


sub new {       	#subroutine to create new object. Paramters set are 'user' reference and 'gene' reference
	my $self = shift;
	$user=shift;
	$master_gene=shift;
	$output_dir=shift;
	$output_dir=~s/\/$//;
	if (! -d $output_dir) { mkdir $output_dir, 0777;}
	else { `rm -rf $output_dir/*`;} #UNDO
	if (! -d $output_dir."/VT") {mkdir $output_dir."/VT", 0777;}  #creates a new, numbered directory for each gene
	bless {}
}

sub open_input_files	#subroutine to open all input files and store file handles and other info in an array of hashes indexed by input-file name '@input-file'.
{
        my $self = shift;
	my(@case_files) = @{$_[0]};
        my(@control_files) = @{$_[1]};
        my $count=0;
	my $file;
        if($#case_files > -1) { #signals a case file
        	foreach $file (@case_files[0..$#case_files]) {
                	if($file =~ m/vcf/){
                		open("FH$count", "<", "$file") or die "Can't open case file $file\n";
        			my $fmtline = readline "FH$count";
				if($fmtline ne $format) {die "VCF file $file not in VCF 4.0 format\n";}
                		push @input_file, {NAME=> $file, HANDLE=> "FH$count", PHENO=> 1};
                		$count++;
                	}
        	}
	}
        if($#control_files > -1) { #signals a control file
        	foreach $file (@control_files[0..$#control_files]) {
                	if($file =~ m/vcf/){
                		open("FH$count", "<", "$file") or  die "Can't open control file $file\n";
        			my $fmtline = readline "FH$count";
				if($fmtline ne $format) {die "VCF file $file not in VCF 4.0 format\n";}
                		push @input_file, {NAME=> $file, HANDLE=> "FH$count", PHENO=> -1};
                		$count++;
                	}
        	}
	}
        return ($count);
}

sub close_input_files
{
	foreach $file (@input_file) {
		close($file->{HANDLE});
	}
}

sub code
{
	my $self = shift;
	my $raw = shift;
	my $typ = shift;
	my $append = shift;
	my $ret = "";

if($typ == 2) {
	if(exists($od_table{$raw})) {
		$ret = $od_table{$raw};
	} else {
		$od_count++;
		$od_table{$raw} = $od_count;
		$ret = $od_count;
	}
} elsif($typ == 1) {
	if(exists($od_chr{$raw})) {
		$ret = $od_chr{$raw};
	} else {
		$chr_count++;
		$od_chr{$raw} = $chr_count;
		$ret = $chr_count;
	}
}
	return $ret.$append;
}

sub LHSinfo($) {  	# extract the LHS of a function-gene tuple from info field, i.e. - functional name
        my $self = shift;
	my @temp = split (/=/, $_[0]);
	return ($temp[0]);
}#end-LHSinfo

sub RHSinfo($) {   	# extract the RHS of a function-gene tuple from info field. i.e. - gene name
        my $self = shift;
        my @temp = split (/=/, $_[0]);
        if (scalar(@temp) < 2) {
		return ("");
	}
	else {
		$temp[1] =~ m/(\(.*\))/;
		my $geneName = substr($1, 1, (length($1)-2));
		return ($geneName);		
	}
}#end-RHSinfo

sub get_genotype($){ 		#subroutine - extracts genotype from the Individual's data fields of a vcf file. Genotypes are assigned as follows; 0|0 - 0, 1|1 - 2, anything else - 1.
        my $self = shift;
	my $item = $_[0];
	if($item =~ /0(\||\/)0/)		#Assumes GT format in vcf file is 0|0
		{ return '0';}
	elsif($item =~ /\.(\||\/)\./)
		{ return '0';}
	elsif($item =~ /1(\||\/)1/)		#Assumer GT format in vcf file is 1|1
		{ return '2';}
	else 				#Any other GT is genotyped with "1" for e.g. ./. or 0|1
		{return '1';}
}#end-get_genotype

#subroutine to extract all Individual IDs, modify them, and store in corresponding data structures with relevant information like Phenotype.
sub extractIndividualsIDs{
        my $self = shift;
	my $param1=shift;
	my @parts = split(/\t/, $param1);
	my $aFile= shift;
	my $phenotype = $aFile->{PHENO}; #my $phenotype = $_[2];
	my $phenostring = $phenotype == -1 ? "control" : "case";

	$aFile->{ID_START}= scalar( @IDs);
	my $mark = 0;
	my $partnum = scalar(@parts);
  	if($partnum > $num_fields){ #if there is at least one individual in the file
               	for($i = $num_fields;$i<$partnum;$i++){
			$index_string = $user->{USERNAME}.'_'.$phenostring.'_'.$parts[$i];
			if(!exists($IDhash{$index_string})){ #if the id hasn't been seen before and isn't blank
                        	$IDhash{$index_string} = $phenotype;
                                push(@IDs, $index_string); #add the id to the array
                                $mark=1;
                        } else { die "VCF file seems inconsistent. Unique ID expected\n"; }
                } #end for
                if($mark==1) {chomp($IDs[(scalar(@IDs)-1)])};   #removes the end line char from the last ID if taken from file input.
        }
        $aFile->{ID_END}= scalar(@IDs);
}#end-sub-extractIndividualsIDs

#subroutine to read the headers of all files, calls subroutine extractIndividualsIDs() for extracting IDs of individuals from the headers.
sub read_all_headers {
        my $self = shift;
        push (@header, $format);
	push (@header, $InfoField1 );
	push (@header, $InfoField2 );

	foreach $aFile(@input_file){
		while ($line = readline $aFile->{HANDLE}) {
	        	if ($line =~ m/^##/)    # if line begins with a hash it is header
		                { next;	}
		        elsif  ($line =~ m/^#CHROM/)       {
				chomp $line;
				$self->extractIndividualsIDs($line,$aFile);
        			$aFile->{FLAG_READ}= 1;			#0=don't read, 1=allow read, 2=EOD reached, don't read
				if ($header[(scalar(@header))-1]  =~ m/^#CHROM/){}
				else{
					my @items= split(/\t/,$line);
					push (@header, join("\t", @items[0..$num_fields-1]));
				}
				last;
			}
		}
	}
	$header[(scalar(@header))-1].="\t";
	$header[(scalar(@header))-1].= (join("\t", @IDs)."\n");
}#end-sub-read_all_headers

sub create_gene_file{ 		#subroutine to create a gene file called "geneXXX" where XXX is the current gene count. Its put in appropriate directory heirachy to incorporate tens of thousands of genes. Directory root is user-inputted $output_dir
        my $self = shift;
	my $name_key=shift;
	my $random_number = int(rand($num_dirs));

        my $path=$output_dir."/GENES";
	#if (! -d $path) { mkdir $path, 0777;}
	$path.="/DIR_$random_number"; 
	#if (! -d $path) { mkdir $path, 0777;}
	$path.="/GENE".$geneCount[$random_number].".vcf";
        #open("FH_$name_key", ">>", $path) or die "Cannot create gene file for $name_key called $path"; #UNDO
	#select((select("FH_$name_key"), $|=1)[0]); #UNDO
	$current_gene_pool{$name_key} = [$path];

	#TODO add in the @header a line for info
	#foreach $line(@header){			# print common header to all output geneXXX.vcf files #UNDO
	#	print {"FH_$name_key"} $line; #UNDO
	#} #UNDO
	#close "FH_$name_key"; # Experimental #UNDO
	$geneCount[$random_number]++;
}#end-sub-create_gene_file

sub empty_gene_pool{ 		#subroutine to close a geneXXX.vcf file, print the gene file's path in a common GeneInfo.txt file, and finally empty the current gene pool
        my $self = shift;
	open FH_info, ">".$output_dir."/".$gene_out_file or die "Cannot open file $output_dir/$gene_out_file";
	select((select(FH_info), $|=1)[0]);
	for $name_key ( keys %current_gene_pool ) {
		if (substr($name_key, 0, 3) ne "uc0") { die "gene name not in ucsc format\n";}
		my $gene_name = substr($name_key, 3);
		print FH_info  $user->{CIPHER}->encrypt($gene_name)."\t".$current_gene_pool{$name_key}[0]."\n";   #Encrypted
		#print FH_info  $gene_name."\t".$current_gene_pool{$name_key}[0]."\n";
	}
	close FH_info;
	for (keys %current_gene_pool){		  # completely empty %current_gene_pool
        	delete $current_gene_pool{$_};
	}	
}#end-sub-empty_gene_pool

sub trim($)
{
	my $self = shift;
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub gen_pos_cipher {
	my $self = shift;
	my $pos = shift;

	my $ps = pack( 'I', $pos );
	$user->{POSCIPHER}->reset;
	my $ciphertext = $user->{POSCIPHER}->encrypt($ps);
	return $self->trim(unpack('I', $ciphertext));
}

sub  append_gene_file{  	#subroutine to print to an output geneXXX.vcf file. 
        my $self = shift;
	my $buffer = shift;

	for (keys %$buffer) {
        open($temp_handle, ">>", $current_gene_pool{$_}[0]) or die "Cannot open handle to append";
	select((select($temp_handle), $|=1)[0]);
		my @arr = @{$buffer->{$_}};
		#my $string = $self->code($arr[0],1,"\t"); #Encoded
		my $string = $arr[0]."\t";
                #$string.= $self->code($arr[1]-$master_gene->{GENE_HASH}->{$_} + 1,2,"\t"); #Encoded
                $string.= $self->gen_pos_cipher($arr[1] - $master_gene->{GENE_HASH}->{$_} + 1)."\t";
		$string.= ".\t"; # Encrypted
	 	$string .= join ("\t", @arr[3.. 8]);
		for (my $it=9; $it < scalar(@arr); $it++) {
			if ($arr[$it] == 3) {
	 			$string .= "\t0";
			} else {
				$string .= "\t" .$arr[$it];
			}
		}
	 	$string.="\n";
		print  {$temp_handle} $string;
		close $temp_handle; # Experimental
	}
}#end-sub-append_gene_file

sub append_VT_file {
	my $self = shift;
	my $buf = shift;

	for (keys %$buf) {
		my $gene = $_;
		my @arr = @{$buf->{$_}};
		my $snp = $arr[0].':'.($arr[1] - $master_gene->{GENE_HASH}->{$_} + 1);
		my $wt = $arr[7];
		if(!exists($gene_table{$gene}{$snp}->{WEIGHT})) {
			$gene_table{$gene}{$snp}->{WEIGHT} = $wt;
		} else {
			if($wt > $gene_table{$gene}{$snp}->{WEIGHT}) {
				$gene_table{$gene}{$snp}->{WEIGHT} = $wt;
			}
		}
		my @IDlist = @arr[9.. ((scalar @arr )-1) ];
		for(my $i=0;$i<(scalar(@IDlist));$i++){
			$gene_table{$gene}{$snp}{$IDs[$i]} = $IDlist[$i];
		} #end for
	}
}

sub extract_ID_data{ 	#subroutine to extract all the data of individuals from a line from an input VCF file. 
        my $self = shift;
	my @line = @_;

	my @IDdata=(("") x ((scalar @line)-$num_fields));
	for ($ind = $num_fields; $ind < (scalar @line); $ind++) {
        	@IDdata [($ind - $num_fields)] = $self->get_genotype( $line[$ind] );
	}
	return (@IDdata);
}#end-extract_ID_data

sub update_op_buffer{ 	#arguments - $object_ref (discarded), $op_buffer, $afile
        my $self = shift;
	my $buffer_ref = shift;
	my $aFile=shift;
	if ($aFile->{FLAG_READ} == 0){
	        my $the_chr=shift;
	        my $the_pos=shift;
		if ( (@{$aFile->{LINE}}[0] eq $the_chr ) &&  ( @{$aFile->{LINE}}[1] == $the_pos )){
			my (@IDdata) = $self->extract_ID_data(@{$aFile->{LINE}});
			for (keys %$buffer_ref){
				@{$buffer_ref->{$_}}[ ($num_fields+$aFile->{ID_START}) .. ($num_fields+ $aFile->{ID_END} -1) ] = @IDdata;
			}
			return 1;
		}
	}
	return 0;
}#end-update_OP_buffer


#subroutine to extract all information from a line from an input vcf file. Extracted things are chromose, position, functional annotaion + gene name and genotype data for all individuals.
sub extractInfo {		#arguments - $object_ref (discarded), $file handle

	my $self =  shift;
	my $aFile=shift;
	my @line = @{$aFile->{LINE}}; 
	my @info = split(/;/, $line[7]);
	my $output_buffer={};
	my @buff;

	my (@IDdata) = $self->extract_ID_data(@line);


	foreach $info_item (@info){
		my $functionName = $self->LHSinfo($info_item);
	if (exists $master_gene->{WEIGHTS}->{$functionName}) {
	  my ($theGene) =  $self->RHSinfo($info_item);
	    if (($theGene ne "") && (exists $master_gene->{GENE_HASH}->{$theGene})){
		if (! exists $current_gene_pool{$theGene}){
			$self->create_gene_file($theGene); #UNDO
		}
		if (! exists $output_buffer->{$theGene}){
	                @buff = ((0) x ($num_fields+scalar(@IDs)));
			@buff[0 .. 6] = @line[0 .. 6];
			$buff[7] = $master_gene->{WEIGHTS}->{$functionName};
			$buff[8] = "GT";
			@buff[ ($num_fields + $aFile->{ID_START}) .. ($num_fields + $aFile->{ID_END} -1) ] = @IDdata;
			$output_buffer->{$theGene} = ();
			@{$output_buffer->{$theGene}} = @buff;
			undef @buff;
		}
		# REVISIT:
		# Here I seem to be overriding with the SNP type that has maximum weight instead of collating it. Do I need to do this for update_op_buffer as well?
		else {
	                if($output_buffer->{$theGene}[7] < $master_gene->{WEIGHTS}->{$functionName} ) {
	                        $output_buffer->{$theGene}[7] = $master_gene->{WEIGHTS}->{$functionName};
	             	}
 		}
            }
	}
 }
 return ($output_buffer);
}#end-extractInfo

sub find_next_SNP{  		#subroutine - from all the open files handles (input vcf files), this subroutine decides which file will have the next line processed. All input files are processed in the order of increasing SNP positions. The file which is decided to be processed next will have its FLAG_READ flag set to 1, to indicate that a file read is to be done afterwards.
        my $self = shift;
	my $min_chr = "M";
        my $min_pos=$chr_max_len;
	my $minFile={};

        foreach $aFile(@input_file){
                if ($aFile->{FLAG_READ} != 2){
                        if ($chr_map{@{$aFile->{LINE}}[0]} < $chr_map{$min_chr} ) {
                                $minFile=$aFile;
                                $min_chr= @{$aFile->{LINE}}[0];
                                $min_pos= @{$aFile->{LINE}}[1];
 			}
			elsif (( $chr_map{@{$aFile->{LINE}}[0]} == $chr_map{$min_chr} ) && ( @{$aFile->{LINE}}[1] < $min_pos)) {
                                $minFile=$aFile;
                                $min_chr= @{$aFile->{LINE}}[0];
                                $min_pos= @{$aFile->{LINE}}[1];
                        }
                }
        }
        if (defined $minFile) {
                foreach $aFile(@input_file){
                        if ( ($aFile->{FLAG_READ} != 2) && ($aFile ne $minFile) ){
                                $aFile->{FLAG_READ} = 0;
                        }
                }
	        $minFile->{FLAG_READ}=1;
        }
	return $minFile;
}#end-find_next_SNP


sub read_VCF_line{	#this sub performs a readline operation on those input vcf files which have their FLAG_READ set to 1. This is because only those files had been selected for processing. Once a readline operation cannot be done because of EOF the FLAG_READ is set to 2. If atleast one file has been read subroutine returns 1 (true) else 0 (false). 0 means no more files have any lines left to be read.
        my $self = shift;
	my $flag=0;
	foreach $aFile(@input_file){
		if ($aFile->{FLAG_READ} == 1){		#read a line if it was marked for reading i.e. FLAG_READ =1
			my $line = readline $aFile->{HANDLE};
			if (defined $line) {
				chomp $line;
			        @{$aFile->{LINE}} = split(/\t/, $line);
				$flag=1;
			}
			else {
				$aFile->{FLAG_READ} = 2;		#if EOF is reached
			}
		}
	}
	return $flag;
}#end-sub-read_VCF_line

sub shatterVCF{		#main function which reads all input vcf files, extracts data in increasing order of SNPs and outputs all encrypted information gene-wise, in files named as geneXXX.vcf .

        my $self = shift;
	my $curr_chr="0"; my $curr_pos="0";
	my $OPbuffer={};	

	$self->read_all_headers();

	my $isContinue = $self->read_VCF_line();	#reads a new line from any file whose FLAG_READ  is set to 1.

	while ($isContinue == 1){
		my $aFile = $self->find_next_SNP();	#gets the VCF file handle which has the next closest SNP.
		if (! defined $aFile) { last;}

		my $this_chr = @{$aFile->{LINE}}[0];
		my $this_pos = @{$aFile->{LINE}}[1];

		if ((scalar keys %current_gene_pool)==0) { # if gene_pool is empty
			$curr_chr= $this_chr ;
		}
		elsif ($curr_chr ne $this_chr){ # check for new chromosome, if so close all open geneXXX.vcf file handles in current gene pool
			print "\nEncryption of $curr_chr complete\n";
			$curr_chr= $this_chr ;
		}
		($OPbuffer)= $self->extractInfo($aFile);

		foreach $otherFile(@input_file)  {
			my $isUpdate = $self->update_op_buffer($OPbuffer, $otherFile, $this_chr, $this_pos);	#from remaining files.. i.e. if any chr& pos overlap with this. Check for FLAG_READ=0 done in callee function.
#REVISIT: move FLAG_READ=1 to update_op_buffer itself
			if ($isUpdate) {
				$otherFile->{FLAG_READ} = 1;
			}
		}

		#$self->append_gene_file($OPbuffer); #UNDO
		$self->append_VT_file($OPbuffer);

		for (keys %$OPbuffer){            # empty the buffer after printing to files.
                	delete $OPbuffer->{$_};
	        }

		$isContinue = $self->read_VCF_line();	#reads a new line from all those files whose flag is set.
		foreach $missedFile(@input_file) {
			if($missedFile->{FLAG_READ}==0) {
				$isContinue = 1;
			}
		}
	}
	$self->empty_gene_pool(); #UNDO
}#end-sub-shatterVCF

sub write_pheno_file{		#prints the phenotypes of all individuals from all input vcf files, into a common Pheno.txt file
        my $self = shift;
	open FH_id, ">".$output_dir."/".$phenotype_file or die "Cannot create $output_dir/$phenotype_file\n";
	select((select(FH_id), $|=1)[0]);
	for $id ( keys %IDhash ) {
		print FH_id $id. "\t". $IDhash{$id}. "\n";   		# prints Individual ID (not encrypted) & phenotype  for testing
        }
        close FH_id;
        for (keys %IDhash){      
                delete $IDhash{$_};
        }
}#end-write_pheno_file

sub write_VT_files {
	my $self = shift;
	my $complete = 0;
	my $curr = 0;
	my $cycle = 1000;
	my @gect = ((0) x (3*$num_dirs));

	for(my $rdir=0;$rdir<3*$num_dirs;$rdir++) {
		system("mkdir -p $output_dir/VT/DIR_$rdir");
	}
	open Info, ">", "$output_dir"."/info.txt" or die "Can't open file info\n";
	select((select(Info), $|=1)[0]);
	for $gene ( keys %gene_table) {
		my $random_number = int(rand(3*$num_dirs));
		my $gdir = "VT/DIR_$random_number";#/gene$gect[$random_number]";
		my $cdir = $output_dir."/".$gdir;

		open Phenotypes, ">", "$cdir/gene$gect[$random_number].data.pheno" or die "Cannot create phenotype file: $cdir/gene$gect[$random_number].data.pheno\n";
		open Genotypes, ">", "$cdir/gene$gect[$random_number].data.geno" or die "Cannot create genotype file: $cdir/gene$gect[$random_number].data.geno\n";
		open Weights, ">", "$cdir/gene$gect[$random_number].data.wt" or die "Cannot create weight file: $cdir/gene$gect[$random_number].data.wt\n";
	select((select(Phenotypes), $|=1)[0]);
	select((select(Genotypes), $|=1)[0]);
	select((select(Weights), $|=1)[0]);

		if (substr($gene, 0, 3) ne "uc0") { die "gene name not in ucsc format\n";}
		my $gene_name = substr($gene, 3);
		print Info $user->{CIPHER}->encrypt($gene_name)."\t$gdir/gene$gect[$random_number]\n"; #Encrypted

		my %ID;
		foreach $snps (keys %{$gene_table{$gene}}) {
			$snps =~s/\t/\\t/;
			$snps =~s/\n/\\n/;
			@snp = split(/:/,$snps);

			my $wt = $snp[0].":";
			$wt.= $self->gen_pos_cipher($snp[1])."\t";
			$wt.= $gene_table{$gene}{$snps}->{WEIGHT};
			print Weights $wt."\n";

			foreach $ind (keys %{$gene_table{$gene}{$snps}}) {
	                	if($ind eq "WEIGHT") { next;}
	                	my $patient = $ind;
				my $geno = $gene_table{$gene}{$snps}->{$ind};
        	        	$patient =~s/\t/\\t/;
                		$patient =~s/\n/\\n/;

				my $gt = $snp[0].":";
				$gt.= $self->gen_pos_cipher($snp[1])."\t";
	                	print Genotypes "$patient\t$gt$geno\n";
	                	if(!exists($ID{$patient})){

	                		if($patient=~/control/){
        	        			print Phenotypes "$patient\t1\n";
                			} elsif($patient=~/case/) {
                				print Phenotypes "$patient\t-1\n";
                			}
                        		$ID{$patient}=1;
                		}
			} #ind
		}

		close Weights;
		close Phenotypes;
		close Genotypes;

		$complete = 0;
		$gect[$random_number]++;
		$complete += $_ for @gect;
		if($complete > $curr) {
			print "$complete VT files written\n";
			$curr += $cycle;
		}
	}
	close Info;
}

} #Package close


package main;

my $options={INITIALIZE => sub {
	my $self= shift;
	my $programOptions = GetOptions (
                        "case=s{,}" => \@{$self->{CASE}},
                        "control=s{,}" => \@{$self->{CONTROL}},
                        "weight=s" => \$self->{WEIGHT_FILE},
                        "genelist=s" => \$self->{GENE_FILE},
                        "user=s" => \$self->{USERNAME},
                        "keyfile=s" => \$self->{KEY_FILE},
                        "out=s" => \$self->{OUTPUT_DIR},
                        "help|?" => \$self->{FLAG_HELP});
        }};

my $user={
	GENERATE_CIPHER => sub {
		my $self=shift; $self->{KEY_FILE}=shift;
	        my $key;

	        open keyFH, "<".$self->{KEY_FILE} or die "Can't open key file\n";
        	read(keyFH, $key, 8);
	        $self->{CIPHER} = Crypt::CBC->new(-key         => "$key",
                                'regenerate_key'  => 0,
                                -iv => "$key",
                                'prepend_iv' => 0 ); #generates the cipher
	        close keyFH;
	},
	POSITION_CIPHER => sub {
		my $self=shift; $self->{KEY_FILE}=shift;
	        my $key;

	        open keyFH, "<".$self->{KEY_FILE} or die "Can't open key file\n";
        	read(keyFH, $key, 8);
		$self->{POSCIPHER} = new Crypt::CFB $key, 'Crypt::DES';
	        close keyFH;
	}};
	
my $gene={
	INITIALIZE => sub {
		my $self=shift;
		$self->{WEIGHT_FILE}= shift;
		$self->{GENE_FILE}=shift;
		$self->{WEIGHTS} = {};
		$self->{GENE_HASH} = {};
		},

	INIT_WEIGHTS => sub {
		my $self=shift;
        	open funcFH, "<".$self->{WEIGHT_FILE} or die "Can't open functional weights file\n";
	        while (<funcFH>){
	                chomp; my @temp = split(/\t/, $_);
			$self->{WEIGHTS}->{$temp[0]} = $temp[1];
	        }
        	close funcFH;
		#if ((scalar keys %$self->{WEIGHTS}) == 0 ) { die "Weights file is not valid\n";}
		},
	READ_GENE_FILE => sub {
                my $self=shift;
		open geneFH, "<". $self->{GENE_FILE} or die "Can't open gene_list file\n";

		my $temp = <geneFH>; chomp($temp); my @line = split(/\t/, $temp);
		my $indexGeneName=-1; my $indexTxstart=-1; my $i;
		for $i (0 .. $#line){
		        if ($line[$i] eq "ucsc_name") {$indexGeneName=$i; }      
			if ($line[$i] eq "genestart") {$indexTxstart=$i; }
		        #if ($line[$i] eq "#name") {$indexGeneName=$i; }      
			#if ($line[$i] eq "txStart") {$indexTxstart=$i; }
		}
		# Fill geneList with names of genes in order of appearance in the geneFile
		while (<geneFH>)  {
		        chomp;  @line = split(/\t/, $_);
		        $self->{GENE_HASH}->{$line[$indexGeneName]} = $line[$indexTxstart];
		        }
		close geneFH;
		}
};

if (@ARGV > 0 ) {
	&{$options->{INITIALIZE}}($options);

	 if ($options->{FLAG_HELP}) {print "\nHelp Options..\n";
                print "\n (1) Encrypt Data: \n\t ./encrypt.pl --user=S --keyfile=S --case=S{,} --control=S{,} -genelist=S -weight=S --out=S";
                print "\n (2) Help: \n\t ./encrypt.pl --help\n\n";
                exit;
        }

	if($options->{USERNAME}){ 
                $user->{USERNAME} = $options->{USERNAME};}
		else { die "Username must be provided. \n"; }
	if(($options->{WEIGHT_FILE} ) && ($options->{GENE_FILE} )) {
		&{$gene->{INITIALIZE}}($gene, $options->{WEIGHT_FILE}, $options->{GENE_FILE}); }
                else { die "Weights file and Gene list file must be provided. \n"; }
 
	if($options->{KEY_FILE} ne ""){ #signals the encryption key
		&{$user->{GENERATE_CIPHER}}($user, $options->{KEY_FILE});
		&{$user->{POSITION_CIPHER}}($user, $options->{KEY_FILE}); }
                else { die "An encryption key must be provided in a file. \n"; }
 
	$VCFobj= DATA->new($user, $gene, $options->{OUTPUT_DIR});
	&{$gene->{INIT_WEIGHTS}}($gene);
	&{$gene->{READ_GENE_FILE}}($gene);

	$VCFobj->open_input_files($options->{CASE},$options->{CONTROL});
	$VCFobj->shatterVCF();
	$VCFobj->write_pheno_file();
	$VCFobj->write_VT_files(); #UNDO
	$VCFobj->close_input_files();
}

exit;

