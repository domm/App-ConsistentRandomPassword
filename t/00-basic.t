use strict;
use warnings;

use Test::More tests => 2;

require_ok('App::ConsistentRandomPassword');
ok(App::ConsistentRandomPassword->new(), 'Can instantiate CRP object');

# vim: expandtab shiftwidth=4
