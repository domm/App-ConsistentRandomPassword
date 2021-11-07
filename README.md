# NAME

App::ConsistentRandomPassword - Create consistent random passwords

# VERSION

version 0.900

# SYNOPSIS

    say App::ConsistentRandomPassword
        ->new({ site=> 'https://example.com' })
        ->password( 'hunter2' );

    # or use the script included with this dist:
    ~# crp.pl https://example.com
    key: <ENTER YOUR SECRET>
    Your password for 'example.com' is ready to paste

# DESCRIPTION

`App::ConsistentRandomPassword` is a tool to create consistent but
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

`App::ConsistentRandomPassword` uses a config file (`.crp.json`)
where you can fine-tune how the passwords for different sites should
be generated. You can combine 6 different password generators, ignore
subdomains (so `foo.example.com` and `bar.example.com` have the same
password), include paths (so `example.com/foo` and `example.com/bar`
have different passwords) and even base the password on something
that's not an URI.

## Password generators

### xkcd

### alphanumeric

### mixed\_case

### printable

### number

### simple\_nonletter

## Configuration Files

### crp.json

#### match

#### method

#### entropy

#### with\_path

#### main\_domain

#### no\_uri

### crp.entropy

# THANKS

Thanks to

- <Paul Cochrane|https://github.com/paultcochrane> for various cleanup pull requests

# AUTHOR

Thomas Klausner <domm@plix.at>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2015 - 2021 by Thomas Klausner.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
