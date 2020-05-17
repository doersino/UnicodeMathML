# UnicodeMathML

*This repository provides a JavaScript-based translation of [UnicodeMath](https://www.unicode.org/notes/tn28/) to [MathML](https://developer.mozilla.org/en-US/docs/Web/MathML) ("UnicodeMathML"). An interactive "playground" allows for experimentation with UnicodeMath's syntax and insight into the translation pipeline. UnicodeMathML can be easily integrated with arbitrary HTML or [Markdeep](https://casual-effects.com/markdeep/) documents.*

UnicodeMath is an **easy-to-read linear format** for mathematics initially developed as an input method and interchange representation for Microsoft Office. Its author, Murray Sargent III, has published a [*Unicode Technical Note*](https://www.unicode.org/notes/tn28/) detailing the format, based on which this UnicodeMath to MathML translator was built. *More in the FAQ section below.*

![](screenshot.png)

## Demo

The *UnicodeMathML Playground* is available [here](https://doersino.github.io/UnicodeMathML/playground.html), while an example Markdeep document containing UnicodeMath can be found [here](https://doersino.github.io/UnicodeMathML/markdeep-integration/markdeep.md.html).


## Getting Started

Depending on what whether you TODO

TODO clone/download, demo page, how to embed into an html page, how to run on arbitrary text, how to (pre)generate parser, etc.

TODO how to use in conjunction with mathjax? (see asciimathml readme for reference)

TODO how to use in node?


## FAQ

Got questions that aren't answered below? Feel free to pose them by [filing an issue](https://github.com/doersino/UnicodeMathML/issues)!


### What's this *UnicodeMath* you're talking about?

UnicodeMath is an linear format for mathematics initially developed as an input method and interchange representation for Microsoft Office. By using Unicode symbols in lieu of keywords wherever possible, it's significantly more readable than established/competing formats in plain text:

TODO a single example, table further down

TODO more from thesis/presentation

Its author, Murray Sargent III, has published a [*Unicode Technical Note*](https://www.unicode.org/notes/tn28/) detailing the format, based on which this UnicodeMath to MathML translator was built.

#### Basic constructs

TODO explain basic constructs/link to page describing more advanced ones


### How does its syntax compare to AsciiMath, LaTeX, and MathML?

Here's a table showing a few formulas as you'd write them in UnicodeMath, AsciiMath and LaTeX:

TODO table

To summarize, here's a totally-not-biased ranking of the formats

TODO comparison table: latex vs asciimath vs unicodemath on three star scale, with "source readability" 1 2 3, "ease of input" 2 3 1 or so, ease of parsing, etc.

TODO good running example: fourier transform


### Alright, but I can't find any of these fancy Unicode symbols on my keyboard!

Nobody's keeping you from adapting [Tom Scott's emoji keyboard](https://www.youtube.com/watch?v=lIFE7h3m40U) idea for math.

More realistically, there's a bunch of tools and text editor plugins that can help out here:

* TODO sublime plugin (note this: https://github.com/mvoidex/UnicodeMath/issues/20)
* TODO other tools (see the ones torsten recommended, macos popup thingy, something for windows?)

Additially, you can configure UnicodeMathML to automatically translate keywords like `\infty` into their respective symbols before processing proper commences.


### Alright, that's not as big of a problem as I feared. What's *MathML*, then?

TODO explain


### Isn't browser support for MathML really lackluster?

Sort of – according to [caniuse.com](https://caniuse.com/#search=mathml), native support for MathML is available for around 24% of users as of early 2019 as only Firefox and Safari currently support MathML.

However, Igalia is working in conjunction with TODO on TODO, which should push this number upwards quite significantly in the coming months and years.

All of this isn't really an issue: MathJax, which you'd probably use to render LaTeX math on the web, provides a polyfill for MathML rendering.


### But LaTeX seems more TODO widespread, usable, omnipresent., and KaTeX is so much faster than MathJax!

Yup. For this reason, I'm experiementing with enabling UnicodeMathML to emit LaTeX code, too – most but not all UnicodeMath features are supported. TODO link to section

TODO test with katex


### I found a bug, also I've got a bunch of ideas on how to improve this thing!

Great! Please feed free to file an issue or send a pull request.

TODO insert links


## Development

TODO how to gen parser, architecture overview etc.


## Notes

TODO note: when running playground on your local machine in chrome (TODO other browsers?), make sure to either
* spin up a `python -m SimpleHTTPServer 8000` to circumvent pegjs grammar file loading being prevented due to same-origin policy stuff (TODO still current?)
* open chrome (on macos anyway) with `open -a Google\ Chrome --args --disable-web-security --user-data-dir`
* set the `security.fileuri.strict_origin_policy` key on `about:config` in Firefox to `false`
TODO see https://gist.github.com/willurd/5720255
TODO is this all still necessary? nope?

TODO note on generating parser and storing it in static file

TODO note on features i've added (colors etc., \u1234, etc., custom control words, doublestruck option, etc.)

TODO see also mathjax, katex, https://github.com/michael-brade/LaTeX.js, more


## License

You may use this repository's contents under the terms of the *MIT License*, see `LICENSE`.

However, the subdirectories `lib/`, `markdeep-integration/` and `playground-assets/lib/` contain some **third-party software with its own licenses**:

* pegjs
* markdeep, highlightjs
* todo jquery
* **MathJax** is licensed under the *Apache License 2.0*, see [here](https://github.com/mathjax/MathJax/blob/master/LICENSE).
* todo webfonts: https://github.com/be5invis/Iosevka and http://www.gust.org.pl/projects/e-foundry/lm-math/download/index_html
