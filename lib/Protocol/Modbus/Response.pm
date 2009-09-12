package Protocol::Modbus::Response;

use strict;
use warnings;
use Carp;

use overload '""' => \&stringify;
use overload 'eq' => \&equals;

use Protocol::Modbus::Exception;

our @in = ();
our @coils = ();


sub equals
{
    my($x, $y) = @_;
    $x->stringify() eq $y->stringify();  # or "$x" == "$y"
}


#
# `frame' is required when calling constructor
#
sub new
{
    my($obj, %args) = @_;
    my $class = ref($obj) || $obj;

    $args{pdu} ||= $args{frame};

    my $self = { _options => { %args }
               };

    bless $self, $class;
}


sub stringify
{
    my $self  = $_[0];
    my $frame = $self->frame();
    my $func  = $self->function();
    my $cRes  = 'Modbus Generic Response';

    if( defined($frame) )
    {
        my $frameHex = uc( unpack('H*', $frame) );
        $cRes = "Modbus Response [$frameHex]";
        if( defined($func) )
        {
            $cRes .= " ($funcCodeRef->{$func})";
        }
    }
    return( $cRes );
}


# frame is the entire packet stream received from transport
sub frame
{
    my $self = shift;
    if( @_ )
    {
        $self->{_options}->{frame} = $_[0];
    }
    return( $self->{_options}->{frame} );
}


sub options
{
    my $self = shift;
    return( $self->{_options} );
}

# len is length of the data received
sub len
{
    my $self = shift;
    if( @_ )
    {
        $self->{_options}->{len} = $_[0];
    }
    return( $self->{_options}->{len} );
}


# unit is the address at the head of the response
sub unit
{
    my $self = shift;
    if( @_ )
    {
        $self->{_options}->{unit} = $_[0];
    }
    return( $self->{_options}->{unit} );
}


# PDU is the "Pure" Modbus packet without transport headers
sub pdu
{
    my $self = shift;
    if( @_ )
    {
        $self->{_options}->{pdu} = $_[0];
    }
    return( exists($self->{_options}->{pdu}) ? $self->{_options}->{pdu} : undef );
}


# func is the received function type
sub function
{
    my $self = shift;
    if( @_ )
    {
        $self->{_options}->{_function} = $_[0];
    }
    return( exists($self->{_options}->{_function}) ? $self->{_options}->{_function} : undef );
}


# output address written to
sub address
{
    my $self = shift;
    if( @_ )
    {
        $self->{_options}->{_address} = $_[0];
    }
    return( $self->{_options}->{_address} );
}


# value of the received data
sub value
{
    my $self = shift;
    if( @_ )
    {
        $self->{_options}->{_value} = $_[0];
    }
    return( $self->{_options}->{_value} );
}


# CRC of the response
sub crc
{
    my $self = shift;
    if( @_ )
    {
        $self->{_options}->{_crc} = $_[0];
    }
    return( $self->{_options}->{_crc} );
}


sub process
{
    my($self, $pdu) = @_;

    # If binary packets not supplied, take them from constructor options ('pdu')
    $pdu ||= $self->pdu();
    #warn('Parsing binary data [' . uc(unpack('H*', $pdu)) . ']');

    my $excep = 0;     # Modbus exception flag
    my $error = 0;     # Error in parsing response
    my $count = 0;     # How many bytes in response
    my @bytes = ();    # Hold response bytes

    # get function code (only first char)
    my $func = ord substr($pdu, 0, 1);

    # check if there was an exception (msb on)
    if( $func & 0x80 )
    {
        # Yes, exception for function $func - 0x80
        $func -= 0x80;
        $excep = ord substr($pdu, 1, 1);
    }

    # there was an exception response. Throw exception!
    if( $excep > 0 )
    {
        warn('Throw exception func=', $func, ' code=', $excep);
        return( throw Protocol::Modbus::Exception( function=>$func, code=>$excep ) );
    }

    # normal response - decode bytes that arrived
    if( $func == &Protocol::Modbus::FUNC_READ_COILS )
    {
        $self->function( $func );
        $count = ord substr($pdu, 1, 1);
        @bytes = split //, substr($pdu, 2);
        @coils = ();
        for(@bytes)
        {
            $_ = unpack('B*', $_);
            $_ = reverse;
            push @coils, split //;
        }
        $self->coils( \@coils );
    }
    elsif( $func == &Protocol::Modbus::FUNC_READ_INPUTS )
    {
        $self->function( $func );
        $count = ord substr($pdu, 1, 1);
        @bytes = split //, substr($pdu, 2);
        @in    = ();
        for(@bytes)
        {
            $_ = unpack('B*', $_);
            $_ = reverse;
            push @in, split //;
        }
        $self->inputs( \@in );
    }
    elsif(    $func == &Protocol::Modbus::FUNC_WRITE_COIL
           || $func == &Protocol::Modbus::FUNC_WRITE_REGISTER )
    {
        $self->function( $func );
        $self->address( unpack 'n', substr($pdu, 1, 2) );
        $self->value( unpack 'n', substr($pdu, 3, 2) );
    }
    elsif( $func == &Protocol::Modbus::FUNC_READ_HOLD_REGISTERS )
    {
        $self->function( $func );
        $count = ord substr($pdu, 1, 1);
        @bytes = split //, substr($pdu, 2);
        @in    = ();
        for(@bytes)
        {
            push @in, unpack('H*', $_);
        }
        $self->registers( \@in );
    }
    return($self);
}


sub coils
{
    return( $_[0]->{_coils} );
}


sub inputs
{
    my $self = shift;
    if( @_ )
    {
        $self->{_inputs} = $_[0];
    }
    return( $self->{_inputs} );
}


sub registers
{
    my $self = shift;
    if( @_ )
    {
        $self->{_registers} = $_[0];
    }
    return( $self->{_registers} );
}


# given function code, return response structure
sub structure
{
    my($self, $func) = @_;
    my @tokens = ();

    if(    $func == &Protocol::Modbus::FUNC_READ_COILS
        || $func == &Protocol::Modbus::FUNC_READ_INPUTS )
    {
        @tokens = ( &Protocol::Modbus::PARAM_COUNT,
                    &Protocol::Modbus::PARAM_STATUS_LIST,
                  );
    }
    elsif(    $func == &Protocol::Modbus::FUNC_READ_HOLD_REGISTERS
           || $func == &Protocol::Modbus::FUNC_READ_INPUT_REGISTERS )
    {
        @tokens = ( &Protocol::Modbus::PARAM_COUNT,
                    &Protocol::Modbus::PARAM_REGISTER_LIST,
                  );
    }
    else
    {
        croak('UNIMPLEMENTED RESPONSE FUNC $func');
    }

    return( @tokens );
}

1;

