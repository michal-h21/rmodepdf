# rmodepdf
## Convert web pages in reader mode to PDF

This utility converts text content of web pages to PDF using LaTeX. The text
content is extracted using [rdrview](https://github.com/eafer/rdrview), utility
that uses port of Firefox's reader view functionality.

# Documentation

You can find the documentation [here](https://www.kodymirus.cz/rmodepdf/).
See also the [handout](https://www.kodymirus.cz/presentations/responsive_handout.html) of my talk at the TUG 2024 conference.

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
