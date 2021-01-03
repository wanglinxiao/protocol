#!/picb/bigdata/program/bin/perl
#$ -S /picb/bigdata/program/bin/perl
#$ -V
#$ -N prepare_ctl
#$ -wd /picb/bigdata/project/tianshu/5_comprativeGenomics_dnds
#$ -o /picb/bigdata/project/tianshu/5_comprativeGenomics_dnds/prepare_ctl.out
#$ -e /picb/bigdata/project/tianshu/5_comprativeGenomics_dnds/prepare_ctl.err

# Create control file for subsequent PAML batch analysis
use strict;
use warnings;

# Set by user
my $wd = "/picb/bigdata/project/tianshu/5_comprativeGenomics_dnds";	# Working directory
my $tmp_dir = "$wd/template";						# Directory of template control files (.ctl)
my $aln_dir = "$wd/sig_orth_aln";					# Directory of sequence alignments (.phy-gb)
my $tree_dir = "$wd/sig_orth_tree";					# Directory of trees (.nwk)
my $ctl_dir = "$wd/ctl";						# Directory of Output control files (.ctl)
my $mlc_dir = "$wd/mlc";						# Directory for PAML main output (.mlc)
my $batches = 10;							# Batch number for multi-processors

# Get all sequence alignment files
opendir(ALN, $aln_dir) || die "Error: cannot open directory $aln_dir\n";
my @aln_files = readdir ALN;
@aln_files = grep {/\.phy-gb$/} @aln_files;

for (my $i = 0; $i < @aln_files; $i++) {
	my $aln_file = $aln_files[$i];
	$aln_file =~ /^(.+)\.phy-gb$/;
	my $id = $1;							# Get id of the alignment

	$aln_file = "$aln_dir/$aln_file";
	my $tree_file = "$tree_dir/$id.nwk";				# Get corresponding tree file
	die "Error: cannot find tree file $tree_file\n" unless -e $tree_file;

	my $batch = $i % $batches;					# Batch number for this run
	mkdir $mlc_dir unless -e $mlc_dir;				# Create directory for PAML main output by batch
	my $mlc_batch_dir = "$mlc_dir/batch_$batch";
	mkdir $mlc_batch_dir unless -e $mlc_batch_dir;

	mkdir $ctl_dir unless -e $ctl_dir;				# Create directory for control file by batch
	my $ctl_batch_dir = "$ctl_dir/batch_$batch";
	mkdir $ctl_batch_dir unless -e $ctl_batch_dir;
	
	opendir(TMP, $tmp_dir) || die "Error: cannot open directory $tmp_dir\n";		# Get all control templates
	my @tmp_files = readdir TMP;
	@tmp_files = grep {/\.ctl$/} @tmp_files;
	die "Error: cannot find template control files (.ctl) in $tmp_dir\n" if @tmp_files == 0;

	foreach my $tmp_file (@tmp_files) {				# For each template file, create control file for the id
		my $ctl_file = "$ctl_batch_dir/$id.$tmp_file";		# Control file name
		my $mlc_file = "$mlc_batch_dir/$id.$tmp_file";		# PAML main output file name
		$mlc_file =~ s/ctl$/mlc/;

		open(CTL_TMP, "$tmp_dir/$tmp_file");			# Set sequence file, tree file and main output file in the control file
		open(CTL, ">$ctl_file");
		while (<CTL_TMP>) {
			if (/seqfile =/) {
				$_ = "seqfile = $aln_file\n";
			} elsif (/treefile =/) {
				$_ = "treefile = $tree_file\n";
			} elsif (/outfile =/) {
				$_ = "outfile = $mlc_file\n";
			}
			print CTL $_;
		}
	}
}

