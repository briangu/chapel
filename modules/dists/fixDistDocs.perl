#!/usr/bin/env perl

# A counterpart for modules/internal/fixInternalDocs.sh
# for modules/dists, modules/layouts.

use English;
use strict;
use warnings;
use open OUT => ":raw";

$#ARGV == 0 or die "Error: This script takes one argument," .
    " the path of the intermediate sphinx project\n";

my $TEMPDIR = "$ARGV[0]/source/modules/dists";
chdir $TEMPDIR or die "Could not cd to $TEMPDIR";

my $errors = 0;

process("../layouts/LayoutCSR.rst");
process("BlockDist.rst");
process("CyclicDist.rst");
process("BlockCycDist.rst");
process("ReplicatedDist.rst");
process("PrivateDist.rst");
process("DimensionalDist2D.rst");
process("dims/ReplicatedDim.rst");
process("dims/BlockDim.rst");
process("dims/BlockCycDim.rst");

# There is nothing user-facing there.
# chpldoc creates this .rst because DSIUtil is imported from the above modules.
unlink "DSIUtil.rst" or warn "Could you remove DSIUtil.rst: $!";

#or: for my $rst (@ARGV) { process($rst); }

print "done\n";
exit $errors;

# non-fatal error
sub errorNF { print "Error: ", @_, "\n"; $errors++; }

sub process {
   my ($rst) = @_;
   my $tmp = "$rst.tmp";
   #print "processing $rst\n";

   open RST, $rst or
       ( errorNF("could not open the input file '$rst'"), return );
   open MOD, ">", $tmp or
       ( errorNF("could not open the temp file '$tmp'"), close RST, return );

   # Print all lines until the one after "Module:",
   # which is the underline.
   while (<RST>) {
      print MOD;
      if (/^Module:/) {
	 my $next = <RST>;
	 $next =~ /^=+$/ or die "Expected a line after Module:, got $next";
	 print MOD $next;
	 last;
      }
   }

   # Skip everything until "class::", edit that line and print.
   while (<RST>) {
      if (/^.. class::/) {
	 s/ : Base.*//;
	 print MOD;
	 last;
      }
   }

   # Print until a chpldoc line for the next declaration.
   while (<RST>) {
      m/ attribute::| class::| method::/ and last;
      print MOD;
   }

   # That's all we will retain.
   close RST;
   close MOD;
   rename $tmp, $rst or
       errorNF("could not update $rst");
}