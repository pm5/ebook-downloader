
Ebook Download
===

Download your Readmoo ebooks as EPUB files.

## Usage

You can skip the first three steps after the first time using the tool.

1. Make sure you have a modern version, say >= 5.24, of Perl.  You can install one with [Perlbrew](https://perlbrew.pl/).
2. Make sure you have [cpanm](https://metacpan.org/pod/distribution/App-cpanminus/lib/App/cpanminus/fatscript.pm) and [carton](https://metacpan.org/pod/distribution/Carton/script/carton) installed:
   ```
   $ curl -L https://cpanmin.us | perl - App::cpanminus
   $ cpanm Carton
   ```
3. Install dependencies with
   ```
   $ carton install --deployment
   ```
4. Setup Perl running environment variables with
   ```
   $ eval $(perl -Mlocal::lib=./local)
   ```
5. Run interactive script
   ```
   $ interactive_get.pl
   Readmoo account: <your_email@your_email_provider>
   Readmoo password:
   ```
   If everything goes well, it will list all ebooks in your Readmoo library.  Select the ebook you want to download by its number and press ENTER to start downloading.  Type `q` and press ENTER to quit the program.

## License

[MIT](LICENSE)

## Questions

### Readmoo offers their ebooks with DRM.  This tool sidesteps the protection.  Is it ethical to release a tool like this?

Like the many DeDRM tools for Amazon Kindle or other ebook shops, this tool has practical uses, which is to backup the ebooks you have bought, and at the same time demonstrates a technical possibility.  Since it can only download for you the ebooks you have bought on Readmoo, you have already paid for these contents.

Leaving the customers like you unable to backup and transfer the ebooks to other devices using open formats after buying them creates an unjust lock-in, because Readmoo does not sell their products as subscriptions.  This is, however, a controversial point of view.

There are other ebook shops like [Kobo](https://www.kobo.com/) which offers largely the same ebook titles under the same prices as Readmoo does, and gives you access to the EPUB files, albeit with DRM.
