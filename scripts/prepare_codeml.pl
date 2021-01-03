# This script is used to prepare files for PAML analysis based on treebest results
# By Zhen Wang 08/23/2016
use strict;
use warnings;
use Getopt::Long;
use Bio::TreeIO;
use Bio::AlignIO;

# Command option
my $ortholog_file;		# Ortholog table generated by parse_ortholog.pl after parsing 'treebest nj -v' result
my $species_tree_file;		# Species tree template for generating gene tree for PAML (can be a subset of the ortholog table; should be labelled if necessary)
my $cds_aln_dir;		# Directory containing all files of CDS alignment generated by 'treebest backtrans'
my $sig_orth_aln_dir;		# Single-copy ortholog CDS alignment directory (fasta format for subsequent Gblocks analysis)
my $sig_orth_tree_dir;		# Single-copy ortholog tree for PAML

GetOptions(
	"ortholog_file=s" => \$ortholog_file,
	"species_tree_file=s" => \$species_tree_file,
	"cds_aln_dir=s" => \$cds_aln_dir,
	"sig_orth_aln_dir=s" => \$sig_orth_aln_dir,
	"sig_orth_tree_dir=s" => \$sig_orth_tree_dir
);

die "Usage: perl prepare_codeml.pl --ortholog_file --species_tree_file --cds_aln_dir --sig_orth_aln_dir --sig_orth_tree_dir"
	unless defined $ortholog_file && defined $species_tree_file && defined $cds_aln_dir && defined $sig_orth_aln_dir && defined $sig_orth_tree_dir;

# Extract species from species tree file
my $species_tree = new Bio::TreeIO(-format=>'newick', -file=>$species_tree_file)->next_tree;
my @species = map {(split(/\s+/, $_->id))[0]} $species_tree->get_leaf_nodes;	# Space should be used to distinguish sequence name and PAML label
die "Error: no species were found in $species_tree_file\n" if @species == 0;

# Read ortholog table
open(TAB, $ortholog_file) || die "Error: cannot open ortholog table $ortholog_file: $!\n";

my %species2col;		# Map from species in the tree (can be a subset) to the colunmns of the ortholog table
my %cluster2index;		# A cluster may contain more than one ortholog groups; use index to ditinguish them

while (<TAB>) {
	chop;
	my ($cluster_id, @cols) = split(/\t/);			# Format of the ortholog table
	if ($cluster_id eq 'cluster_id') {			# The first line of the table, column names are species
		foreach my $species (@species) {		# If the species exists in the tree, get the column number 
			for (my $i = 0; $i < @cols; $i++) {
				$species2col{$species} = $i if $species eq $cols[$i];
			}
			exists $species2col{$species} || die "Error: cannot find $species in the ortholog table\n";
		}
	} else {						# The remaining lines of the table (ortholog groups)
		my @seq_ids;
		foreach my $species (@species) {
			my $i = $species2col{$species};
			my $gene = $cols[$i];			# Get genes for each species
			if (defined $gene && $gene ne '' && $gene !~ /,/) {		# Judge if the gene exists and is unique
				my $seq_id = $gene . "_" . $species;			# Sequence id in the alignment is consistent with treebest standard
				push(@seq_ids, $seq_id); 
			}
		}
		if (@seq_ids == @species) {			# If this is a single-copy ortholog group
			# print $cluster_id, "\n";
			my $cds_aln_file;			# Output alignment file name
			my $cds_tree_file;			# Output gene tree file name

			# Set output file nane
			if (!exists $cluster2index{$cluster_id}) {	# Use the cluster id for output file name if the cluster appears for the first time
				$cds_aln_file = "$cluster_id.fasta";
				$cds_tree_file = "$cluster_id.nwk";
				$cluster2index{$cluster_id} = 0;
			} else {					# For cluster with more than one single-copy ortholog groups, index will be added in the output file name
				$cluster2index{$cluster_id}++;
				$cds_aln_file = "$cluster_id" . "_" . $cluster2index{$cluster_id} . ".fasta";
				$cds_tree_file = "$cluster_id" . "_" . $cluster2index{$cluster_id} . ".nwk";
			}

			# Write single-copy CDS alignment
			my $cds_aln = Bio::AlignIO->new(-file=>"$cds_aln_dir/$cluster_id.fasta", -format=>"fasta")->next_aln;
			foreach my $seq ($cds_aln->each_seq) {
				my $seq_id = $seq->id;
				my @keep = grep {$seq_id eq $_} @seq_ids;		# Remove paralogs from original alignment
				$cds_aln->remove_seq($seq) if @keep == 0;
			}
			my $aln_out = Bio::AlignIO->new(-file=>">$sig_orth_aln_dir/$cds_aln_file", -format=>'fasta');
			$cds_aln->set_displayname_flat;					# Sequence length should not be output
			$aln_out->write_aln($cds_aln);

			# Write gene tree
			my $gene_tree = $species_tree->clone;           # Prepare gene tree based on the species tree
			my @nodes=$gene_tree->get_leaf_nodes;
			for (my $i = 0; $i < @species; $i++) {		# the orders of nodes, species and sequences are consistent
				my $node_id = $nodes[$i]->id;
				$node_id =~ s/$species[$i]/$seq_ids[$i]/;		# Replace species name with sequence name (labels are preserved)
				$nodes[$i]->id($node_id);
			}
			my $tree_out = Bio::TreeIO->new(-file=>">$sig_orth_tree_dir/$cds_tree_file", -format=>'newick');
			$tree_out->write_tree($gene_tree);
		}
	}	
}

