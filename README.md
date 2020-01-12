# UnicodeMathML

*UnicodeMath is an easy-to-read linear format for mathematics. The code in this repository implements a JavaScript-based translation of UnicodeMath to MathML ("UnicodeMathML"). An interactive "playground" allows for experimentation with UnicodeMath's syntax. UnicodeMathML can be used with arbitrary HTML or Markdeep documents.*

**What's UnicodeMath, precisely?** This and other questions are answered in the FAQ section below.

#### Demo: TODO link to playground demo running on github pages

## Getting Started

TODO clone/download, demo page, how to embed into an html page, how to run on arbitrary text, how to (pre)generate parser, etc.

TODO how to use in conjunction with mathjax? (see asciimathml readme for reference)

TODO how to use in node?


## FAQ

Got questions that aren't answered below? Feel free to submit them by [filing an issue](TODO link)!

### What's this *UnicodeMath* you're talking about?

TODO take from thesis/presentation


### How does its syntax compare to LaTeX and AsciiMath?

Here's a table showing a few formulas as you'd write them in UnicodeMath, AsciiMath and LaTeX:

TODO comparison table: latex vs asciimath vs unicodemath on three star scale, with "source readability" 1 2 3, "ease of input" 2 3 1 or so, etc.
TODO good running example: fourier transform


### Alright, but I can't find many of these fancy Unicode symbols on my keyboard!

Nobody's keeping you from adapting [Tom Scott's emoji keyboard](https://www.youtube.com/watch?v=lIFE7h3m40U) idea for math.

More realistically, there's a bunch of tools and text editor plugins that can help out here:

* TODO sublime plugin
* TODO other tools


### Neat. What's *MathML*, then?

TODO explain


### Isn't browser support for MathML really lackluster?

Sort of – according to [caniuse.com](https://caniuse.com/#search=mathml), native support for MathML is available for around 24% of users as of early 2019 as only Firefox and Safari currently support MathML.

However, Igalia is working in conjunction with TODO on TODO, which should push this number upwards quite significantly in the coming months and years.

All of this isn't really an issue: MathJax, which you'd probably use to render LaTeX math on the web, provides a polyfill for MathML rendering.


### But LaTeX seems more TODO widespread, usable, omnipresent., and KaTeX is so much faster than MathJax!

Yup. UnicodeMathML can emit LaTeX code, too – most but not all UnicodeMath features are supported. TODO link to section


## Notes

TODO note: when running playground on your local machine in chrome (TODO other browsers?), make sure to either
* spin up a `python -m SimpleHTTPServer 8000` to circumvent pegjs grammar file loading being prevented due to same-origin policy stuff (TODO still current?)
* open chrome (on macos anyway) with `open -a Google\ Chrome --args --disable-web-security --user-data-dir`
* set the `security.fileuri.strict_origin_policy` key on `about:config` in Firefox to `false`

TODO note on generating parser and storing it in static file

TODO note on features i've added (colors etc., \u1234, etc.)


## License

TODO all original work MIT, I guess?

TODO This license does not apply to ..., which come with their own liceses. (note on license for pegjs and https://github.com/be5invis/Iosevka and jquery and http://www.gust.org.pl/projects/e-foundry/lm-math/download/index_html), also: generated parser license?
