#!/usr/bin/perl

####
# Jacques Dainat 2015/03
# jacques.dainat@bils.se
####
use strict;
use Pod::Usage;
use Getopt::Long;
use Bio::SeqIO ;
use IO::File ;
use Bio::Tools::GFF;

my $start_run = time();
my $opt_HardMask;
my $opt_SoftMask;
my $opt_gfffile;
my $opt_fastafile;
my $opt_output;
my $opt_help = 0;

# Character for hardMask
my $hardMaskChar;
my $width = 60; # line length printed

# OPTION MANAGMENT
if ( !GetOptions( 'g|gff=s' => \$opt_gfffile,
                  'f|fa|fasta=s' => \$opt_fastafile,
                  'hm:s' => \$opt_HardMask,
                  'sm' => \$opt_SoftMask,
                  'o|output=s'      => \$opt_output,

                  'h|help!'         => \$opt_help ) )
{
    pod2usage( { -message => 'Failed to parse command line',
                 -verbose => 1,
                 -exitval => 1 } );
}

if ($opt_help) {
    pod2usage( { -verbose => 2,
                 -exitval => 0 } );
}
 
if ( (! (defined($opt_gfffile)) ) || (! (defined($opt_fastafile)) ) || ( (! defined($opt_HardMask) && (! defined($opt_SoftMask))) ) ){
    pod2usage( {
           -message => "\nAt least 3 parametes are mandatory:\nInput reference gff file (-g);  Input reference fasta file (-f); Mask type (-hm for hard mask or -sm for soft mask)\n\n".
           "Ouptut is optional. Look at the help documentation to know more.\n",
           -verbose => 0,
           -exitval => 2 } );
}

if (defined ($opt_HardMask) && defined ($opt_SoftMask)){
  print "It is not possible to HardMask and SoftMask at the same time. Choose only one the options and try again !\n"; exit();
}

my $ostream           = IO::File->new();
if (defined($opt_output) ) {
   $ostream->open( $opt_output, 'w' ) 
}
else{
  $ostream->fdopen( fileno(STDOUT), 'w' ) or
  croak( sprintf( "Can not open STDOUT for writing: %s", $! ) );
}

if (defined( $opt_HardMask)){
  print "You choose to Hard Mask the genome.\n";
	if (! $opt_HardMask){
	  $hardMaskChar = "n";
	}
	elsif(length($opt_HardMask) == 1){
	  $hardMaskChar = $opt_HardMask;
	}
	else{print "$opt_HardMask cannot be used to Mask. A character is mandatory.\n";exit;}
	print "Charcater uses for Mask: $hardMaskChar\n";
}
if (defined( $opt_HardMask)){
  print "You choose to Soft Mask the genome.\n";
}
##### MAIN ####

#### read gff file and save info in memory
my %gff; my $nbLineRead=0;

# Manage input fasta file
my $gff_in = Bio::Tools::GFF->new(-file => $opt_gfffile, -gff_version => 3);


print( "Reading features from $opt_gfffile...\n");
  while (my $feature = $gff_in->next_feature()) {
    my $seqname=$feature->seq_id();
    my $start=$feature->start();
    my $end=$feature->end();
   	push @{$gff{uc $seqname}},"$start $end";
    $nbLineRead++;
   }
close gff_in;
print "$nbLineRead lines read\n";

#### read fasta
my $nbFastaSeq=0;
my $nucl_masked=0;
my $inFasta  = Bio::SeqIO->new(-file => "$opt_fastafile" , '-format' => 'Fasta');

while ($_=$inFasta->next_seq()) {
    my $seqname = $_->id;
    my $sequence = $_->seq;

    foreach (@{$gff{uc $seqname}}) {
	    my ($start,$end) = split;
      if ($opt_SoftMask){
        my $strinTolo = substr($sequence,$start-1,$end+1-$start);
        substr($sequence,$start-1,$end+1-$start) = lc $strinTolo;
      }
      else{
	     substr($sequence,$start-1,$end+1-$start) = $hardMaskChar x ($end+1-$start);
      }
      $nucl_masked=$nucl_masked+($end-$start+1);
    }

    print $ostream ">$seqname\n";
    for (my $i=0;$i<length $sequence;$i+=$width) { print $ostream substr($sequence,$i,$width)."\n" }
    $nbFastaSeq++;
}
print "$nbFastaSeq fasta sequences read.\n";
print "$nucl_masked nucleotides masked.\n";
my $end_run = time();
my $run_time = $end_run - $start_run;
print "Job done in $run_time seconds\n";
__END__

=head1 NAME

gffMask_bils.pl -
This script masks (hard or soft) repeats among sequences. It needs 3 input parameters: a gff3 file, a fasta file, and a Mask method. 
The result is written to the specified output file, or to STDOUT.

=head1 SYNOPSIS

    ./gffMask_bils.pl -g=infile.gff -f=infile.fasta  (-hm or -sm) [ -o outfile ]
    ./gffMask_bils.pl --help

=head1 OPTIONS

=over 8

=item B<-g>, B<--gff> or B<-ref>

Input GFF3 file that will be read (and sorted)

=item B<-f> or B<--fasta> 

Input fasta file that will be masked

=item B<-sm> 

SoftMask option =>Sequences masked will be in lowercase

=item B<-hm> 

HardMask option => Sequences masked will be replaced by a character. By default the character used is 'n'. But you are allowed to speceify any character of your choice. To use 'z' instead of 'n' type: -hm z

=item B<-o> or B<--output>

Output GFF file.  If no output file is specified, the output will be
written to STDOUT.

=item B<-h> or B<--help>

Display this helpful text.

=back

=cut
