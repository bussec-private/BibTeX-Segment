#!/usr/bin/perl
#
# This script parses the input file for "\cite{...}" citations, then reads a bibtex file and finally produces an output of the BibTeX entries matching
# the citations. This allows hte user to keep one big literature library file, but only to include the references that are actually needed by a given
# set of LaTeX documents.
#
# TO DOs: - multiple in-files (TEX), probably as filter
#         - filter for key-value pairs (inclusion/exclusion)
#         - sort order for references
#         - automatically parse outfilename from TEX source

use warnings;
use strict;
use Getopt::Long;

my %hash_cite_references;
my %hash_bib_reference;

my $option_show_help = '';
my $option_infile_tex = '';
my $option_infile_bib = '';
my $option_outfile_bib = '';

GetOptions (
    'help' => \$option_show_help,
    'intex=s' => \$option_infile_tex,
    'inbib=s' => \$option_infile_bib,
    'outbib=s' => \$option_outfile_bib
);

if (($option_show_help) || ! ($option_infile_tex) || ! ($option_infile_bib) || ! ($option_outfile_bib)) {
    print "ERROR: Mandatory file option missing!\n" if ! ($option_infile_tex) || ! ($option_infile_bib) || ! ($option_outfile_bib); 
    print "Usage: bibtex_segment --intex=TEXFILE --inbib=BIBFILE_IN --outbib=BIBFILE_OUT\n";
    print " --intex  : screen TEXFILE for citations\n";
    print " --inbib  : use BIBFILE_IN as reference library\n";
    print " --outbib : out bibtex segment into BIBFILE_OUT\n";
    exit;
}

open TEXFILE, "<", "$option_infile_tex" or die "Could not open TEXFILE $option_infile_tex !";
open BIBFILE_IN, "<", "$option_infile_bib" or die "Could not open BIBFILE_IN $option_infile_bib !";

{
    my $tmp_file_content = "";
    foreach (<TEXFILE>) {
        chomp;
        $tmp_file_content .= $_;
    }

    foreach ($tmp_file_content =~ /\\cite\{[^}]+}/g) {
        s/^\\cite\{[[:space:]]*(.+)[[:space:]]*\}$/$1/;
        foreach (split /[[:space:]]*,[[:space:]]*/) {
            $hash_cite_references{$_}++;
        }
    }
}

{
    my $tmp_file_content = "";
    my @tmp_bibtex_array;

    foreach (<BIBFILE_IN>) {                    # No chomp-ing to preserve line-breaks
        $tmp_file_content .= $_;
    }

    @tmp_bibtex_array = ( $tmp_file_content =~ /@([^,]+)                                        # match entry type
                            \{([^,]+)                                                           # match entry ID
                            ((?:,[[:space:]]*[^[:space:]=]+[[:space:]]*=[[:space:]]*\{          # match key-Value key
                            [^{}]*(?:\{[^}]*\}[^{}]*)*                                          # match key-value value
                            \})+)                                                               # match key-value end
                            [[:space:]]*\}/gx
    );

    foreach my $cnt_foo (0..(@tmp_bibtex_array/3)-1) {
        my $entry_type = $tmp_bibtex_array[$cnt_foo*3];
        my $entry_id = $tmp_bibtex_array[$cnt_foo*3+1];
        $hash_bib_reference{$entry_id}{"_ENTRY_TYPE"} = $entry_type;
        my $entry_key_values = $tmp_bibtex_array[$cnt_foo*3+2];
        foreach ($entry_key_values =~ /,[[:space:]]*([^[:space:]=]+[[:space:]]*=[[:space:]]*\{   # match key-value key
                            [^{}]*(?:\{[^}]*\}[^{}]*)*                                           # match key-value value
                            \})/gx ) {
            my ($entry_key, $entry_value) = /([^[:space:]=]+)[[:space:]]*=[[:space:]]*\{([^{}]*(?:\{[^}]*\}[^{}]*)*)\}/;
            $hash_bib_reference{$entry_id}{$entry_key} = $entry_value;
        }
    }
}

open BIBFILE_OUT, ">", "$option_outfile_bib" or die "Could not open BIBFILE_OUT $option_outfile_bib !";

foreach my $tmp_reference (sort keys %hash_cite_references) {
    printf BIBFILE_OUT "@%s{%s", $hash_bib_reference{$tmp_reference}{"_ENTRY_TYPE"},$tmp_reference;
    foreach my $tmp_value (sort keys %{$hash_bib_reference{$tmp_reference}}) {
        next if ($tmp_value eq "_ENTRY_TYPE");
        printf BIBFILE_OUT ",\n\t%s = {%s}", $tmp_value, $hash_bib_reference{$tmp_reference}{$tmp_value};
    }
    printf BIBFILE_OUT "\n}\n\n";
}
 
close TEXFILE;
close BIBFILE_IN;
close BIBFILE_OUT;
