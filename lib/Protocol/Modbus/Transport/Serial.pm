# $Id: Serial.pm,v 1.2 2007/08/25 20:12:25 cosimo Exp $

package Protocol::Modbus::Transport::Serial;

use strict;
use base 'Protocol::Modbus::Transport';
use Carp ();

use vars qw($OS_win $has_serialport $stty_path);

BEGIN
{
    # Taken from SerialPort/eg/any_os.plx

    # We try to use Device::SerialPort or Win32::SerialPort, if it's
    # not Windows and there's no Device::SerialPort installed,
    # then we just use the FileHandle module that comes with Perl.

    $OS_win = ($^O eq "MSWin32") ? 1 : 0;

    if( $OS_win )
    {
        eval "use Win32::API";
        die "Must have Win32::API correctly installed: $@\n" if ($@);
        eval "use Win32API::CommPort qw( :STAT :PARAM 0.17 )";
        die "Must have Win32::CommPort correctly installed: $@\n" if ($@);
        eval "use Win32::SerialPort";
        die "Must have Win32::SerialPort correctly installed: $@\n" if ($@);
        $has_serialport++;
    }
    elsif( eval q{ use Device::SerialPort; 1 } )
    {
        $has_serialport++;
    }
    elsif( eval q{ use POSIX qw(:termios_h); use FileHandle; 1} )
    {
        # NOP
    }
    elsif( -x "/bin/stty" )
    {
        $stty_path = "/bin/stty";
    }
    else
    {
        die "Missing either POSIX, FileHandle, Device::SerialPort or /bin/stty";
    }
}   # End BEGIN


sub connect
{
    my $self = shift;
    my $comm;
    my $opt = $self->options();

    if( ! exists( $opt->{port} ) || ! $opt->{port} )
    {
        croak('Modbus Serial transport error: no \'port\' parameter supplied.');
    }

    if( ! $self->connected )
    {
        if( $OS_win || $has_serialport )
        {
            $comm = $self->serialport_connect;
        }
        elsif( defined($stty_path) )
        {
            $comm = $self->stty_connect;
        }
        else
        {
            $comm = $self->unix_connect;
        }

        if( ! $comm )
        {
            Carp::croak('Modbus Serial transport error: can\'t connect to Modbus server on port ' . $opt->{port});
            return(0);
        }

        # Store socket handle inside object
        $self->{_handle} = $comm;
    }
    else
    {
        $comm = $self->{_handle};
    }

    return($comm ? 1 : 0);
}


sub serialport_connect
{
    my $self   = shift;
    my $opt    = $self->options();

    my $port   = $opt->{'port'};
    my $baud   = $opt->{'baud'};
    my $parity = $opt->{'parity'};
    my $comm   =    ( $OS_win ? Win32::SerialPort->new( $port ) : Device::SerialPort->new( $port ) )
                 or Carp::croak( "Modbus Serial transport error: can\'t open port $port: $^E\n" );

    $comm->baudrate( $baud || 9600 );
    $comm->parity('none');
    $comm->parity_enable(0);
    $comm->databits(8);
    # if no parity then spec requires two stop bits
    $comm->stopbits( ( $parity eq 'none' ) ? 2 : 1 );
    $comm->handshake('none');
    $comm->read_interval(5) if $OS_win;
    $comm->buffers(4096, 4096) if $OS_win;

    $comm->write_settings || die "Unable to write settings to serial port $port\n";

    # The API resets errors when reading status
    # $LatchErrorFlags is all $ErrorFlags seen since the last reset_error
    my( $BlockingFlags, $InBytes, $OutBytes, $LatchErrorFlags ) = $comm->status
        or warn "Can't read port $port status\n";
    if( $BlockingFlags )               { warn "Port $port is blocked.\n"; }
    if( $BlockingFlags & BM_fCtsHold ) { warn "Waiting for CTS on port $port.\n"; }
    if( $LatchErrorFlags & CE_FRAME )  { warn "Framing Error on port $port.\n"; }

    $self->{serialtype} = 'SerialPort';

    # Purge RX/TX buffers
    $comm->lookclear();

    return( $comm );
}


sub unix_connect
{
    # This was adapted from a script on connecting to a sony DSS, credits to its author (lost his email)
    my $self   = shift;
    my $opt    = $self->options();

    my $port   = $opt->{'port'};
    my $baud   = $opt->{'baud'};
#    my $parity = $opt->{'parity'};
    my($termios, $cflag, $lflag, $iflag, $oflag, $voice);

    my $serial = new FileHandle("+>$port")
                 or Carp::croak( "Modbus UNIX Serial transport error: can\'t open port $port: $^E\n" );

    $termios   = POSIX::Termios->new();
    $termios->getattr($serial->fileno()) || die "getattr: $!\n";
    $cflag = 0 | CS8() | CREAD() | CLOCAL();
    $lflag = 0;
    $iflag = 0 | IGNBRK() | IGNPAR();
    $oflag = 0;

    $termios->setcflag($cflag);
    $termios->setlflag($lflag);
    $termios->setiflag($iflag);
    $termios->setoflag($oflag);
    $termios->setattr($serial->fileno(), TCSANOW()) || die "setattr: $!\n";
    eval qq[ \$termios->setospeed(POSIX::B$baud) || die "setospeed: \$!\n";
             \$termios->setispeed(POSIX::B$baud) || die "setispeed: \$!\n";
           ];

    die $@ if $@;

    $termios->setattr($serial->fileno(),TCSANOW()) || die "setattr: $!\n";

    $termios->getattr($serial->fileno()) || die "getattr: $!\n";
    for( 0..NCCS() )
    {
        if( $_ == NCCS() )
        {
            last;
        }
        if( $_ == VSTART() || $_ == VSTOP() )
        {
            next;
        }
        $termios->setcc($_, 0);
    }
    $termios->setattr($serial->fileno(), TCSANOW()) || die "setattr: $!\n";

    $self->{serialtype} = 'FileHandle';

    # Purge RX/TX buffers
    $serial->purge_all();

    return( $serial );
}


sub stty_connect
{
    my $self = shift;
    my $opt    = $self->options();

    my $port   = $opt->{'port'};
    my $baud   = $opt->{'baud'};
#    my $parity = $opt->{'parity'};
    my($termios, $cflag, $lflag, $iflag, $oflag, $voice);

    if( $^O eq 'freebsd' )
    {
        my $cc = join(" ", map { "$_ undef" } qw(eof eol eol2 erase erase2 werase kill quit susp dsusp lnext reprint status));
        system("$stty_path <$port cs8 cread clocal ignbrk ignpar ospeed $baud ispeed $baud $cc");
        warn "$stty_path failed" if $?;
        system("$stty_path <$port -e");
    }
    else # linux
    {
        my $cc = join(" ", map { "$_ undef" } qw(eof eol eol2 erase werase kill intr quit susp start stop lnext rprnt flush));
        system("$stty_path <$port cs8 clocal -hupcl ignbrk ignpar ispeed $baud ospeed $baud $cc");
        die "$stty_path failed" if $?;
        system("$stty_path <$port -a");
    }

    open(FH, "+>$port") or die "Could not open $port: $!\n";
    $self->{serialtype} = 'FileHandle';

    # Purge RX/TX buffers
    FH->purge_all();

    return( \*FH );
}


sub connected
{
    my $self = shift;

    return $self->{_handle};
}


# Send request object
sub send
{
    my($self, $req) = @_;

    my $comm = $self->{_handle};
    return undef unless $comm;

    # Send request PDU
    my $countOut = $comm->write($req->frame());
    #print "Sent: $req length $countOut\n";
    # Wait 100mS
    select(undef, undef, undef, 0.10);

    return($countOut);
}


sub receive
{
    my($self, $req) = @_;

    # Get port channel
    my $comm = $self->{_handle};
    my $countIn;
    my $dataIn;
    ($countIn, $dataIn) = $comm->read(256);    # = hdr + max PDU size for Modbus is 253 bytes + crc
    #print 'Rcvd: [' . uc(unpack('H*', $dataIn)) . "] length $countIn\n";

    return($countIn, $dataIn);
}


sub disconnect
{
    my $self = shift;

    my $comm = $self->{_handle};
    return unless $comm;
    $comm->close();
    undef $comm;
}

1;
