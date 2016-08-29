#!/home/domm/rakudo-star-2016.07/install/bin/perl6

use JSON::Tiny;
use Digest::MD5;
use URI;
use Terminal::Readsecret;
use experimental :pack;

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
    my $key = getsecret("Please enter your key for $site: ");
    return $key;

    # another way might be https://github.com/krunen/term-termios
    # gfldex | CLI::Promt::Password may actually what most ppl look for
}

sub set_consistent_seed(Str $site, Str $key, Str $global_entropy?, Str $match_entropy?) {
    my $d = Digest::MD5.new;
    my @data = ($site, $key);
    @data.push($global_entropy) if $global_entropy;
    @data.push($match_entropy) if $match_entropy;
    my $hex = $d.md5_buf(@data);
    my @ints = $hex.unpack("CxCxCxCxCxC");
    my $seed = @ints.reduce: * ~ *;
    srand($seed.Int);
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

    my $function = '&pwd_' ~ $generator;
    if ($size) {
	::($function).($size);
    }
    else {
	::($function).();
    }
}

sub pwd_xkcd(Int $size?=4) {
    return "Photon Staple Horse Fire $size";
}
sub pwd_number(Int $size?=8) {
    return "42";
}
sub pwd_simple_nonletter(Int $size?=16) {
    return "simple nonletter $size";
}
sub pwd_mixed_case(Int $size?=16) {
    return "MixEdCasE $size";
}
sub pwd_alphanumeric(Int $size?=16) {
    return "alpahnum $size";
}
sub pwd_printable(Int $size?=16) {
    return "printable $size";
}

=finish
