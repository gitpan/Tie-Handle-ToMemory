#!/usr/bin/perl
use strict;
use warnings;
use blib;  

# Tie::Handle::ToMemory  

use Test::More 'no_plan'; # tests =>  2 ;
use Test::Exception;

#--------------------------------------------------------------------------#
# Object creation
#--------------------------------------------------------------------------#

use Tie::Handle::ToMemory;

my ($data2, $data3, $data6, $data7);
$data2 = $data3 = $data6 = $data7 = "start";

ok( my $fh1 = Tie::Handle::ToMemory->new(), 
    "new with no argument" );
ok( my $fh2 = Tie::Handle::ToMemory->new($data2), 
    "new with scalar" );
ok( my $fh3 = Tie::Handle::ToMemory->new(\$data3), 
    "new with scalar reference" );
ok( my $fh4 = Tie::Handle::ToMemory->new("start"), 
    "new with string literal argument" );
ok( my $obj5 = tie( *FH5, 'Tie::Handle::ToMemory'), 
    "tie with no argument");
ok( my $obj6 = tie( *FH6, 'Tie::Handle::ToMemory', $data6), 
    "tie with scalar argument");
ok( my $obj7 = tie( *FH7, 'Tie::Handle::ToMemory', \$data7), 
    "tie with scalar reference argument");
ok( my $obj8 = tie( *FH8, 'Tie::Handle::ToMemory', "start"), 
    "tie with string literal argument");

dies_ok { Tie::Handle::ToMemory->new([]) }
    "new should die when given a bad variable reference type";
dies_ok { local *FH8; tie( *FH8, 'Tie::Handle::ToMemory', []) }
    "tie should die when given a bad variable reference type";

#--------------------------------------------------------------------------#
# support functions and fixtures
#--------------------------------------------------------------------------#
    
my @fhs = \($fh1, $fh2, $fh3, $fh4, \*FH5, \*FH6, \*FH7, \*FH8);

my $phrase = "testing print";

sub _iterate(&) {
    my $code = shift;
    for (my $i = 1; $i <= @fhs; $i++) {
        local $_ = ${$fhs[$i-1]};
        $code->($i);
    }
}

sub _link_matches {
    my $text = shift;
    is( $data2, $text, 
        "handle 2 linked scalar contents match");
    is( $data3, $text, 
        "handle 3 linked scalar contents match");
    is( $data6, $text, 
        "handle 6 linked scalar contents match");
    is( $data7, $text, 
        "handle 7 linked scalar contents match");
}

sub _reset { _iterate { ${ tied *$_} = "" } };

#--------------------------------------------------------------------------#
# confirm all objects were properly blessed
#--------------------------------------------------------------------------#

_iterate {
    isa_ok(tied *$_, 'Tie::Handle::ToMemory', 
        "object $_[0]");
};

_iterate {
    is( ref($_), 'GLOB', "handle $_[0] is a typeglob reference");
};

#--------------------------------------------------------------------------#
# Checking initial states
#--------------------------------------------------------------------------#


_iterate {
    is( ${tied *{$_}}, ( $_ == $fh1 || $_ == \*FH5 ) ? "" : "start", 
        "object $_[0] expected starting contents found");
};

#--------------------------------------------------------------------------#
# Print
#--------------------------------------------------------------------------#

_reset;

_iterate {
    print $_ $phrase;
    is( ${ tied *$_ }, $phrase, 
        "handle $_[0] tied contents match after print");
};

_link_matches($phrase);

_reset;

_iterate {
    my @list = qw(red green blue);
    local $, = ", ";
    local $\ = ";\n";
    print $_ @list;
    is( ${ tied *$_ }, "red, green, blue;\n",
        "handle $_[0] print with \$, and \$\\ matches");
};

#--------------------------------------------------------------------------#
# Printf
#--------------------------------------------------------------------------#

_reset;

_iterate {
    printf $_ "%s", $phrase; 
    is( ${ tied *$_ }, $phrase, 
        "handle $_[0] tied contents match after printf");
};

_link_matches($phrase);

#--------------------------------------------------------------------------#
# eof
#--------------------------------------------------------------------------#

_reset;

ok( eof($fh1), "handle is EOF when empty");
print $fh1 "foo";
ok( !eof($fh1), "handle is not EOF when not empty");

#--------------------------------------------------------------------------#
# dummy functions
#--------------------------------------------------------------------------#

lives_ok { open *$fh1 } "handle open lives";
ok( open(*$fh1), "handle open returns success" );
lives_ok { fileno *$fh1 } "handle fileno lives";
ok( fileno(*$fh1), "handle fileno returns success" );
lives_ok { close *$fh1 } "handle close lives";
ok( close(*$fh1), "handle close returns success" );

#--------------------------------------------------------------------------#
# Read and getc
#--------------------------------------------------------------------------#

_reset;

print $fh1 "test line";
my $buf = "garbage";
my $num;
$num = read($fh1,$buf,0); # zero length and no offset
is( $buf, "", "handle read without length is empty string");
is( $num, 0, "handle read returns correct number of characters");
is( ${tied *$fh1}, "test line", "tied contents are correct after read");

$buf = "garbage";
$num = read($fh1, $buf, 5); # length, but no offset 
is( $buf, "test ", "handle read with length is correct");
is( $num, 5, "handle read returns correct number of characters");
is( ${tied *$fh1}, "line", "tied contents are correct after read");

$num = read($fh1, $buf, 4, 4); # length with offset
is( $buf, "testline", "handle read with length and offset is correct");
is( $num, 4, "handle read returns correct number of characters");
ok( eof(*$fh1), "handle should be empty" );

print $fh1 "test2";
$buf = "";
$num = read($fh1, $buf, 5, 2);
is( $buf, "\0\0test2", "handle read with offset past buffer is padded" );

ok( eof(*$fh1), "handle should be empty again" );
$num = read($fh1, $buf, 1);
is( $buf, "", "reading empty handle should truncate buffer string" );
is( $num, 0, "reading empty handle should return 0 characters read" );

print $fh1 "dog";
$buf = "big cat";
$num = read($fh1, $buf, 3, -3);
is( $buf, "big dog", "reading handle with negative offset is correct" );

print $fh1 "dog";
$buf = "big cat";
$num = read($fh1, $buf, 2, -10);
is( $buf, "do", 
    "reading handle with negative offset more than length is correct" );
$buf = getc($fh1);
is( $buf, "g", "getc on handle is correct");

print $fh1 "frog";
my $newbuf;
$num = read($fh1, $newbuf, 0);
is( $newbuf, "", "read with length zero sets buffer to empty string");
$num = read($fh1, $newbuf, undef);
is( $newbuf, "", "read with length 'undef' sets buffer to empty string");

#--------------------------------------------------------------------------#
# readline
#--------------------------------------------------------------------------#

_reset;

my @expected = ( "line 1\n", "line 2\n", "line 3\n" );

$buf = <$fh1>;
is( $buf, undef, "readline on empty handle returns undef");

print $fh1 "test";
$buf = <$fh1>;
is( $buf, "test", "readline in scalar context with no \\n works");

print $fh1 "\n";
$buf = <$fh1>;
is( $buf, "\n", "readline in scalar context with leading \\n works");

print $fh1 @expected;
my @lines = <$fh1>;
is_deeply( \@lines, \@expected,
    "readline in array context works");

print $fh1 @expected;
$buf = <$fh1>;
@lines = <$fh1>;
is( $buf, "line 1\n", 
    "mixing scalar and array context in readline - scalar part");
is_deeply( \@lines, [ @expected[1,2] ],
    "mixing scalar and array context in readline - array part");



