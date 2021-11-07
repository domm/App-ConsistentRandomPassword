use strict;
use warnings;

use Test::Most;
use File::HomeDir::Test;
use App::ConsistentRandomPassword;

my $pwd = App::ConsistentRandomPassword
      ->new({ site=> 'https://example.com' })
      ->password( 'hunter2' );

my $pwd_again = App::ConsistentRandomPassword
      ->new({ site=> 'https://example.com/foo.html' })
      ->password( 'hunter2' );

is($pwd, $pwd_again, 'passwords match');

my $pwd_wrong = App::ConsistentRandomPassword
      ->new({ site=> 'https://example.com' })
      ->password( 'hunter21' );
isnt($pwd, $pwd_wrong, 'wrong passwords doesnt match');

done_testing();
