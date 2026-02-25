use v5.36;
use utf8;
use Mojo::JSON qw(decode_json encode_json);
use Test::More;

my $chars = '{"word":"ÑAME"}';
# $chars has the UTF8 flag ON because of 'use utf8' and literal string

eval {
    my $data = decode_json($chars);
    is($data->{word}, "ÑAME", "decode_json handles character strings with Unicode characters");
};
if ($@) {
    diag "decode_json FAILED on character string: $@";
}

my $bytes = encode_json({word => "ÑAME"});
# $bytes is a byte string (UTF-8 encoded)

eval {
    my $data = decode_json($bytes);
    is($data->{word}, "ÑAME", "decode_json handles byte strings");
};
if ($@) {
    diag "decode_json FAILED on byte string: $@";
}

done_testing();
