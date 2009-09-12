package Protocol::Modbus::Request;

use strict;
use warnings;
use overload '""' => \&stringify;
use overload 'eq' => \&equals;

sub equals
{
    my($x, $y) = @_;
    $x->stringify() eq $y->stringify();  # or "$x" == "$y"
}

sub new
{
    my($obj, %args) = @_;
    my $class = ref($obj) || $obj;
    my $self = { _options => { %args }
               };
    bless $self, $class;
}

sub stringify
{
    my $self  = shift;
    my $frame = $self->frame();
    my $str   = 'Modbus Request  [' . uc(unpack('H*', $frame)) . ']';
    return( $str );
}


# get/set frame - the whole request message
sub frame
{
    my $self = shift;
    if( @_ )
    {
        $self->{_options}->{frame} = $_[0];
    }
    return( $self->{_options}->{frame} || '' );
}


# get/set request additional header (for TCP/IP, RTU protocol flavours)
sub header
{
    my $self = shift;
    if( @_ )
    {
        $self->{_header} = $_[0];
    }
    return( $self->{_header} || '' );
}


sub pdu
{
    my $self = shift;

    my $pdu;

    if( exists( $self->{_pdu} ) )
    {
        return($self->{_pdu})
    }
    else
    {
        my @struct = $self->structure();
        my $args   = $self->options();
        my $func   = $self->function();
        my $pdu    = pack('C', $func);  # PDU starts with function type

        if( @struct )
        {
            for(@struct)
            {
                my $ptype = $_;
                my($pname, $pbytes, $pformat) = @{ &Protocol::Modbus::PARAM_SPEC->[$ptype] };
                #warn('adding ', $pname, '(', $args->{$pname},') for ', $pbytes, ' bytes with pack format (', $pformat, ')');
                $pdu .= pack($pformat, $args->{$pname});
            }
        }
        else
        {
            $pdu = '';   # if no parameters required
        }
        $self->{_pdu} = $pdu; # probably best not to call this function recursively
    }

    return($pdu);
}


# get/set request additional trailer (for RTU)
sub trailer
{
    my $self = shift;
    if( @_ )
    {
        $self->{_trailer} = $_[0];
    }
    return( $self->{_trailer} || '' );
}


# given function code, return its structure (parameters)
sub structure
{
    my $self   = shift;
    my $func   = $self->function();
    my @params = ();

    # Multiple read requests
    if( $func == &Protocol::Modbus::FUNC_READ_COILS           ||
        $func == &Protocol::Modbus::FUNC_READ_INPUTS          ||
        $func == &Protocol::Modbus::FUNC_READ_HOLD_REGISTERS  ||
        $func == &Protocol::Modbus::FUNC_READ_INPUT_REGISTERS )
    {
        @params = ( &Protocol::Modbus::PARAM_ADDRESS,
                    &Protocol::Modbus::PARAM_QUANTITY
                  );
    }

    # Single write requests
    elsif( $func == &Protocol::Modbus::FUNC_WRITE_COIL )
    {
        @params = ( &Protocol::Modbus::PARAM_ADDRESS,
                    &Protocol::Modbus::PARAM_VALUE,
                  );
    }

    # Single write of register
    elsif( $func == &Protocol::Modbus::FUNC_WRITE_REGISTER )
    {
        @params = ( &Protocol::Modbus::PARAM_ADDRESS,
                    &Protocol::Modbus::PARAM_VALUE,
                  );
    }
    else
    {
        warn("UNIMPLEMENTED REQUEST FUNC $func");
    }

    return(@params);
}


sub function
{
    my $self = shift;
    return( $self->{_options}->{function} );
}


sub options
{
    my $self = shift;
    return( $self->{_options} );
}


# Get/set the PDU address for the request
sub address
{
    my $self = shift;
    if( @_ )
    {
        $self->{_options}->{address} = $_[0];
    }
    return( $self->{_options}->{address} );
}


# Get/set the no of PDUs for the request
sub quantity
{
    my $self = shift;
    if( @_ )
    {
        $self->{_options}->{quantity} = $_[0];
    }
    return( $self->{_options}->{quantity} );
}


# Get/set the unit address for the request
sub unit
{
    my $self = shift;
    if( @_ )
    {
        $self->{_options}->{unit} = $_[0];
    }
    return( $self->{_options}->{unit} );
}


# get/set the length of data sent in the request
sub len
{
    my $self = shift;
    if( @_ )
    {
        $self->{_options}->{len} = $_[0];
    }
    return( $self->{_options}->{len} );
}


1;
