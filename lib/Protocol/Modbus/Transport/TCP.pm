# $Id: TCP.pm,v 1.2 2007/08/25 20:12:25 cosimo Exp $

package Protocol::Modbus::Transport::TCP;

use strict;
use warnings;
use base 'Protocol::Modbus::Transport';
use Carp ();
use IO::Socket::INET;

sub connect
{
    my $self = $_[0];
    my $sock;
    my $opt = $self->options();

    if( ! $self->connected() )
    {
        $sock = IO::Socket::INET->new(
            PeerAddr => $opt->{address},
            PeerPort => $opt->{port}    || 502,
            Timeout  => $opt->{timeout} || 3,
        );

        if( ! $sock )
        {
            Carp::croak('Can\'t connect to Modbus server on ' . $opt->{address} . ':' . $opt->{port});
            return(0);
        }

        # Store socket handle inside object
        $self->{_handle} = $sock;

    }
    else
    {
        $sock = $self->{_handle};
    }

    return($sock ? 1 : 0);
}

sub connected
{
    my $self = $_[0];
    return $self->{_handle};
}

# Send request object
sub send
{
    my($self, $req) = @_;

    my $sock = $self->{_handle};
    return undef unless $sock;

    # Send request PDU and wait 100 msec
    my $ok = $sock->send($req->pdu());
    select(undef, undef, undef, 0.10);

    return($ok);
}

sub receive
{
    my($self, $req) = @_;

    # Get socket
    my $sock = $self->{_handle};

    $sock->recv(my $data, 100);
    #warn('Received: [' . unpack('H*', $data) . ']');

    return(length($data), $data);
}

sub disconnect
{
    my $self = $_[0];
    my $sock = $self->{_handle};
    return unless $sock;
    $sock->close();
}

1;
