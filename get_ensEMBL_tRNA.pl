#!/usr/bin/perl

=head1 NAME

get_ensEMBL_tRNA.pl - script to extract tRNA 'features' from ensEMBL

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use FindBin qw($Bin);
use lib "$Bin/lib";
use ensembl;
use Bio::EnsEMBL::ApiVersion;

$| = 1; # turn on autoflush
my $help;
my $keepPseudogenes = 1;
my $species = 'human';
my $out;
my $man;
my $VERBOSE = 1;
our $VERSION = '0.5';

GetOptions (
	'pseudo!'   => \$keepPseudogenes,
	'species=s' => \$species,
	'out=s'     => \$out,
   'man'       => \$man,
   'help|?'    => \$help,
) or pod2usage();

pod2usage(-verbose => 2) if ($man);
pod2usage(-verbose => 1) if ($help);
#pod2usage(-msg => 'Please supply a valid filename.') if (!$file or !-e $file);

$out = "ensEMBL_${species}_tRNAs.fasta";

# load ensembl object
my $ens = ensembl->new(species => $species, VERBOSE => $VERBOSE);
print "Species: ", $ens->species, "\n" if $VERBOSE;

# connect to ensembl and do some checks
my $registry = $ens->connect();
printf "NOTE: using Ensembl API version %s\n", software_version() if $VERBOSE;
warn "Warning - API version check has failed. You probably need to update your local install.\n" unless ($registry->version_check($registry->get_DBAdaptor($species, 'core')));

## open output file
open(my $OUT, ">", $out) or die "ERROR - unable to open '$out' for write: ${!}\nDied";

## retrieve all tRNA 'features' (thanks to Bret Overduin at ensEMBL)
print "Connecting to Ensembl...\n";
my $slice_adaptor = $registry->get_adaptor( $species, 'Core', 'Slice' );
die "ERROR - failed to get gene adaptor for '$species'. Check spelling and that it's a valid Ensembl species. Or check that you're using the correct API.\n" unless (defined($slice_adaptor));

print "Retrieving data...\n";
my $id = "ENS_tRNA";
my $n = 1;
foreach my $slice (@{$slice_adaptor->fetch_all("toplevel")}) {
   my $tRNAs = $slice->get_all_SimpleFeatures("tRNAscan");
   
   ## retrieve requied fields for each tRNA
   foreach my $tRNA (@{$tRNAs}){
      printf "\r%5d", $n;
      
      if ($tRNA->display_label eq 'Pseudo') {
         next unless ($keepPseudogenes);
      }
      
      # determine what kind of chromosome we're dealing with
      my $chromosome = $tRNA->coord_system_name();

      # create new slice of DNA specific to the tRNA
      my $newSlice = $slice_adaptor->fetch_by_region($chromosome , $tRNA->seq_region_name, $tRNA->start, $tRNA->end, $tRNA->strand);
      unless($newSlice){
         my $s = sprintf "$chromosome:%s\t%s\t%s\t%s\n", $tRNA->seq_region_name, $tRNA->start, $tRNA->end, $tRNA->strand;
         die "ERROR - slice failed at: $s\n"
      }
      my $sequence = $newSlice->seq();
      
      # print out sequence data in Fasta format and as close as 
      # possible to the ensEMBL ncRNA format
      printf $OUT ">$id%05d ncrna:tRNA_%s %s:%s:%s:%s gene:unknown\n$sequence\n", $n, $tRNA->display_label, $tRNA->seqname(), $tRNA->start,$tRNA->end, $tRNA->strand;
      ++$n;
   }
}
print "\nDone!\n";


=head1 SYNOPSIS

get_ensEMBL_tRNA.pl [--species <name>] [--out <file>] [--pseudo|--no-pseudo] [--man] [--help]

=head1 DESCRIPTION

ensEMBL doesn't define tRNAs as genes, but as 'Features' on the genome. This is despite the fact that other non-coding RNAs (ncRNAs) are, including tRNA pseudogenes.

This script uses the ensEMBL API to retrieve the full list of 'annotated' tRNAs in the human genome. Now modified to search any of the organisms found in ensEMBL.

=head1 OPTIONS

=over 5

=item B<--species>

Organism to search. [default: Human]

=item B<--out>

File for output. [default: ensEMBL_<species>_tRNAs.fasta]

=item B<--pseudo|--no-pseudo>

Toggle whether to return pseudogenes. [default: on]

=item B<--help>

Brief help.

=item B<--man>

Full manpage of program.

=back

=head1 AUTHOR

Chris Cole <c.cole@dundee.ac.uk>

=cut