package App::ConsistentRandomPassword;

use 5.010;
use strict;
use warnings;

our $VERSION='1.000';
# ABSTRACT: Create consistent random passwords

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

    my $matched = {};
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
        return {
            entropy => 'none',
            sites   => [],
        };
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
        if ( my $count = $matched->{with_path} ) {
            my @path = split( /\//, $uri->path, $count + 2 );
            if ( @path > $count + 1 ) {
                my $discard = pop(@path);
            }
            my $path = join( '/', @path );
            $target .= $path;
        }
        if ($matched->{main_domain}) {
            $target=~s/^[^\.]+\.//;
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

sub site_from_firefox {
    my $site;
    my $ffdir = dir( File::HomeDir->my_home, '.mozilla/firefox' );
    return unless -d $ffdir;
    while ( my $thing = $ffdir->next ) {
        if ( $thing->is_dir && $thing->basename =~ /\.default$/ ) {
            my $storefile = $thing->file('sessionstore-backups/recovery.js');
            my $data      = decode_json( $storefile->slurp );
            my $window    = $data->{selectedWindow} - 1;
            my $active    = $data->{windows}[$window]{selected} - 1;
            my $index = $data->{windows}[$window]{tabs}[$active]{index} - 1;
            my $current =
                $data->{windows}[$window]{tabs}[$active]{entries}[$index]
                {url};
            return $current if $current;
        }
    }
}

1;
