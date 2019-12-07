# unicodemathml

UnicodeMath is an easy-to-read markup language for mathematics. This repository contains a UnicodeMath to MathML compilation pipeline. TODO more

TODO note on "to be integrated into Markdeep"

### Demo: TODO link to demo running on github pages


## What's this *UnicodeMath* you're talking about?

TODO comparison table: latex vs asciimath vs unicodemath on three star scale, with "source readability" 1 2 3, "ease of input" 2 3 1 or so, etc.
TODO good running example: fourier transform


## Getting Started

TODO clone/download, demo page, how to embed into an html page, how to run on arbitrary text, how to (pre)generate parser, etc.

TODO how to use in conjunction with mathjax? (see asciimathml readme for reference)

TODO how to use in node?


## Notes

TODO note: when running playground on your local machine in chrome (TODO other browsers?), make sure to either
* spin up a `python -m SimpleHTTPServer 8000` to circumvent pegjs grammar file loading being prevented due to same-origin policy stuff
* open chrome (on macos anyway) with `open -a Google\ Chrome --args --disable-web-security --user-data-dir`
* set the `security.fileuri.strict_origin_policy` key on `about:config` in Firefox to `false`

TODO note on generating parser and storing it in static file


## License

TODO This license does not apply to ..., which come with their own liceses. (note on license for pegjs and https://github.com/be5invis/Iosevka and jquery and http://www.gust.org.pl/projects/e-foundry/lm-math/download/index_html), also: generated parser license?

TODO all original work MIT, I guess?
