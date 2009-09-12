# $Id: Transaction.pm,v 1.2 2007/08/25 20:12:25 cosimo Exp $

package Protocol::Modbus::Transaction;

use strict;
use diagnostics;
use warnings;
use Carp;

use Data::Dumper;
use Protocol::Modbus::Request;
use Protocol::Modbus::Response;

# Define a progressive id
$Protocol::Modbus::Transaction::ID = 0;


sub new
{
    my($obj, %args) = @_;
    my $class = ref($obj) || $obj;
    my $self = { _request   => $args{request},
                 _response  => $args{response},
                 _protocol  => $args{protocol},
                 _transport => $args{transport},
                 _id        => Protocol::Modbus::Transaction::nextId(),
               };
    bless $self, $class;
}


# Get/set protocol class (Pure modbus or TCP modbus)
sub protocol
{
    my $self = shift;
    if( @_ )
    {
        $self->{_protocol} = $_[0];
    }
    return $self->{_protocol};
}


# Transport object (TCP or Serial)
sub transport
{
    my $self = shift;
    if( @_ )
    {
        $self->{_transport} = $_[0];
    }
    return $self->{_transport};
}


sub close
{
    my $self = shift;
    $self->transport->disconnect();
    $self->request(undef);
    $self->response(undef);
}


sub execute
{
    my $self = shift;
    my($req, $res);

    # must be connected to execute a transaction
    if( ! $self->transport->connect() )
    {
        croak('Modbus unable to connect with server');
        return(undef);
    }

    # must have a request object
    if( ! ($req = $self->request()) )
    {
        croak('No request PDU defined for Modbus transaction');
        return(undef);
    }

    # Send request
    my $countOut = $self->transport->send($req);
    $req->len( $countOut );
    print 'Sent: ', $req, ' request object length ', $req->len(), "\n";

    # Get a response
    my ($countIn, $raw_data) = $self->transport->receive($req);
    #warn('Rcvd: [', uc(unpack('H*', $raw_data)), '] data');

    # Init a response object with the data received by transport
    $res = Protocol::Modbus::Response->new( frame => $raw_data,
                                            len   => $countIn );

    # parse the response if data received
    print 'Rcvd: ', $res, ' response object length ', $res->len(), "\n";
    $res = $self->protocol->parseResponse($res) if $res->len();

    # Protocol (TCP/RTU) should now parse the response
    return( $res );
}


sub id
{
    my $self = shift;
    return $self->{_id};
}


sub nextId
{
    return($Protocol::Modbus::Transaction::ID++);
}


# Get/set request class
sub request
{
    my $self = shift;
    if( @_ )
    {
        $self->{_request} = $_[0];
    }
    return $self->{_request};
}

# Get/set response class
sub response
{
    my $self = shift;
    if( @_ )
    {
        $self->{_request} = $_[0];
    }
    return $self->{_request};
}


# convert transaction to string
sub stringify
{
    my $self = $_[0];
    my $str = "TrID: $self->id()\nSent: $self->request()\nRecv: $self->response()\n";
    return($str);
}

1;

__END__

=head1 NAME

Protocol::Modbus::Transaction - Modbus protocol request/response transaction

=head1 SYNOPSIS

  use Protocol::Modbus;

  # Initialize protocol object
  my $proto = Protocol::Modbus->new( driver=>'TCP' );

  # Get a request object
  my $req = $proto->request(
      function => Protocol::Modbus::FUNC_READ_COILS, # or 0x01
      address  => 0x1234,
      quantity => 1,
      unit     => 0x07, # Only has sense for Modbus/TCP
  );

  # Init transaction and execute it, obtaining a response
  my $trn = Protocol::Modbus::Transaction->new( request=>$req );
  my $res = $trn->execute();

  # Pretty-print response on stdout
  print $response . "\n";   # Modbus Response PDU(......)

  # ...
  # Parse response
  # ...

=head1 DESCRIPTION

Implements the basic Modbus transaction model, with request / response cycle.
Also responsible of raising exceptions (see C<Protocol::Modbus::Exception> class).

=head1 METHODS

=over +

=item protocol

Returns the protocol object in use. Should be an instance of
C<Protocol::Modbus> or its subclasses.

=item request

Get/set request object. Should be an instance of C<Protocol::Modbus::Request> class.

=item response

Get/set response object. Should be an instance of C<Protocol::Modbus::Response> class.

=item execute

Executes transaction, sending request to proper channel (depending on protocol at this time).
Returns a C<Protocol::Modbus::Response> object in case of successful transaction.
Returns a C<Protocol::Modbus::Exception> object in case of failure and exception raised.

=over

=head1 SEE ALSO

=over *

=item Protocol::Modbus::Exception

=back

=head1 AUTHOR

Cosimo Streppone, E<lt>cosimo@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Cosimo Streppone

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
