
Readmoo Downloader
===

Download your Readmoo ebooks as EPUB files.

## Usage

You can skip the first three steps after the first time using the tool.

1. Make sure you have a modern version of Perl or install one with [Perlbrew](https://perlbrew.pl/).
2. Make sure you have [cpanm](https://metacpan.org/pod/distribution/App-cpanminus/lib/App/cpanminus/fatscript.pm) and [carton](https://metacpan.org/pod/distribution/Carton/script/carton) installed.
3. Install dependencies with
   ```
   $ eval $(perl -Mlocal::lib=./local)
   $ carton
   ```
4. Setup Perl running environment variables with
   ```
   $ eval $(perl -Mlocal::lib=./local)
   ```
5. Open your [Readmoo library](https://new-read.readmoo.com/library) in a browser.  Click on the book you want to download.  A mooreader tab will pop out.
6. Note the book ID, which is the string of digits at the end, in URL.  For example, if the URL of mooreader tab is <https://new-read.readmoo.com/mooreader/12345678901213>, the book ID is `12345678901213`.
7. Get the cookie string with the following steps.  Open the web developer tool of your browser.  Go to Network tab.  Use filter to find a request to `content.opf`.  If there is no such a request, reload the mooreader.  Look for the cookies in the request header of this request.  Select all and copy the whole cookie string.  It should be a long string started with `CloudFront-Policy=...` and may have `CloudFront-Signature`, `CloudFront-Key-Pair-Id`, `readmoo`, `AWSELB` in it.
8. Run the following command to download the EPUB and save it as `ebook.epub`:
   ```
   $ ./get.pl <BOOK_ID> <COOKIE_STRING>
   ```
   Note that the cookie string may contains blank and semicolons, so enclose it with quotation marks like in the following example
   ```
   $ ./get.pl 12345678901213 "CloudFront-Policy=...; CloudFront-Signature=...; CloudFront-Key-Pair-Id=...; readmoo=...; AWSELB=..."
   ```

## License

[MIT](LICENSE)

## Questions

### Readmoo offers their ebooks with DRM.  This tool sidesteps the protection.  Is it ethical to release a tool like this?

Like the many DeDRM tools for Amazon Kindle or other ebook services, this tool has practical uses, which is to backup the ebooks you have bought, and at the same time demonstrates a technical possibility.  Since it can only download for you the ebooks you have bought on Readmoo, you have already paid for these contents.

Leaving the customers like you unable to backup and transfer the ebooks to other devices using open formats after buying them creates an unjust lock-in, because Readmoo does not sell their products as subscriptions.

Besides, [Kobo](https://www.kobo.com/) offers largely the same ebook titles under the same prices as Readmoo does, but gives you access to the EPUB files without DRM.  Therefore I do not believe that offering un-DRM'ed contents with reasonable prices violates the principles to publishing business.