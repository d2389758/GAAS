#!/usr/bin/perl

# Convert Mfannot output file to GFF3 format
# kbseah@mpi-bremen.de      2015-04-01
# modified by jacques dainat 2017-11: jacques.dainat@nbis.se

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;

my $mfannot_file;
my $gff_file;
my %startend_hash;     # Stores start and end positions of each feature reported
#my %end_hash;       # Stores end positions of each feature reported
my %contig_hash;    # Stores contig each feature falls on
my %gencode_hash;

GetOptions(
    'mfannot|m|i=s' => \$mfannot_file,
    'gff|g|o=s' => \$gff_file,
    'help|h' => sub { pod2usage( -exitstatus=>2, -verbose=>2 ); },
    'man' => sub { pod2usage(-exitstatus=>0, -verbose=>2); }
) or pod2usage ( -exitstatus=>2, -verbose=>2 );

if (!defined $mfannot_file) {
    pod2usage( -message=>"Insufficient options supplied", -exitstatus=>2 );
}

## MAIN ##############################################################

read_mfannot($mfannot_file);
write_gff($gff_file);

## SUBROUTINES #######################################################

sub usage {
    print STDERR "Convert Mfannot Masterfile to GFF3 format\n";
    print STDERR "\n";
    print STDERR "Usage: perl mfannot2gff.pl -m input.new -g output.gff \n";
    print STDERR "\n";
    exit();
}

sub read_mfannot {
    my $current_contig;         # Track the current contig
    my $current_genetic_code;   # Track current genetic code
    my $current_pos=1;          # Track current position
    #my $current_feature;       # Track current feature
    #my $current_startend;      # Track current feature start/end
    #my $current_leftright;
    my $current_comment;        # Track current commentfield
    my $writeflag=0;
    my $previousSplit1="";
    my $previousSplit2="";

    open(INPUT, "<", "$_[0]") or die ("$!\n");
    # Open Mfannot file for reading
    while (<INPUT>) {
        chomp;
        if ($_ =~ /^>(.*) gc=(\d+)/) {
            # If a header line, update the current contig and genetic code
            ($current_contig, $current_genetic_code) = ($1, $2);
            $current_pos=1; # Reset the position counter
            $gencode_hash{$current_contig} = $current_genetic_code;
        }
        elsif ($_ =~ /^\s+(\d+)\s+([ATCGatcgNn]+)/) {
            # If line is a numbered sequence line
            my ($pos_begin,$seqline) = ($1, $2);   # Sequence position
            $current_pos = length($seqline) + $pos_begin - 1;
        }
        elsif ($_ =~ /^;+\s+G-(\w.*)/) {
            # If line is a feature boundary, save that information
            my @splitline = split /\s/, $1;
            #push (@{$contig_hash{$current_contig}}, substr($splitline[0],2));
            $contig_hash{$current_contig}{$splitline[0]} = 1;
            

            if ($splitline[1] eq "<==" && $splitline[2] eq "start" ) {
                if (defined $startend_hash{$splitline[0]}{"start"}) {
                    
                    if ($previousSplit1 eq $splitline[1] and $previousSplit2 eq $splitline[2]){ #keep the first key and the second value
                        my $i = keys %{$startend_hash{$splitline[0]}{"start"}};
                        $startend_hash{$splitline[0]}{"start"}{$i-1} = $current_pos;
                        print STDERR "11 - Feature ". $splitline[0]. " already defined. Please manually verify in $mfannot_file\n";
                        next;
                    } 

                    my $i = keys %{$startend_hash{$splitline[0]}{"start"}};
                    $startend_hash{$splitline[0]}{"start"}{$i} = $current_pos;
                    print STDERR "1 - Feature ". $splitline[0]. " already defined. Please manually verify in $mfannot_file\n";
                }
                else { $startend_hash{$splitline[0]}{"start"}{0} = $current_pos; }
            }
            elsif ($splitline[1] eq "==>" && $splitline[2] eq "end" ) {
                if (defined $startend_hash{$splitline[0]}{"end"}{0}) {
                    
                    if ($previousSplit1 eq $splitline[1] and $previousSplit2 eq $splitline[2]){ #keep the first key and the second value
                        my $i = keys %{$startend_hash{$splitline[0]}{"end"}};
                         $startend_hash{$splitline[0]}{"end"}{$i-1} = $current_pos;
                         print STDERR "22 - Feature ". $splitline[0]. " already defined. Please manually verify in $mfannot_file\n";
                         next;
                    } 

                    my $i = keys %{$startend_hash{$splitline[0]}{"end"}};
                    $startend_hash{$splitline[0]}{"end"}{$i} = $current_pos;
                    print STDERR "2 - Feature ". $splitline[0]. " already defined. Please manually verify in $mfannot_file\n";
                }
                else { $startend_hash{$splitline[0]}{"end"}{0} = $current_pos; }
                
            }
            elsif ($splitline[1] eq "==>" && $splitline[2] eq "start") {
                if (defined $startend_hash{$splitline[0]}{"start"}{0}) {
                    
                    if ($previousSplit1 eq $splitline[1] and $previousSplit2 eq $splitline[2]){
                        print STDERR "3 - Feature ". $splitline[0]. " already defined. Please manually verify in $mfannot_file\n";
                        next;
                    } #keep the first key and the first value
                    
                    my $i = keys %{$startend_hash{$splitline[0]}{"start"}};
                    $startend_hash{$splitline[0]}{"start"}{$i} = $current_pos + 1;
                    print STDERR "3 - Feature ". $splitline[0]. " already defined. Please manually verify in $mfannot_file\n";
                }
                else { $startend_hash{$splitline[0]}{"start"}{0} = $current_pos + 1; }
            }
            elsif ($splitline[1] eq "<==" && $splitline[2] eq "end") {
                if (defined $startend_hash{$splitline[0]}{"end"}{0}) {
                    
                    if ($previousSplit1 eq $splitline[1] and $previousSplit2 eq $splitline[2]){
                    print STDERR "44 - Feature ". $splitline[0]. " already defined. Please manually verify in $mfannot_file\n";
                    next;
                    } #keep the first key and the first val

                    my $i = keys %{$startend_hash{$splitline[0]}{"end"}};
                    $startend_hash{$splitline[0]}{"end"}{$i} = $current_pos + 1;
                    print STDERR "4 - Feature ". $splitline[0]. " already defined. Please manually verify in $mfannot_file\n";
                }
                else { $startend_hash{$splitline[0]}{"end"}{0} = $current_pos + 1; }
            }
            else { print STDERR "Exception to possible combination of feature boundaries and directions: $_ \n"; }
            $previousSplit1=$splitline[1];
            $previousSplit2=$splitline[2];
        }
    }
    close(INPUT);
}

sub write_gff {
    open(GFF, ">", "$_[0]") or die ("$!\n");
    print GFF "##gff-version 3\n";  # header line
    foreach my $thecontig (keys %contig_hash) {
        foreach my $thefeature (keys %{$contig_hash{$thecontig}}) {
            
            foreach my $featureNB (keys %{$startend_hash{$thefeature}{"start"}}) {
                my $featuretype;
                if ($thefeature =~ /^rnl/ | $thefeature =~ /^rns/) { $featuretype="rRNA"; }
                elsif ($thefeature =~ /^trn/) { $featuretype = "tRNA"; }
                else {$featuretype="CDS";}
                my $featuredir;
                my $frame;
                my $start;
                my $end;
                if ($startend_hash{$thefeature}{"end"}{$featureNB} < $startend_hash{$thefeature}{"start"}{$featureNB}) {
                    $featuredir = "-";
                    $start = $startend_hash{$thefeature}{"end"}{$featureNB};
                    $end = $startend_hash{$thefeature}{"start"}{$featureNB};
                } else {
                    $featuredir="+";
                    $start = $startend_hash{$thefeature}{"start"}{$featureNB};
                    $end = $startend_hash{$thefeature}{"end"}{$featureNB};
                }
                if ($featuretype eq "CDS") { $frame="0"; } else { $frame = "."; }
                my @gff3_line = ($thecontig,
                                 "mfannot",
                                 $featuretype,
                                 $start,
                                 $end,
                                 ".",
                                 $featuredir,
                                 $frame,
                                 "ID=$thefeature;Name=$thefeature;transl_table=$gencode_hash{$thecontig};gene=$thefeature"
                                 );
                print GFF join ("\t", @gff3_line)."\n";
            }
        }
    }
    close (GFF);
}

=head1 NAME

mfannot2gff.pl - Convert MFannot Masterfile to GFF3 format

=head1 SYNOPSIS

perl mfannot2gff.pl -m <mfannot> -g <gff>
perl mfannot2gff.pl --help

=head1 DESCRIPTION

Conversion utility for MFannot "masterfile" annotation produced by the MFannot
pipeline (http://megasun.bch.umontreal.ca/RNAweasel/). Reports GFF3 format. If
more than one instance of a gene annotation (e.g. more than one ORF annotated
as "nad10"), then you will have to manually verify the MFannot file and give
them distinguishing names before running this script again.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2015, Brandon Seah (kbseah@mpi-bremen.de)
... GPL-3 ...
modified by jacques dainat 2017-11

=head1 OPTIONS

=over 8

=item B<-m> or B<-i> or B<--mfannot>

The mfannot input file

=item B<-g> or B<-o> or B<--gff>

the gff output file

=item B<-h> or B<--help>

Display this helpful text.

=back

=cut
