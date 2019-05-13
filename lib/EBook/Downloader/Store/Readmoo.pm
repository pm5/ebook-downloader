package EBook::Downloader::Store::Readmoo;

use v5.24;
use strict;
use warnings;
use Mojo::UserAgent;

sub config {
    {
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

1;
