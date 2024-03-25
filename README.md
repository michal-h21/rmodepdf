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
- [Rdrview](https://github.com/eafer/rdrview)
- [Curl](https://curl.haxx.se/)
- [ImageMagick](https://imagemagick.org/index.php) -- for conversion of Gif and Webp images
- [CairoSVG](https://cairosvg.org/) -- for conversion of SVG images
