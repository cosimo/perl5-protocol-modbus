#
# Modbus/TCP-IP core tests
# Test the responses packet parsing
#
# 2007/01/31 Cosimo Streppone <cosimo@cpan.org>
#
# $Id: 015-Responses.t,v 1.2 2007/02/05 11:16:03 cosimo Exp $

use strict;
use warnings;
use Test::More;

BEGIN { plan tests => 3 }

use_ok('Protocol::Modbus');
use_ok('Protocol::Modbus::Response');

my $proto = Protocol::Modbus->new();
ok($proto, 'generic protocol object loaded');

