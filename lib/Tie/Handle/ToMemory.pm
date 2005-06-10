package Tie::Handle::ToMemory;
use 5.004;
use strict;
# use warnings; # Not available before 5.6
use vars qw($VERSION);
$VERSION = "0.12";

# Required modules
use Carp;

#--------------------------------------------------------------------------#
# main pod documentation 
#--------------------------------------------------------------------------#

=head1 NAME

Tie::Handle::ToMemory - Print to or read from a scalar in memory

=head1 SYNOPSIS

  use Tie::Handle::ToMemory;
  my $data;

  # new returns a reference to an anonymous filehandle linked to memory
  my $fh = Tie::Handle::ToMemory->new( \$data );
  print $fh "winds up in memory";  # $data eq "winds up in memory"
  my $line = <$fh>;                # $line eq "winds up in memory"

  # tie links a specific handle to memory
  my $tied = tie *FH, 'Tie::Handle::ToMemory', \$data;
  print FH "blessed reference";    # $$tied eq "blessed reference"
  
  # same thing, but using anonymous scalars
  $fh = Tie::Handle::ToMemory->new();
  $tied = tie *FH, 'Tie::Handle::ToMemory';
  
=head1 DESCRIPTION

As of Perl 5.8, filehandles can be opened to "in memory" files held in
ordinary scalars.  This module provides a similar capability that is
backwards compatible by using tied filehandles.

The scalar is treated as a FIFO communication stream.  New data printed to the
handle is appended.  Data read from the handle is removed from the beginning.

=head1 USAGE


=over

=cut

#--------------------------------------------------------------------------#
# new()
#--------------------------------------------------------------------------#

=item new

 my $data;
 my $fh1 = Tie::Handle::ToMemory->new();
 my $fh2 = Tie::Handle::ToMemory->new( \$data );
 my $fh3 = Tie::Handle::ToMemory->new( $data );
 my $fh3 = Tie::Handle::ToMemory->new( "initial contents" );
 ${tied(*$fh3)} = "new contents"; # access the underlying scalar directly
 
Unlike an ordinary constructor, this returns a reference to the anonymous tied
filehandle, not the underlying tied object.  This reference can be used
directly with print() and similar functions.  With no argument, this function
ties the filehandle to an anonymous scalar.  If provided with a scalar or
scalar reference argument, the filehandle prints to and reads from that scalar.
If if a string literal is provided as an argument, the filehandle is tied to an
anonymous scalar containing the contents of the string.

=cut

sub new {
    my $pkg = shift;
    my $handle = \do {local *HANDLE};
    tie *{$handle}, $pkg, @_; 
    return $handle;
}


#--------------------------------------------------------------------------#
# TIEHANDLE()
#--------------------------------------------------------------------------#

=item TIEHANDLE classname, LIST

 my $data;
 my $tied1 = tie *FH, 'Tie::Handle::ToMemory', \$data;
 my $tied2 = tie *FH, 'Tie::Handle::ToMemory', $data;
 my $tied3 = tie *FH, 'Tie::Handle::ToMemory', "initial contents";
 $$tied3 = "new contents"; # access the underlying scalar directly
 
TIEHANDLE is called when tying to a specific filehandle.  Only the
first argument of the list is used and follows the same rules as with
C<new>, above.  The blessed object returned is a reference to the
scalar which holds the underlying data.

=back

=cut

# Note: if passed an array, it will flatten and this will use the first element

sub TIEHANDLE($;$) {
    my $pkg = shift;
    my $ref;
    if ( @_ == 0 ) {
        $ref = \( my $data );
    } elsif ( ref($_[0]) eq 'SCALAR') { 
        $ref = $_[0];
    } elsif ( ref(\$_[0]) eq 'SCALAR') { 
        $ref = \$_[0];
    } else {
        croak "Argument to TIEHANDLE must be a scalar or scalar reference";
    }
    $$ref = '' unless defined $$ref;
    bless( $ref, $pkg );
}

=pod

The following tying functions have been implemented. See C<perldoc -f tie>
and C<perldoc perltie> for more details.

=over

=cut

#--------------------------------------------------------------------------#
# WRITE()
#--------------------------------------------------------------------------#

=item WRITE this, scalar, length, offset

=cut

sub WRITE {
    my( $self, $buf, $len, $offset ) = @_;
    $$self .= substr( $buf, $offset, $len );
    return $len;
}

#--------------------------------------------------------------------------#
# PRINT()
#--------------------------------------------------------------------------#

=item PRINT this, LIST

=cut

sub PRINT {
    my $self = shift;
    my $buf = join(defined $, ? $, : "",@_);
    $buf .= $\ if defined $\;
    $self->WRITE($buf,length($buf),0);
}

#--------------------------------------------------------------------------#
# PRINTF()
#--------------------------------------------------------------------------#

=item PRINTF this, format, LIST

=cut

sub PRINTF {
    my $self = shift;
    my $buf = sprintf(shift,@_);
    $self->WRITE($buf,length($buf),0);
}

#--------------------------------------------------------------------------#
# READ()
#--------------------------------------------------------------------------#

=item READ this, scalar, length, offset

=cut

sub READ {
    my $self = shift;
    my $bufref = \$_[0];
    my (undef, $len, $offset) = @_;
     
    $len ||= 0;
    unless ( $len && length $$self ) {
        $$bufref = "";
        return 0;
    }

    $$bufref ||= "";
    $offset ||= 0;
    $len = $len < length $$self ? $len : length $$self;
    my $pos;
    if    ( $offset > 0 ) { $pos = $offset; } 
    elsif ( $offset < 0 ) {
        $pos = length($$bufref) + $offset;
        $pos = 0 if $pos < 0;
    } else { $pos = 0; }

    my $pad = $pos + $len - length $$bufref;
    $$bufref .= "\0" x $pad if ( $pad > 0 );
    $$bufref = substr($$bufref,0,$pos+$len);
    
    substr($$bufref,$pos,$len) = substr($$self,0,$len);
    $$self = substr($$self,$len);
    
    return $len;
}

#--------------------------------------------------------------------------#
# GETC()
#--------------------------------------------------------------------------#

=item GETC this

=cut

sub GETC {
    my $self = shift;
    my $buf;
    $self->READ($buf,1);
    return $buf;
}

#--------------------------------------------------------------------------#
# READLINE()
#--------------------------------------------------------------------------#

=item READLINE this

=cut

sub READLINE {
    my $self = shift;

    return undef unless length $$self;
    
    if ( wantarray() ) {
        my @lines = split( $/, $$self );
        $$self = "";
        return map { "$_$/" } @lines;
    }
    else {
        my $i = index( $$self, $/ ) - $[ + 1; # 1 based
        my $line;
        if ( $i == 0 || $i == length $$self ) { # whole line
            $line = $$self;
            $$self = "";
        } else {
            $line = substr( $$self, 0, $i );
            $$self = substr( $$self, $i ); # remember it's 1 based!
        }
        return $line;
    }
}

#--------------------------------------------------------------------------#
# EOF()
#--------------------------------------------------------------------------#

=item EOF this

Returns true if the underlying scalar is empty.

=cut

sub EOF {
	my $self = shift;
    return ($$self eq "");
}

#--------------------------------------------------------------------------#
# OPEN()
#--------------------------------------------------------------------------#

=item OPEN this, mode, LIST

This is a dummy function that always returns true.

=cut

sub OPEN { 1 }

#--------------------------------------------------------------------------#
# CLOSE()
#--------------------------------------------------------------------------#

=item CLOSE this

This is a dummy function that always returns true.

=cut

sub CLOSE { 1 }

#--------------------------------------------------------------------------#
# FILENO()
#--------------------------------------------------------------------------#

=item FILENO this

This is a dummy function that always returns true.

=cut

sub FILENO { 1 }

=back

The following functions have not been implemented.

=over

=item BINMODE this

=item SEEK this, position, whence

=item TELL this

=item DESTROY this

=item UNTIE this

=back

=cut

1; #this line is important and will help the module return a true value
__END__

=head1 INSTALLATION

The following commands will build, test, and install this module:

 perl Build.PL
 perl Build
 perl Build test
 perl Build install

=head1 BUGS

Please report bugs using the CPAN Request Tracker at 
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Tie-Handle-ToMemory

=head1 AUTHOR

David A Golden <dagolden@cpan.org>

http://dagolden.com/

=head1 COPYRIGHT

Copyright (c) 2005 by David A Golden

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

=over

=item *

L<perltie>

=back

=cut
