#!/home/domm/rakudo-star-2016.07/install/bin/perl6

use JSON::Tiny;
use Digest::MD5;
use URI;

use Inline::Perl5;

sub MAIN (Str $insite?) {
    my @sites = get_config_sites;
    my $global_entropy = get_config_entropy;

    my $site = $insite || get_site;
    my $match = match_site($site, @sites);

    my $normalized = normalize_site($site, $match);

    my $key = get_user_key($normalized);
    set_consistent_seed($normalized, $key);

    my $pwd = get_password($match);
    say $pwd;

}

sub get_site {
    # TODO get site from firefox

    my $site = prompt "site: ";
    return $site;
}

sub get_config_sites {
    my $json = '/home/domm/.crp.json'.IO.slurp;
    my @sites = from-json($json);
    return @sites;
}

sub get_config_entropy {
    return '/home/domm/.crp.entropy'.IO.slurp;
}

sub match_site(Str $site, @sites) {
    for @sites -> $cand {
        my $try = $cand<match>;
        # TODO rx/$try/
        if $site ~~ m / $try / {
            return $cand;
        }
    }
    return {};
}

sub normalize_site(Str $site, Hash $match) {
    return $site if $match<no_uri>;

    my URI $uri .= new($site);
    my $normalized = $uri.host;
    $normalized ~~ s/^www\.//;

    if $match<main_domain> {
        if $normalized ~~ /(<[\w-]>+\.<[\w]>+)$/ {
            $normalized = $0.Str;
        }
    }

    if $uri.port != 80 | 443 {
        $normalized ~= ':' ~ $uri.port;
    }

    if $match<with_path> -> $count {
        my @path = comb(/<-[\/]>+/,$uri.path,$count);
        $normalized ~= '/' ~ @path.join('/');
    }

    return $normalized;
}

sub get_user_key(Str $site) {
    # Terminal::Readsecret ?

    my $key = prompt "Please enter key for $site: ";
    return $key;

}

sub set_consistent_seed(Str $site, Str $key, Str $global_entropy?, Str $match_entropy?) {
    my $d = Digest::MD5.new;
    my @data = ($site, $key);
    @data.push($global_entropy) if $global_entropy;
    @data.push($match_entropy) if $match_entropy;
    my $hex = $d.md5_buf(@data);
    # TODO how ?? my $int = $hex.base(10);
    # say substr($hex,0,8).base(10);
    #srand(substr($hex,0,8).base(10));
    srand(1);
}

sub get_password(Hash $match) {

    given $match<method>.WHAT {
        when Array {
            my $pwd;
            for $match.<method>.values -> $m {
                $pwd ~= make_pwd($m);
            }
            return $pwd;
        }
        when Str {
            return make_pwd($match<method>);
        }
        default {
            return make_pwd('printable');
        }
    }
}

sub make_pwd(Str $definition) {
    my $generator = $definition;
    my $size;
    if $definition ~~ /^(.*)\((\d+)\)$/ {
        $generator = $0;
        $size= $1.Str.Int;
    }
    given $generator {
        when 'xkcd' { return pwd_xkcd }
        when 'alphanumeric' { return pwd_alphanumeric($size) }
        when 'mixed_case' { return pwd_mixed_case($size) }
        when 'printable' { return  pwd_printable($size) }
        when 'number' { return  pwd_number($size) }
        when 'simple_nonletter' { return pwd_simple_nonletter($size) }
        default { return pwd_xkcd }
    }

    # TODO how to call a function by name?
    #my $func = 'pwd_' ~ $generator;
    #$func($size);
}

sub pwd_xkcd {
    return "Photon Staple Horse Fire";
}

multi pwd_alphanumeric(Any $size) {
    pwd_alphanumeric(16);
}
multi pwd_alphanumeric(Int $size) {
    return "alpahnum $size";
}

multi pwd_printable(Any $size) {
    pwd_printable(16);
}
multi pwd_printable(Int $size) {
    return "printable $size";
}

multi pwd_mixed_case(Any $size) {
    pwd_mixed_case(16);
}
multi pwd_mixed_case(Int $size) {
    return "MixEdCasE $size";
}

multi pwd_number(Any $size) {
    pwd_number(16);
}
multi pwd_number(Int $size) {
    return "number $size";
}

multi pwd_simple_nonletter(Any $size) {
    pwd_simple_nonletter(16);
}
multi pwd_simple_nonletter(Int $size) {
    return "simple nonletter $size";
}

=finish
