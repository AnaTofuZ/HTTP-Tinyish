use strict;
use Test::More;
use HTTP::Tinyish;
use File::Temp qw(tempdir);
use JSON::PP qw(decode_json);

plan skip_all => "skip network tests"
  unless $ENV{LIVE_TEST} or -e ".git";

sub read_file {
    open my $fh, "<", shift;
    join "", <$fh>;
}

for my $backend ( @HTTP::Tinyish::Backends ) {
    diag "Testing with $backend";
    $HTTP::Tinyish::PreferredBackend = $backend;

    my $res = HTTP::Tinyish->new->get("http://www.cpan.org");
    is $res->{status}, 200;
    like $res->{content}, qr/Comprehensive/;

    if ($backend->supports('https')) {
        $res = HTTP::Tinyish->new->get("https://cpan.metacpan.org");
        is $res->{status}, 200;
        like $res->{content}, qr/Comprehensive/;
    }

    my $fn = tempdir(CLEANUP => 1) . "/index.html";
    $res = HTTP::Tinyish->new->mirror("http://www.cpan.org", $fn);
    is $res->{status}, 200;
    like read_file($fn), qr/Comprehensive/;

 SKIP: {
        skip "Wget doesn't handle mirror", 1 if $backend =~ /Wget/;
        $res = HTTP::Tinyish->new->mirror("http://www.cpan.org", $fn);
        is $res->{status}, 304;
    }

    $res = HTTP::Tinyish->new(agent => "Menlo/1")->get("http://httpbin.org/user-agent");
    is_deeply decode_json($res->{content}), { 'user-agent' => "Menlo/1" };

    $res = HTTP::Tinyish->new->get("http://httpbin.org/status/404");
    is $res->{status}, 404;

    $res = HTTP::Tinyish->new->get("http://httpbin.org/response-headers?Foo=Bar+Baz");
    is $res->{headers}{foo}, "Bar Baz";

    $res = HTTP::Tinyish->new->get("http://httpbin.org/basic-auth/user/passwd");
    is $res->{status}, 401;

    $res = HTTP::Tinyish->new->get("http://user:passwd\@httpbin.org/basic-auth/user/passwd");
    is $res->{status}, 200;
    is_deeply decode_json($res->{content}), { authenticated => JSON::PP::true(), user => "user" };
}

done_testing;
