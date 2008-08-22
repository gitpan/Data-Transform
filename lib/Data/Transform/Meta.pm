package Data::Transform::Meta;

sub new {
   my ($type, $data) = @_;

   my $self = { };
   $self->{data} = $data if (defined $data);

   return bless $self, $type
}

sub data {
   my $self = shift;

   return $self->{data};
}

package Data::Transform::Meta::SENDBACK;
use base qw(Data::Transform::Meta);

package Data::Transform::Meta::EOF;
use base qw(Data::Transform::Meta);

package Data::Transform::Meta::Error;
use base qw(Data::Transform::Meta);

1;
