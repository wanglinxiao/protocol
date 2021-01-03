#!/picb/bigdata/program/bin/perl
#$ -S /picb/bigdata/program/bin/perl
#$ -V
#$ -N fasta2phy
#$ -wd /picb/bigdata/project/tianshu/5_comprativeGenomics_dnds
#$ -o /picb/bigdata/project/tianshu/5_comprativeGenomics_dnds/fasta2phy.out
#$ -e /picb/bigdata/project/tianshu/5_comprativeGenomics_dnds/fasta2phy.err
use strict;
use warnings;
use Bio::AlignIO;

my $aln_dir = "/picb/bigdata/project/tianshu/5_comprativeGenomics_dnds/sig_orth_aln";
opendir(DIR, $aln_dir) || die "Error: cannot open directory $aln_dir\n";
my @files = readdir DIR;

foreach my $file (@files) {
	if ($file =~ /^(.+)\.fasta-gb$/) {
		my $id = $1;
		my $in = Bio::AlignIO->new(-file=>"$aln_dir/$id.fasta-gb", -format=>'fasta');
		my $aln = $in->next_aln;

		my $out = Bio::AlignIO->new(-file => ">$aln_dir/$id.phy-gb", -format => 'phylip');
		$out->flag_SI(1);		# Phylip interleaved format shoule be marked
		$out->idlength(30);		# ID length should be longer than default, or it will not complete
		$out->write_aln($aln);
	}
}

