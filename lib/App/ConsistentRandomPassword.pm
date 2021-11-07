package App::ConsistentRandomPassword;

use 5.010;
use strict;
use warnings;

# ABSTRACT: Create consistent random passwords

# VERSION

use Digest::SHA1 qw(sha1_hex);
use Data::Random qw(:all);
use URI;
use JSON qw(decode_json);
use File::HomeDir;
use Path::Class;

use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw(site global_entropy sites base));

sub password {
    my ( $self, $key ) = @_;
    my $match = $self->match_site;
    $self->prepare_seed( $match, $key );
    return $self->get_pwd($match);
}

sub match_site {
    my ($self) = @_;

    my $site  = $self->site;
    my $sites = $self->get_config;

    foreach my $c (@$sites) {
        my $match = $c->{match};
        my $rx    = qr/$match/;
        if ( $site =~ /$rx/ ) {
            return $c;
        }
    }
    return {};
}

sub get_config {
    my $self = shift;

    my $file = file( File::HomeDir->my_home, '.crp.json' );
    unless ( -e $file ) {
        say "No config found at $file, you might want to set one up...";
        return [{
            match   => ".*",
        }];
    }
    my $json = $file->slurp;
    my $sites = decode_json($json);

    $self->sites($sites);

    my $global_entropy = file( File::HomeDir->my_home, '.crp.entropy' );
    if ( -e $global_entropy ) {
        my $entropy = $global_entropy->slurp;
        $self->global_entropy($entropy);
    }
    else {
        say "You should set up a global entropy file at $global_entropy";
    }

    return $sites;
}

sub prepare_seed {
    my ( $self, $matched, $key ) = @_;

    my $target;
    if ( $matched->{no_uri} ) {
        $target = $self->site;
    }
    else {
        my $uri = URI->new( $self->site );
        $target = $uri->host;
        $target =~ s/^www\.//;

        if ($matched->{main_domain}) {
            $target=~/([\w-]+\.[\w]+)$/;
            if (my $main = $1) {
                $target = $main;
            }
        }

        if ( $uri->port != 80 && $uri->port != 443 ) {
            $target.=":".$uri->port;
        }

        if ( my $count = $matched->{with_path} ) {
            my @path = split( /\//, $uri->path, $count + 2 );
            if ( @path > $count + 1 ) {
                my $discard = pop(@path);
            }
            my $path = join( '/', @path ) if $path[1];
            $target .= $path if $path;
        }
    }

    $self->base($target);
    my @data = ( $target, $key );
    push( @data, $self->global_entropy ) if $self->global_entropy;
    push( @data, $matched->{entropy} )   if $matched->{entropy};

    my $hex          = sha1_hex(@data);
    my $prepare_seed = substr( $hex, 0, 8 );
    my $seed         = hex($prepare_seed);
    srand($seed);
    return;
}

sub get_pwd {
    my ( $self, $matched ) = @_;
    my $pwd;
    if ( ref( $matched->{method} ) eq 'ARRAY' ) {
        foreach my $method ( @{ $matched->{method} } ) {
            $pwd .= $self->make_pwd( $method, $matched );
        }
    }
    else {
        $pwd = $self->make_pwd( $matched->{method}, $matched );
    }
    return $pwd;
}

sub make_pwd {
    my ( $self, $method, $matched ) = @_;
    $method ||= 'printable';
    my $size;
    if ( $method =~ /^(.*)\((\d+)\)$/ ) {
        $method = $1;
        $size   = $2;
    }

    $method = 'pwd_' . $method;
    return $self->$method( $matched, $size );
}

sub pwd_xkcd {
    my ( $self, $matched, $size ) = @_;
    $size ||= 4;

    return join( '', map { ucfirst($_) } rand_words( size => $size ) );
}

sub pwd_alphanumeric {
    my ( $self, $matched, $size ) = @_;
    $size ||= 16;

    return join( '', rand_chars( set => 'alphanumeric', size => $size ) );
}

sub pwd_mixed_case {
    my ( $self, $matched, $size ) = @_;
    $size ||= 16;

    return join( '',
        rand_chars( set => 'upperalpha', size => 1 ),
        rand_chars( set => 'loweralpha', size => $size - 1 ) );
}

sub pwd_printable {
    my ( $self, $matched, $size ) = @_;
    $size ||= 16;

    return join( '', rand_chars( set => 'all', size => $size ) );
}

sub pwd_number {
    my ( $self, $matched, $size ) = @_;
    $size ||= 16;

    return join( '', rand_chars( set => 'numeric', size => $size ) );
}

sub pwd_simple_nonletter {
    my ( $self, $matched, $size ) = @_;
    $size ||= 16;

    return join( '', rand_set( set => ['%','&','+',',','.', ':', ';', '=', '?', '_','(',')'], size => $size ) );

}

q{ listening to: Anna Mabo - Notre Dame };

=head1 SYNOPSIS

  say App::ConsistentRandomPassword
      ->new({ site=> 'https://example.com' })
      ->password( 'hunter2' );

  # or use the script included with this dist:
  ~# crp.pl https://example.com
  key: <ENTER YOUR SECRET>
  Your password for 'example.com' is ready to paste

=head1 DESCRIPTION

C<App::ConsistentRandomPassword> is a tool to create consistent but
random password, best suited to use for throwaway or other not
high-security accounts.

It works by combining the URL of the service you want to use, a
passphrase you have to enter, and optionally some more bits of
entropy, calculating a checksum out of this data and then initalizing
the random number generator with a seed based on that checksum. Then
it uses various methods to generate a new password, without storing
the password anywhere.

If you later need to re-generate the password, run the algorithm again
on the same input, and you'll get the same password.

C<App::ConsistentRandomPassword> uses a config file (F<.crp.json>)
where you can fine-tune how the passwords for different sites should
be generated. You can combine 6 different password generators, ignore
subdomains (so C<foo.example.com> and C<bar.example.com> have the same
password), include paths (so C<example.com/foo> and C<example.com/bar>
have different passwords) and even base the password on something
that's not an URI.

=head2 Password generators

=head3 xkcd

=head3 alphanumeric

=head3 mixed_case

=head3 printable

=head3 number

=head3 simple_nonletter

=head2 Configuration Files

=head3 crp.json

=head4 match

=head4 method

=head4 entropy

=head4 with_path

=head4 main_domain

=head4 no_uri

=head3 crp.entropy

=head1 THANKS

Thanks to

=over

=item * <Paul Cochrane|https://github.com/paultcochrane> for various cleanup pull requests

=back
