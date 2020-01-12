// Integration of the UnicodeMathML translator into Markdeep or plain HTML.
'use strict';

// check if UnicodeMathML is loaded
var umml = (typeof ummlParser === "object") && (typeof unicodemathml === "function");

if (!umml) {
    (typeof ummlParser === "object") || console.log("There's a problem with the UnicodeMathML integration: It seems like the parser isn't loaded.");
    (typeof unicodemathml === "function") || console.log("There's a problem with the UnicodeMathML integration: It seems like the translator isn't loaded.");
}


////////////////////////
// OPTIONS PROCESSING //
////////////////////////

// initialize with defaults (this variable has the same name as the config used
// by the playground – but really only the resolveControlWords key is shared)
var ummlConfig = {
    resolveControlWords: false,
    showProgress: true,
    customControlWords: undefined,
    before: Function.prototype,
    after: Function.prototype
};

// if set, override defaults with user-specified options
if (typeof unicodemathmlOptions !== "undefined") {
    ummlConfig = Object.assign({}, ummlConfig, unicodemathmlOptions);
}


////////////////////////
// EXTRACTION/MARKING //
////////////////////////

// note that the protect function is required for markdeep, it's probably less
// relevant in other contexts
function markUnicodemathInHtmlCode(code, protect = x => x) {

    // ES2018's lookbehind, i.e. (?<=^|[^\\]), would be really handy here, but
    // sadly it's only supported by a small subset of browsers yet (see
    // https://caniuse.com/#search=lookbehind), so we need to capture the
    // preceding char and return it unchanged (this breaks directly adjacent
    // math zones, but that seems like an uncommon use case and can't be helped,
    // i guess?)
    code = code.replace(/(^|[^\\])⁅([^⁆]*?[^\\])⁆/gi, function (unicodemathWithDelimiters, prec, unicodemath) {

        // markdeep appears to convert non-breaking spaces to &nbsp; entities
        // (although i can't find where exactly this is done in its source code
        // – so maybe the browser does it? it's not happening in the html
        // integration, though), so invert this mapping
        unicodemathWithDelimiters = unicodemathWithDelimiters.replace(/&nbsp;/g, "\u00A0");
        unicodemath = unicodemath.replace(/&nbsp;/g, "\u00A0");

        var placeholder = document.createElement("span");
        placeholder.classList.add("unicodemathml-placeholder");

        // any <, >, and & contained in the original unicodemath expression will
        // be escaped as &lt;, &gt and &amp; when we return courtesy of
        // .outerHTML, so keep the original, unchanged expression around in a
        // data attribute
        // see also: https://casual-effects.com/markdeep/features.md.html#less-thansignsincode
        // and: http://docs.mathjax.org/en/latest/input/tex/html.html
        placeholder.setAttribute("data-unicodemath", encodeURIComponent(unicodemath));

        // keep original in case no translation to mathmal is performed
        placeholder.innerText = unicodemathWithDelimiters;

        return prec + protect(placeholder.outerHTML);
    });

    // remove backslashes from escaped math delimiters for rendering
    return code.replace(/\\⁅/g, '⁅').replace(/\\⁆/g, '⁆');
}

// TODO this works in the most common cases, but can be improved – take a look at the asciimath source code or https://github.com/mathjax/MathJax/blob/develop/unpacked/extensions/tex2jax.js
// TODO respect escaping of delimiters – reuse regex from markUnicodemathInHtmlCode function?
function markUnicodemathInHtmlDom(node) {
    if (node === undefined) {
        node = document.body;
    }

    // via https://stackoverflow.com/a/4793630
    var insertAfter = (newNode, referenceNode) => {
        referenceNode.parentNode.insertBefore(newNode, referenceNode.nextSibling);
    }

    switch (node.nodeType) {
        case Node.ELEMENT_NODE:

            // ignore the contents of these tags
            if (["PRE", "CODE", "TEXTAREA", "SCRIPT", "STYLE", "HEAD", "TITLE"].includes(node.tagName)) {
                break;
            }

            // recurse
            node.childNodes.forEach(markUnicodemathInHtmlDom);

            break;

        case Node.TEXT_NODE:

            // subdivide text such that non-unicodemath areas alternate with
            // unicodemath areas (no escaping of delimiters supported yet),
            // strip delimiters out in the process
            var strings = node.textContent.split("⁅").map(x => x.split("⁆"));

            // flatten the resulting list of lists
            strings = [].concat.apply([], strings);

            var lastNode = node;
            for (var i = 0; i < strings.length; i++) {
                if (i % 2 == 0) {  // text node
                    var text = document.createTextNode(strings[i]);
                    insertAfter(text, lastNode);
                    lastNode = text;
                } else {  // unicodemath node
                    var placeholder = document.createElement("span");
                    placeholder.classList.add("unicodemathml-placeholder");
                    placeholder.setAttribute("data-unicodemath", encodeURIComponent(strings[i]));
                    placeholder.innerText = "⁅" + strings[i] + "⁆";
                    insertAfter(placeholder, lastNode);
                    lastNode = placeholder;
                }
            }
            node.parentNode.removeChild(node);
            break;

        default:
            break;
    }
}


///////////////////////////
// TRANSLATION/RENDERING //
///////////////////////////

async function renderMarkedUnicodemath(node) {
    if (node === undefined) {
        node = document.body;
    }

    // note that getting the status to update properly took some work – i only
    // got it to wirk with this weird semi-cps-transformed async/await/
    // requestAnimationFrame approach, which seems overly complicated
    function showProgress(totalNum) {
        return new Promise((f) => {
            if (document.getElementById("unicodemathml-progress")) {

                // reset progress indicator
                document.getElementById("unicodemathml-progress-counter").innerText = "0";
                document.getElementById("unicodemathml-progress-errors").innerHTML = "";
                document.getElementById("unicodemathml-progress").style.display = "block";
                requestAnimationFrame(f);
            } else {

                // add CSS rules for progress and errors
                var styleElement = document.createElement("style");
                styleElement.type = "text/css";
                styleElement.innerText = `
                #unicodemathml-progress {
                    position: fixed;
                    right: 0;
                    bottom: 0;
                    border: 1px solid #ccc;
                    background-color: #eee;
                    margin: 1px;
                    font: 12px sans-serif;
                    padding: 0 1px;
                    z-index: 9001;
                }
                .unicodemathml-error {
                    color: red;
                }
                .unicodemathml-error-unicodemath:before {
                    content: '⁅';
                }
                .unicodemathml-error-unicodemath:after {
                    content: '⁆';
                }
                .unicodemathml-error-message {
                    display: none;
                }
                .unicodemathml-error:hover .unicodemathml-error-message {
                    display: inline;
                }
                `
                document.head.appendChild(styleElement);

                // create progress indicator
                var progress = document.createElement("div");
                progress.innerHTML = '<div id="unicodemathml-progress">Translating UnicodeMath to MathML (<strong id="unicodemathml-progress-counter">0</strong>/' + totalNum + '<span id="unicodemathml-progress-errors"></span>)</div>';
                document.body.appendChild(progress.childNodes[0]);
                requestAnimationFrame(f);
            }
        });
    }
    function updateProgress(currNum, errorNum) {
        return new Promise((f) => {
            document.getElementById("unicodemathml-progress-counter").innerText = currNum;
            if (errorNum > 0) {
                document.getElementById("unicodemathml-progress-errors").innerHTML = ', with <span style="color: red;">' + errorNum + ' error' + (errorNum == 1 ? "" : "s") + '</span>';
            }
            requestAnimationFrame(f);
        });
    }
    function hideProgress() {
        return new Promise((f) => {
            document.getElementById("unicodemathml-progress").style.display = "none";
            requestAnimationFrame(f);
        });
    }

    // run before hook
    ummlConfig.before();

    // initialize cache
    var cache = {};

    // extract unicodemath expressions from node
    var unicodemathPlaceholders = Array.from(node.querySelectorAll("span.unicodemathml-placeholder"));

    // show a progress message
    var progressUpdated = Date.now();
    if (ummlConfig.showProgress) await showProgress(unicodemathPlaceholders.length);

    // work our way through
    var errors = 0;
    for (var i = 0; i < unicodemathPlaceholders.length; i++) {

        var elem = unicodemathPlaceholders[i];

        // extract unicodemath expression
        var unicodemath = decodeURIComponent(elem.getAttribute("data-unicodemath"));

        // determine whether the expression should be rendered in displaystyle
        // (i.e. iff it is the only child of a <p>, the determination of which
        // is made a bit annoying by the presence of text nodes)
        // TODO are other tags relevant too? BLOCKQUOTE? CENTER? any display: block element?
        var displaystyle = elem.parentNode &&
                           elem.parentNode.nodeName == "P" &&
                           Array.from(elem.parentNode.childNodes).filter(node => {  // keep everything that's...
                               return node.nodeType !== Node.TEXT_NODE ||           // ...not a text node...
                                      node.nodeValue.trim().length != 0;            // ...or a text node with non-zero length after whitespace removal...
                           }).length == 1;                                          // ...and check if the result has cardinality 1 (i.e. contains only the unicodemath placeholder)

        var mathml;

        // check whether we've translated this unicodemath expression in this
        // style before
        var cacheAddress = (displaystyle? "1" : "0") + unicodemath;
        if (cache.hasOwnProperty(cacheAddress)) {

            // i'm making a note here: huge success – it's hard to overstate my
            // satisfaction
            mathml = cache[cacheAddress];
        } else {

            // seems like we haven't
            var t = unicodemathml(unicodemath, displaystyle);
            mathml = t.mathml;
            if (t.details.error) {
                errors++;
            } else {
                cache[cacheAddress] = mathml;
            }
        }

        // replace span with math
        elem.outerHTML = mathml;

        // update progress message if at least 200 ms have elapsed since the
        // last update (this speeds up things considerably versus updating it on
        // every iteration – drawing is expensive, which is why browsers avoid
        // it by default within functions!)
        if (ummlConfig.showProgress && Date.now() >= progressUpdated + 200) {
            progressUpdated = Date.now();
            await updateProgress(i+1, errors);
        }
    }

    // hide progress message
    if (ummlConfig.showProgress) await hideProgress();

    // tell mathjax to rerender the document
    if (typeof MathJax != "undefined") {
        MathJax.Hub.Queue(["Typeset", MathJax.Hub, node]);
    }

    // run after hook
    ummlConfig.after();
}


////////////////////////////////////////////////////////////////////////////////

// translates all mathml expressions on the page, should be called like
// document.body.onload = renderUnicodemath();
function renderUnicodemath() {
    markUnicodemathInHtmlDom();
    renderMarkedUnicodemath();
}
