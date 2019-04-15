#!/usr/bin/env perl -w

=pod

=head1 NAME

get.pl - Get ebooks

=head1 SYNOPSIS

    # Grab the book ID and cookie from `container.xml` request.
    $ get.pl <BOOK_ID> <COOKIE_STRING>

=head1 TECHNICAL SPECS

Readmoo's eBook reader roughly works in the following way:

=over

=item 1. Load the reader HTML from L<https://new-read.readmoo.com/mooreader/210001615000101>.

=item 1. Load the reader navigation data from L<https://reader.readmoo.com/api/book/210001615000101/nav>.

=item 1. Load ePub contents using the navigation data.

=back

=cut

use strict;
use warnings;
use v5.10;
use FindBin;
use lib "$FindBin::Bin/local/lib/perl5";
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

sub request_nav
{
    my $moo = shift;

    $moo->{nav_url} = "https://reader.readmoo.com/api/book/$moo->{book_id}/nav";

    my $nav;
    if ($moo->{debug}) {
        open my $fh, "<:utf8", "nav.json";
        $nav = from_json(<$fh>);
        close $fh;
    } else {
        $nav = request_readmoo($moo, $moo->{nav_url})->json;
    }

    $moo = &parse_nav($moo, $nav);
    $moo;
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
    my $zip = Archive::Zip->new;

    $zip->addFile(catfile($moo->{book_id}, "mimetype"), "mimetype");

    foreach (keys %{$moo->{content}}) {
        $zip->addFile(catfile($moo->{book_id}, $_), $_);
    }

    foreach (@{$moo->{files}}) {
        $zip->addFile(catfile($moo->{book_id}, "OEBPS", $_), catfile("OEBPS", $_));
    }

    unless ($zip->writeToFileNamed("ebook.epub") == AZ_OK) {
        die "Cannot write EPUB to ebook.epub: $!";
    }

    $moo;
}

my $moo = config();
$moo = set_book_id($moo, $ARGV[0]);
$moo = set_cookie($moo, $ARGV[1]);
$moo = set_build_dir($moo, $ARGV[0]);
$moo = request_nav($moo);
$moo = request_container($moo);
$moo = request_opf($moo);
$moo = save_files($moo);
$moo = save_mimetype($moo);
say Dumper($moo) if $moo->{debug};
$moo = save_epub($moo);

0;
