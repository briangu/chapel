#!/usr/bin/env perl
#

`rm -f Syntax.tex`;
$i = 0;
@texs = `ls *.tex`;
foreach $tex (@texs) {
    chomp $tex;
    $readSyntax = 0;
    $rule = "";
    @lines = `cat $tex`;
    $linenumber = 0;
    foreach $line (@lines) {
        $linenumber += 1;
        if ($line =~ /^\\begin\{syntax\}/) {
            die "$tex:$linenumber: unmatched begin of syntax block" if ($readSyntax == 1);
            $readSyntax = 1;
        } elsif ($line =~ /^\\end\{syntax\}/) {
            die "$tex:$linenumber: unmatched end of syntax block" if ($readSyntax == 0);
            $readSyntax = 0;
            if ($tex eq "Lexical_Structure.tex") {
                $lexes{$i++} = $rule;
            } else {
                $rules{$i++} = $rule;
            }
            $rule = "";
        } elsif ($readSyntax == 1) {
            if ($line =~ /^\s*$/) {
                if ($tex eq "Lexical_Structure.tex") {
                    $lexes{$i++} = $rule;
                } else {
                    $rules{$i++} = $rule;
                }
                $rule = "";
            } else {
                $rule .= $line;
            }
        }
    }
}

open FILE, ">Syntax.tex";
print FILE "%%\n";
print FILE "%% Do not modify this file.  This file is automatically\n";
print FILE "%% generated by collect_syntax.pl.\n";
print FILE "%%\n\n";
print FILE "\\sekshun{Collected Lexical and Syntax Productions}\n";
print FILE "\\label{Syntax}\n\n";
print FILE "This appendix collects the syntax productions listed throughout the specification.  There are no new syntax productions in this appendix.  The productions are listed both alphabetically and in depth-first order for convenience.\n\n";
print FILE "\\subsection{Alphabetical Lexical Productions}\n\n";
$last = "";
foreach $rule (sort values %lexes) {
    $prefix = $last;
    if ($prefix =~ m/(.*:)/) {
        if ($rule =~ m/^$1/) {
            if (!($rule eq $last)) {
                print "Syntax rules do not match\n";
                print "$last$rule";
            }
            $duplicate = 1;
        }
    }
    if ($duplicate == 0) {
        print FILE "\\begin{syntax}\n";
        print FILE "$rule";
        print FILE "\\end{syntax}\n\n";
    }
    $duplicate = 0;
    $last = $rule;
}

print FILE "\\subsection{Alphabetical Syntax Productions}\n\n";
$last = "";
foreach $rule (sort values %rules) {
    $prefix = $last;
    if ($prefix =~ m/(.*:)/) {
        if ($rule =~ m/^$1/) {
            if (!($rule eq $last)) {
                print "Syntax rules do not match\n";
                print "$last$rule";
            }
            $duplicate = 1;
        }
    }
    if ($duplicate == 0) {
        print FILE "\\begin{syntax}\n";
        print FILE "$rule";
        print FILE "\\end{syntax}\n\n";
    }
    $duplicate = 0;
    $last = $rule;
}

print "Collected $i grammar rules in Syntax.tex\n"; # counts duplicates

sub get_used_prefixes {
    foreach (@_) {
        s/\`.*\'//g;
        s/\[OPT\]//g;
        s/^.*://g;
        s/one\ of//g;
        s/[^\-\w\ ]//g;
        s/\s-/\ /g;
        s/\s+/\ /g;
        s/^\s+//g;
    }
}

$i = 0;
foreach $rule (values %lexes) {
    $all{$i++} = $rule;
}

foreach $rule (values %rules) {
    $all{$i++} = $rule;
}

foreach $rule (values %all) {
    if ($rule =~ m/^(.*):/) {
        $counts{$1} = 1;
    }
}

foreach $rule (sort values %all) {
    get_used_prefixes($rule);
    @prefixes = split /\ /, $rule;
    foreach $prefix (@prefixes) {
        if ($counts{$prefix} < 1) {
            print "error: used but not defined: $prefix\n";
        } else {
            $counts{$prefix} += 1;
        }
    }
}

foreach $prefix (sort keys %counts) {
    $counts{$prefix}--;
    if ($counts{$prefix} < 1) {
        print "error: defined but not used: $prefix\n";
    }
}

###
### print lexical rules in depth-first order
###

print FILE "\\subsection{Depth-First Lexical Productions}\n\n";

foreach $rule (values %lexes) {
    if ($rule =~ m/^(.*):/) {
        $lex_cnt{$1} = 1;
        $lex_str{$1} = $rule;
    }
}

foreach $rule (values %lexes) {
    get_used_prefixes($rule);
    @prefixes = split /\ /, $rule;
    foreach $prefix (@prefixes) {
        if ($lex_cnt{$prefix} >= 1) {
            $lex_cnt{$prefix} += 1;
        }
    }
}

foreach $prefix (reverse sort keys %lex_cnt) {
    if ($lex_cnt{$prefix} == 1) {
        push(@stack, $prefix);
    }
}

do {
    $prefix = pop @stack;
    $rule = $lex_str{$prefix};
    print FILE "\\begin{syntax}\n";
    print FILE "$rule";
    print FILE "\\end{syntax}\n\n";
    get_used_prefixes($rule);
    @next_prefixes = reverse split /\ /, $rule;
    foreach $next_prefix (@next_prefixes) {
        if ($lex_cnt{$next_prefix} > 1) {
            $lex_cnt{$next_prefix} = 1;
            push @stack, $next_prefix;
        }
    }
} while ($#stack >= 0);

###
### print syntax rules in depth-first order
###

print FILE "\\subsection{Depth-First Syntax Productions}\n\n";

foreach $rule (values %rules) {
    if ($rule =~ m/^(.*):/) {
        $syn_cnt{$1} = 2;
        $syn_str{$1} = $rule;
    }
}

push @stack, "module-declaration-statement";

do {
    $prefix = pop @stack;
    $rule = $syn_str{$prefix};
    print FILE "\\begin{syntax}\n";
    print FILE "$rule";
    print FILE "\\end{syntax}\n\n";
    get_used_prefixes($rule);
    @next_prefixes = reverse split /\ /, $rule;
    foreach $next_prefix (@next_prefixes) {
        if ($syn_cnt{$next_prefix} > 1) {
            $syn_cnt{$next_prefix} = 1;
            push @stack, $next_prefix;
        }
    }
} while ($#stack >= 0);

foreach $prefix (keys %syn_cnt) {
    if ($syn_cnt{$prefix} == 2) {
        print "error: unreachable: $prefix\n";
    }
}

close FILE;


#$rule = "module-declaration-statement";

#foreach $prefix (sort keys %counts) {
#    $counts{$prefix} = 1;
#}

#do {
    
#    push(@stack, 
#} while $#stack > 0;
