# rmodepdf
## Convert web pages in reader mode to PDF

This utility converts text content of web pages to PDF using LaTeX. The text
content is extracted using [rdrview](https://github.com/eafer/rdrview), utility
that uses port of Firefox's reader view functionality.

ToDo:

- convert webp and svg images to filetypes suitable for LaTeX

## Intented support

- standalone HTML documents, both local and online
- Epub files
- [WARC](https://en.wikipedia.org/wiki/Web_ARChive) - Web Archive files

## Dependencies

- TeX distribution
- [rdrview](https://github.com/eafer/rdrview)
- [HTML Tidy](https://www.html-tidy.org/)
- [curl](https://curl.haxx.se/)
