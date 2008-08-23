# vim: ts=2 sw=2 expandtab
package Data::Transform;
use strict;

use vars qw($VERSION);
$VERSION = '0.03_01';

use Carp qw(croak);
use Scalar::Util qw(blessed);
use Data::Transform::Meta;

=head1 NAME

Data::Transform - base class for protocol abstractions

=head1 DESCRIPTION

POE::Filter objects plug into the wheels and define how the data will
be serialized for writing and parsed after reading.  POE::Wheel
objects are responsible for moving data, and POE::Filter objects
define how the data should look.

POE::Filter objects are simple by design.  They do not use POE
internally, so they are limited to serialization and parsing.  This
may complicate implementation of certain protocols (like HTTP 1.x),
but it allows filters to be used in stand-alone programs.

Stand-alone use is very important.  It allows application developers
to create lightweight blocking libraries that may be used as simple
clients for POE servers.  POE::Component::IKC::ClientLite is a notable
example.  This lightweight, blocking event-passing client supports
thin clients for gridded POE applications.  The canonical use case is
to inject events into an IKC application or grid from CGI interfaces,
which require lightweight resource use.

POE filters and drivers pass data in array references.  This is
slightly awkward, but it minimizes the amount of data that must be
copied on Perl's stack.


=head1 PUBLIC INTERFACE

All Data::Transform classes must support the minimal interface,
defined here. Specific filters may implement and document additional
methods.

=cut

=head2 new PARAMETERS

new() creates and initializes a new filter.  Constructor parameters
vary from one Data::Transform subclass to the next, so please consult the
documentation for your desired filter.

=cut

sub new {
  my $type = shift;
  croak "$type is not meant to be used directly";
}

=head2 get_one_start ARRAYREF

get_one_start() accepts an array reference containing unprocessed
stream chunks.  The chunks are added to the filter's internal buffer
for parsing by get_one().

=cut

sub get_one_start {
  my ($self, $stream) = @_;

  push (@{$self->[0]}, @$stream);
}

=head2 get_one

get_one() parses zero or one complete item from the filter's internal
buffer.

get_one() is the lazy form of get(). It only parses only one item at
a time from the filter's buffer. This is vital for applications that
may switch filters in mid-stream, as it ensures that the right filter
is in use at any given time.

=cut

sub get_one {
  my $self = shift;

  if (my $val = $self->_handle_data) {
    return [ $val ];
  }
  return [ ] unless (@{$self->[0]});

  while (my $data = shift (@{$self->[0]})) {
    if (blessed $data and $data->isa('Data::Transform::Meta')) {
      return [ $data ];
    }
    my $ret = $self->_handle_data($data);
    if (defined $ret) {
      return [ $ret ];
    }
  }
  return [];
}

=head2 get ARRAYREF

get() is the greedy form of get_one().  It accepts an array reference
containing unprocessed stream chunks, and it adds that data to the
filter's internal buffer.  It then parses as many full items as
possible from the buffer and returns them in another array reference.
Any unprocessed data remains in the filter's buffer for the next call.

This should only be used if you don't care how long the processing takes.
Unless responsiveness doesn't matter for your application, you should
really be using get_one_start() and get_one().

=cut

sub get {
  my ($self, $stream) = @_;
  my @return;

  $self->get_one_start($stream);
  while (1) {
    my $next = $self->get_one();
    last unless @$next;
    push @return, @$next;
  }

  return \@return;
}

=head2 put ARRAYREF

put() serializes items into a stream of octets that may be written to
a file or sent across a socket.  It accepts a reference to a list of
items, and it returns a reference to a list of marshalled stream
chunks.  The number of output chunks is not necessarily related to the
number of input items.

=cut

=head2 meta

A flag method that always returns 1. This can be used in e.g. POE to check
if the class supports L<Data::Transform::Meta>, which all Data::Transform
subclasses should, but L<POE::Filter> classes don't. Doing it this way
instead of checking if a filter is a Data::Transform subclass allows for
yet another filters implementation that is meant to transparently replace
this to be used by POE without changes to POE.

=cut

sub meta {
  return 1;
}

=head2 clone

clone() creates and initializes a new filter based on the constructor
parameters of the existing one.  The new filter is a near-identical
copy, except that its buffers are empty.

=cut

sub clone {
  my $self = shift;
  my $type = ref $self;
  croak "$type has to implement a clone method";
}

=head2 get_pending

get_pending() returns any data remaining in a filter's input buffer.
The filter's input buffer is not cleared, however.  get_pending()
returns a list reference if there's any data, or undef if the filter
was empty.

Full items are serialized whole, so there is no corresponding "put"
buffer or accessor.

=cut

sub get_pending {
  my $self = shift;

  return [ @{$self->[0]} ] if @{$self->[0]};
  return undef;
}

=head1 IMPLEMENTORS NOTES

L<Data::Transform> implements part of the public API above to help
ensure uniform behaviour across all subclasses. Instead of overriding
the high-level methods from the public API and duplicating code, you
can implement the following methods, which are called by the
generic implementation.

=head2 _handle_data

=cut

sub _handle_data {
  my $self = shift;

  croak ref($self) . " must implement _handle_data";
}

=head1 SEE ALSO

L<Data::Transform> is based on L<POE::Filter>
L<POE::Wheel>
The SEE ALSO section in L<POE> contains a table of contents covering
the entire POE distribution.

=head1 BUGS

In theory, filters should be interchangeable.  In practice, stream and
block protocols tend to be incompatible.

=head1 LICENSE

Data::Transform is released under the GPL version 2.0 or higher.
See the file LICENCE for details.

=head1 AUTHORS

L<Data::Transform> is based on L<POE::Filter>, by Rocco Caputo. New
code in Data::Transform is copyright 2008 by Martijn van Beers  <martijn@cpan.org>

=cut

1;
