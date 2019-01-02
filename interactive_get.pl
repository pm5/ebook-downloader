#!/usr/bin/env perl

use strict;
use warnings;

use Encode;
use Encode::Locale;
use Encode::UTF8Mac;
use JSON qw/from_json/;
use Scalar::Util qw/looks_like_number/;
use Term::ReadKey;
use WWW::Mechanize;
use Modern::Perl;
use Mojo::UserAgent;
use JSON qw/from_json/;
use XML::LibXML;
use File::Basename qw/dirname/;
use File::Spec::Functions;
use Data::Dumper;
use Archive::Zip qw/:ERROR_CODES/;

sub config
{
    return {
        debug => 0,
        ua => Mojo::UserAgent->new,
        user_agent => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.11; rv:53.0) Gecko/20100101 Firefox/53.0",
        reader_base_url => "https://reader.readmoo.com",
        new_read_base_url => "https://new-read.readmoo.com/mooreader",
        api_base_url => "https://api.readmoo.com/books",
        files => [],
        content => {},
    };
}

sub prepare_mech
{
    my $moo = shift;

    my $mech = WWW::Mechanize->new(
        agent => $moo->{user_agent},
        cookie_jar => {},
        #    noproxy => 0,
        );

    return { %$moo, mech => $mech };
}

sub get_user_password
{
    my $moo = shift;

    print STDERR "Readmoo account: ";
    my $email = <STDIN>;
    chomp $email;

    print STDERR "Readmoo password: ";
    Term::ReadKey::ReadMode("noecho");
    my $password = Term::ReadKey::ReadLine(0);
    chomp $password;
    Term::ReadKey::ReadMode('restore');
    print "\n";

    return { %$moo, email => $email, password => $password };
}

sub login
{
    my $moo = shift;
    my $mech = $moo->{mech};

    $mech->get("https://readmoo.com");
    die "Unable to get readmoo's homepage" unless $mech->success;

    $mech->get("https://member.readmoo.com/login/aHR0cHM6Ly9yZWFkbW9vLmNvbS8=");
    die "Unable to get Readmoo's login page." unless $mech->success;

    my $content = {email => $moo->{email}, password => $moo->{password}};

    $mech->post("https://member.readmoo.com/auth/remote_check/password",
                content => $content);
    die "Unable to sign in into Readmoo." unless $mech->success;

    $mech->post("https://member.readmoo.com/login", content => $content);
    die "Unable to sign in into Readmoo." unless $mech->success;

    return $moo;
}

sub get_book_lists
{
    my $moo = shift;
    my $mech = $moo->{mech};

    $mech->get("https://new-read.readmoo.com/api/me/readings");
    die "Unable to get book list" unless $mech->success;

    my $books_data = from_json( $mech->content(charset => 'utf8') );

    my @books =
        map { {id => $_->{'id'}, author => $_->{'author'}, title => $_->{'title'}} }
    @{$books_data->{"included"}};

    return { %$moo, books => \@books };
}

sub get_book_selection
{
    my $moo = shift;

    if (exists $moo->{selection}) {
        delete $moo->{selection};
    }

    my $i = 0;
    for (@{$moo->{books}}) {
        print STDERR $i++ . " - " . $_->{'id'} . " : " . $_->{'author'} . " : " . $_->{'title'} . "\n";
    }
    print STDERR "q - Quit\n";
    print STDERR "Select: ";

    my $selection = <STDIN>;
    chomp $selection;

    if (looks_like_number($selection) && exists $moo->{books}[$selection]) {
        return { %$moo, selection => $moo->{books}[$selection] };
    } else {
        return;
    }
}

sub get_cookies_for_selection
{
    my $moo = shift;

    die "No selection." unless exists $moo->{selection};

    my $mech = $moo->{mech};
    my $selection = $moo->{selection};
    my $id = $selection->{id};

    $mech->get("https://reader.readmoo.com/api/book/${id}/nav");
    die "Problem getting nav for id ${id}" unless $mech->success;

    my @cookies = ();
    $mech->cookie_jar->scan(sub {
        push @cookies, { name => $_[1], value => $_[2] }
        if ($_[1] =~ m/CloudFront-(?:Key-Pair-Id|Policy|Signature)|AWSELB|readmoo/);
                            });

    my $cookie_string = join("; ", map { $_->{name} . "=" . $_->{value} } @cookies );

    return { %$moo, cookie_string => $cookie_string };
}

sub prepare_for_nav
{
    my $moo = shift;
    my $mech = $moo->{mech};

    my @cookies = ();
    $mech->cookie_jar->scan(sub {
        push @cookies, { name => $_[1], value => $_[2], domain => $_[4], path => $_[3] }
        if ($_[1] =~ m/CloudFront-(?:Key-Pair-Id|Policy|Signature)/);
                            });

    for (@cookies) {
        $mech->cookie_jar->clear($_->{domain}, $_->{path}, $_->{name});
    }

    return $moo;
}

sub request_nav_for_selection
{
    my $moo = shift;

    die "No selection." unless exists $moo->{selection};

    my $mech = $moo->{mech};
    my $selection = $moo->{selection};
    my $id = $selection->{id};

    $mech->get("https://reader.readmoo.com/api/book/${id}/nav");
    die "Problem getting nav for id ${id}" unless $mech->success;

    my @cookies = ();
    $mech->cookie_jar->scan(sub {
        push @cookies, { name => $_[1], value => $_[2] }
        if ($_[1] =~ m/CloudFront-(?:Key-Pair-Id|Policy|Signature)|AWSELB|readmoo/);
                            });

    my $cookie_string = join("; ", map { $_->{name} . "=" . $_->{value} } @cookies );

    $moo = &set_cookie($moo, $cookie_string);

    my $json = from_json( $mech->content(charset => 'utf8') );
    $moo = &parse_nav($moo, $json);

    return $moo;
}


sub request_readmoo
{
    my ($moo, $url) = @_;

    my $ua = $moo->{ua};
    my $res = $ua->get($url => {
        "User-Agent"    => $moo->{user_agent},
        "Cookie"        => $moo->{cookie}
    })->result;
    die "Request to '$url' failed: " . $res->message . "\n"
        unless $res->is_success;
    $res;
}

sub save_readmoo
{
    my ($moo, $url, $save_to) = @_;
    my $res = request_readmoo($moo, $url);
    $res->save_to($save_to);
}

sub set_book_id
{
    my ($moo, $book_id) = @_;
    return {
        %$moo,
        book_id => $book_id
    };
}

sub set_cookie
{
    my ($moo, $cookie) = @_;
    return {
        %$moo,
        cookie => $cookie
    };
}

sub set_build_dir
{
    my ($moo, $build_dir) = @_;
    return { %$moo, build_dir => $build_dir };
}

sub parse_nav
{
    my $moo = shift;
    for (shift) {
        return {
            %$moo,
            opf => $_->{opf},
            nav_dir => $_->{nav_dir},
            message => $_->{message},
            base => $_->{base},
        };
    }
}

sub parse_container
{
    my ($moo, $xpc) = @_;
    my $opf = $xpc->findnodes("//container:rootfile")->[0]->{"full-path"};
    return {
        %$moo,
        opf => $opf,
    };
    $moo;
}

sub request_container
{
    my $moo = shift;
    my $path = "META-INF/container.xml";
    $moo = {
        %$moo,
        container_url => $moo->{reader_base_url} . $moo->{base} . $path
    };

    if ($moo->{debug}) {
        $moo->{content}{$path} = `cat container.xml`
    } else {
        $moo->{content}{$path} = request_readmoo($moo, $moo->{container_url})->text;
    }

    my $dom = XML::LibXML->load_xml(string => $moo->{content}{$path});
    my $xpc = XML::LibXML::XPathContext->new($dom);
    $xpc->registerNs("container", "urn:oasis:names:tc:opendocument:xmlns:container");
    $moo = parse_container($moo, $xpc);
}

sub parse_opf
{
    my ($moo, $xpc) = @_;
    return {
        %$moo,
        files => [
            map { $_->{href} } $xpc->findnodes("//opf:item")
        ]
    };
}

sub request_opf
{
    my $moo = shift;
    my $path = $moo->{opf};
    $moo = {
        %$moo,
        opf_url => $moo->{reader_base_url} . $moo->{base} . $path
    };

    if ($moo->{debug}) {
        $moo->{content}{$path} = `cat content.opf`;
    } else {
        $moo->{content}{$path} = request_readmoo($moo, $moo->{opf_url})->text;
    }

    my $dom = XML::LibXML->load_xml(string => $moo->{content}{$path});
    my $xpc = XML::LibXML::XPathContext->new($dom);
    $xpc->registerNs("opf", "http://www.idpf.org/2007/opf");
    $xpc->registerNs("dc", "http://purl.org/dc/elements/1.1/");
    $moo = parse_opf($moo, $xpc);
}

sub write_file
{
    my ($moo, $path, $content) = @_;
    open my $fh, ">$moo->{build_dir}/$path"
        or die "Can't write to $path: $!\n";
    print $fh $content;
    close $fh;
}

sub save_files
{
    my ($moo) = @_;
    my $build_dir = $moo->{build_dir};
    mkdir for ($build_dir, "$build_dir/META-INF", "$build_dir/OEBPS");

    foreach my $path (keys %{$moo->{content}}) {
        write_file($moo, $path, $moo->{content}{$path});
    }

    foreach my $path (@{$moo->{files}}) {
        my $url = $moo->{reader_base_url} . $moo->{nav_dir} . $path;
        my $save_to = $moo->{build_dir} . "/OEBPS/$path";
        say "$url => $save_to";
        mkdir dirname($save_to);
        unless ($moo->{debug}) {
            save_readmoo($moo, $url, $save_to);
            sleep 1;
        }
    }

    $moo;
}

sub save_mimetype
{
    my $moo = shift;
    open my $fh, ">", $moo->{book_id} . "/mimetype"
        or die "Can't write to mimetype: $!";
    print $fh "application/epub+zip";
    close $fh;
    $moo;
}

sub save_epub
{
    my $moo = shift;
    my $selection = $moo->{selection};
    my $bookname = $selection->{author} . "_" . $selection->{title};
    my $zip = Archive::Zip->new;

    my $filename = "${bookname}.epub";
    if ($^O eq 'darwin') {
        require Encode::UTF8Mac;
        $Encode::Locale::ENCODING_LOCALE_FS = 'utf-8-mac';
    }
    $filename = Encode::decode('locale_fs', $filename);

    foreach (keys %{$moo->{content}}) {
        $zip->addFile(catfile($moo->{book_id}, $_), $_);
    }

    foreach (@{$moo->{files}}) {
        $zip->addFile(catfile($moo->{book_id}, "OEBPS", $_), catfile("OEBPS", $_));
    }

    $zip->addFile(catfile($moo->{book_id}, "mimetype"), "mimetype");

    unless ($zip->writeToFileNamed($filename) == AZ_OK) {
        die "Cannot write EPUB to ebook.epub: $!";
    }

    $moo;
}

my $moo = config();
$moo = prepare_mech($moo);
$moo = get_user_password($moo);
$moo = login($moo);
$moo = get_book_lists($moo);
while ($moo = get_book_selection($moo)) {
    $moo = prepare_for_nav($moo);
    $moo = request_nav_for_selection($moo);

    my $book_id = $moo->{selection}{id};
    $moo = set_book_id($moo, $book_id);
    $moo = set_build_dir($moo, $book_id);
    $moo = request_container($moo);
    $moo = request_opf($moo);
    $moo = save_files($moo);
    $moo = save_mimetype($moo);
    say Dumper($moo) if $moo->{debug};
    $moo = save_epub($moo);
}
print STDERR "done.\n";

1;
