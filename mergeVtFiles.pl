#!/usr/bin/perl
#Rajan Banerjee reb2143
#This script will take the encrypted files generated from Alice and Bob and will merge the files.
#This script will be run by Trevor

my $num_dirs=30;
my $src =""; #The directory of one person's numbered gene directories
my $output=""; #A trusted third party's directory that will contain the merged numbered gene directories
my @array=@ARGV;
my $length = scalar(@array);
$! = "Inputted file will not open";

for($i=0; $i<=($length-1); $i++){
	if($array[$i] eq -src) { 
		$i++;
		$src ="$array[$i]";
		$src=~s/\/$//; #removes the last / of the directory path, if its given.
	}
	if($array[$i] eq -out){
		$i++;
		$output="$array[$i]";
		$output=~s/\/$//;
	}
}

@dir_list = `find $src/* -maxdepth 0 -type d`;
chomp @dir_list;
$num = scalar(@dir_list);
my %h; #The hash of gene names found in the first directory

for (my $it=0; $it < $num; $it++) {
open(info, "$dir_list[$it]"."/info.txt");
    while(1) {
        binmode info; my $gene_name = "";
        if(($n = read info, $gene_name, 8)!=8) {
                if($n == 0) {last;}
                else { die "Gene name not in required format\n";}
	}
        my $sep = "";
        if(($n = read info, $sep, 1)!=1) {
                die "No proper separator after $gene_name. Cannot map\n"; }
	chomp $sep;
        if(!($sep eq "	")) {
                die "No proper tab separator after $gene_name. Cannot map\n"; }

        my $s = "";my $i = 0;my @gene = "";
        while(($n = read info, $s, 1)!=0) {
                if($s ne "\n") {
                        $gene[$i++] = $s;
                } else { last;}
        }
        if($n == 0) {
                die "No proper separator after @gene. Cannot map\n"; }
	my $gene_loc = join('', @gene);
		if(!exists($h{$gene_name}{$it})){
			$h{$gene_name}{$it}=$gene_loc;  #a gene name maps to its numbered directory in dir1
		} else {
			print "Why are there duplicate genes in your info file?!\n"; #there should not be duplicates
		}
}
close info;
}

my @geneCount = ((0) x $num_dirs);
open infoOut, ">", "$output"."/info.txt";  #creates a new info file mapping the merged list of genes to a numbered directory

for(my $rdir=0;$rdir<$num_dirs;$rdir++) {
	system("mkdir -p $output/DIR_$rdir");
}

my $complete = 0;
my $thresh = 0;
foreach $Gene (sort keys %h){
	if(scalar(keys(%{$h{$Gene}}))==1){
		formatFiles($h{$Gene}); 
	} else {
		mergeFiles($h{$Gene});  #merge the files
	}
	$complete ++;
	if($complete > $thresh) {
		print "Merging $complete complete\n";
		$thresh+= 1000;
	}
}
close infoOut;

sub formatFiles{
	my $par = shift;
	my $index;
	foreach $ind (keys %{$par}) { $index = $ind; }
	my $dir = $dir_list[$index];
	my $filenum = $par->{$index};
	my %position; #hash of the encrypted positions
	my %person;	#hash of the encrypted ids
	my $snvCount=0;
	my $indCount =0;
	my $random_number = int(rand($num_dirs));
	$geneCount[$random_number]++;
	my $output_dir = $output."/DIR_$random_number/gene".$geneCount[$random_number];

	print infoOut "$Gene\t$output_dir\n";

	#if (! -d $output_dir) { system("mkdir -p $output_dir"); }#, 0777; chmod 0777, $output_dir;
	#else { `rm -rf $output_dir/*`;}

	open genotypeOut, ">", "$output_dir.data.geno" or die "help!3";
	open phenotypeOut, ">", "$output_dir.data.pheno" or die "help!6";
	open weightsOut, ">", "$output_dir.data.wt" or die "help!9";
 
	open genotypeIn, "$dir/$filename.data.geno";
	open phenotypeIn, "$dir/$filename.data.pheno";
	open weightsIN, "$dir/$filename.data.wt";

	while(<weightsIN>){ #this is the polyphen weight file which is: encryptedposition\tscore
		my $line = $_;
		chomp $line;
		my @a = split(/\t/,$line);

		if(!exists($position{$a[0]})){ #creates a hash of the encrypted position
			$snvCount++;
			$position{$a[0]}="$snvCount"."\t"."$a[1]"; #$a[1] is the polyphen weight
			print weightsOut "$position{$a[0]}\n"; #rewrites it into an acceptable format
		} else {
			print "There are duplicate SNPs in gene $filenum! Is there a problem with these files?\n"; #This shouldn't print, otherwise there is a problem!
		}
	}

	while(<phenotypeIn>){
		my $line =$_;
		chomp $line;
		my @a = split(/\t/, $line);
		if(!exists($person{$a[0]})){ #creates a hash of encrypted id's
			$indCount++;
			$person{$a[0]}="$indCount"."\t"."$a[1]";
			print phenotypeOut "$person{$a[0]}\n"; #rewrites to an accepted format
		} else {
			print "There are duplicate ID's in gene $filenum! Is there a problem with these files?\n";
		}
	}

	while(<genotypeIn>){
		my $line = $_;
		chomp $line;
		my @a = split(/\t/,$line);
		if(!exists($person{$a[0]})||!exists($position{$a[1]})){ #checks that the position and id in the genotype file do exist in the other two files
			print "There are ID's or SNV's in the genotype file of gene $filenum not found in other files of $dir! Is there a problem with these files?\n";
		} else {
			my @b= split(/\t/, $person{$a[0]});
			my @c = split(/\t/, $position{$a[1]});
			print genotypeOut "$b[0]\t$c[0]\t$a[2]\n"; #prints it in an accepted format, keeping the same numeric substitution for the encrypted positions and ids
		}
	}
	close genotypeIn;
	close genotypeOut;
	close phenotypeIn;
	close phenotypeOut;
	close weightsIn;
	close weightsOut;
}

sub mergeFiles{
	my $par = shift;
	my $random_number = int(rand($num_dirs));
	$geneCount[$random_number]++;
	my $output_dir = $output."/DIR_$random_number/gene".$geneCount[$random_number];

	print infoOut "$Gene\t$output_dir\n";

	#if (! -d $output_dir) { system("mkdir -p $output_dir"); }#, 0777; chmod 0777, $output_dir;
	#else { `rm -rf $output_dir/*`;}
	open genotypeOut, ">", "$output_dir.data.geno" or die "help!3";
	open phenotypeOut, ">", "$output_dir.data.pheno" or die "help!6";
	open weightsOut, ">", "$output_dir.data.wt" or die "help!9";
		my %position;
		my $snvCount=0;

	foreach $ind (keys %{$par}) {
		my $index = $ind;
		my $dir = $dir_list[$index];
		my $filename = $par->{$index};
		my %person;
		my $indCount =0;

		open genotypeIn, "$dir/$filename.data.geno" or die "help!1";
		open phenotypeIn, "$dir/$filename.data.pheno" or die "help!4";
		open weightsIn, "$dir/$filename.data.wt" or die "help!7";

		#This is the same in the formatFiles subfunction
		while(<weightsIn>){
			my $line = $_;
			chomp $line;
			my @a = split(/\t/,$line);

			if(!exists($position{$a[0]})){
				$snvCount++;
				$position{$a[0]}="$snvCount"."\t"."$a[1]"; #$a[1] is the polyphen weight
				print weightsOut "$position{$a[0]}\n";
			}
		}

		#The next two are similar to the two above, but with the Id's instead of the positions.
		while(<phenotypeIn>){
			my $line =$_;
			chomp $line;
			my @a = split(/\t/, $line);

			if(!exists($person{$a[0]})){
				$indCount++;
				$person{$a[0]}="$indCount"."\t"."$a[1]";
				print phenotypeOut "$person{$a[0]}\n";
			} else {
				print "There are duplicate ID's in gene $filenum! Is there a problem with these files?\n";
			}
		}

		#These next two while loops are similar to the loop in the formatFiles subfunction
		while(<genotypeIn>){
			my $line = $_;
			chomp $line;
			my @a = split(/\t/,$line);

			if(!exists($person{$a[0]})||!exists($position{$a[1]})){
				print "There are ID's or SNV's in the genotype file of gene $filenum not found in other files! Is there a problem with these files?\n";
			} else {
				my @b= split(/\t/, $person{$a[0]});
				my @c = split(/\t/, $position{$a[1]});
				print genotypeOut "$b[0]\t$c[0]\t$a[2]\n";
			}
		}
		close genotypeIn;
		close phenotypeIn;
		close weightsIn;
	}
	close genotypeOut;
	close phenotypeOut;
	close weightsOut;
}

