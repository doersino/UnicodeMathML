'use strict';

var input = document.getElementById("input");
var codepoints = document.getElementById("codepoints");
var output = document.getElementById("output");
var output_pegjs_ast = document.getElementById("output_pegjs_ast");
var output_preprocess_ast = document.getElementById("output_preprocess_ast");
var output_mathml_ast = document.getElementById("output_mathml_ast");
var output_source = document.getElementById("output_source");
var measurements_parse = document.getElementById("measurements_parse");
var measurements_transform = document.getElementById("measurements_transform");
var measurements_pretty = document.getElementById("measurements_pretty");

var activeTab = "source";
var hist = [];

var prevInputValue = "";

// escape mathml tags and entities, via https://stackoverflow.com/a/13538245
function escapeMathMLSpecialChars(str) {
    var replacements = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;'
    };
    return str.replace(/[&<>]/g, tag => {
        return replacements[tag] || tag;
    });
};

// via https://stackoverflow.com/a/49458964
function indentMathML(str) {
    var formatted = '', indent= '';
    str.split(/>\s*</).forEach(node => {
        if (node.match( /^\/\w/ )) indent = indent.substring(2);
        formatted += indent + '<' + node + '>\n';
        if (node.match( /^<?\w[^>]*[^\/]$/ )) indent += '  ';
    });
    return formatted.substring(1, formatted.length-2);
};

// loosely based on https://www.w3schools.com/howto/howto_syntax_highlight.asp
function highlightMathML(mathml) {
    mathml = mathmlMode(mathml);
    return mathml;

    function extract(str, start, end, func, repl) {
        var s, e, d = "", a = [];
        while (str.search(start) > -1) {
            s = str.search(start);
            e = str.indexOf(end, s);
            if (e == -1) {e = str.length;}
            if (repl) {
                a.push(func(str.substring(s, e + (end.length))));
                str = str.substring(0, s) + repl + str.substr(e + (end.length));
            } else {
                d += str.substring(0, s);
                d += func(str.substring(s, e + (end.length)));
                str = str.substr(e + (end.length));
            }
        }
        this.rest = d + str;
        this.arr = a;
    }
    function mathmlMode(txt) {
        var rest = txt, done = "", comment, angular, startpos, endpos, note, i;
        comment = new extract(rest, "&lt;!--", "--&gt;", commentMode, "W3HTMLCOMMENTPOS");
        rest = comment.rest;
        while (rest.indexOf("&lt;") > -1) {
            startpos = rest.indexOf("&lt;");
            endpos = rest.indexOf("&gt;", startpos);
            if (endpos == -1) {endpos = rest.length;}
            done += rest.substring(0, startpos);
            done += tagMode(rest.substring(startpos, endpos + 4));
            rest = rest.substr(endpos + 4);
        }
        rest = done + rest;
        for (i = 0; i < comment.arr.length; i++) {
            rest = rest.replace("W3HTMLCOMMENTPOS", comment.arr[i]);
        }
        return "<span class=\"text\">" + rest + "</span>";
    }
    function tagMode(txt) {
        var rest = txt, done = "", startpos, endpos, result;
        while (rest.search(/(\s|<br>)/) > -1) {
            startpos = rest.search(/(\s|<br>)/);
            endpos = rest.indexOf("&gt;");
            if (endpos == -1) {endpos = rest.length;}
            done += rest.substring(0, startpos);
            done += attributeMode(rest.substring(startpos, endpos));
            rest = rest.substr(endpos);
        }
        result = done + rest;
        result = "<span class=\"bracket\">&lt;</span>" + result.substring(4);
        if (result.substr(result.length - 4, 4) == "&gt;") {
            result = result.substring(0, result.length - 4) + "<span class=\"bracket\">&gt;</span>";
        }
        return "<span class=\"tag\">" + result + "</span>";
    }
    function attributeMode(txt) {
        var rest = txt, done = "", startpos, endpos, singlefnuttpos, doublefnuttpos, spacepos;
        while (rest.indexOf("=") > -1) {
            endpos = -1;
            startpos = rest.indexOf("=") + 1;
            singlefnuttpos = rest.indexOf("'", startpos);
            doublefnuttpos = rest.indexOf('"', startpos);
            spacepos = rest.indexOf(" ", startpos + 2);
            if (spacepos > -1 && (spacepos < singlefnuttpos || singlefnuttpos == -1) && (spacepos < doublefnuttpos || doublefnuttpos == -1)) {
                endpos = rest.indexOf(" ", startpos);
            } else if (doublefnuttpos > -1 && (doublefnuttpos < singlefnuttpos || singlefnuttpos == -1) && (doublefnuttpos < spacepos || spacepos == -1)) {
                endpos = rest.indexOf('"', rest.indexOf('"', startpos) + 1);
            } else if (singlefnuttpos > -1 && (singlefnuttpos < doublefnuttpos || doublefnuttpos == -1) && (singlefnuttpos < spacepos || spacepos == -1)) {
                endpos = rest.indexOf("'", rest.indexOf("'", startpos) + 1);
            }
            if (!endpos || endpos == -1 || endpos < startpos) {endpos = rest.length;}
            done += rest.substring(0, startpos);
            done += attributeValueMode(rest.substring(startpos, endpos + 1));
            rest = rest.substr(endpos + 1);
        }
        return "<span class=\"attribute\">" + done + rest + "</span>";
    }
    function attributeValueMode(txt) {
        return "<span class=\"value\">" + txt + "</span>";
    }
    function commentMode(txt) {
        return "<span class=\"comment\">" + txt + "</span>";
    }
}

// via https://stackoverflow.com/a/7220510
function highlightJson(json) {
    if (typeof json != 'string') {
         json = JSON.stringify(json, undefined, 2);
    }
    json = escapeMathMLSpecialChars(json);
    return json.replace(/("(\\u[a-zA-Z0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?)/g, match => {
        var cls = 'number';
        if (/^"/.test(match)) {
            if (/:$/.test(match)) {
                cls = 'key';
            } else {
                cls = 'string';
            }
        } else if (/true|false/.test(match)) {
            cls = 'boolean';
        } else if (/null/.test(match)) {
            cls = 'null';
        }
        return '<span class="' + cls + '">' + match + '</span>';
    });
}

// only use mathjax where mathml is not natively supported (i.e.
// anything but firefox and safari)
function browserIs(candidate) {
    return navigator.userAgent.toLowerCase().includes(candidate);
}
var loadMathJax = ummlConfig.outputLaTeX || ummlConfig.forceMathJax || !(browserIs('firefox') || (browserIs('safari') && !browserIs('chrome')));
if (loadMathJax) {
    document.write("<script src=\"playground-assets/lib/mathjax/MathJax-2.7.5/MathJax.js?config=TeX-MML-AM_SVG\"></scr" + "ipt>");
}

// if latex output is enabled, hide AST tab (since there is no LaTeX AST) and
// rename source tab
if (ummlConfig.outputLaTeX) {
    document.getElementById("mathml_ast").style.display = "none";
    document.getElementById("source").innerHTML = document.getElementById("source").innerHTML.replace("MathML", "LaTeX");
    measurements_pretty = document.getElementById("measurements_pretty");  // target lock reacquired
}

// if tracing is enabled, add trace tab
if (ummlConfig.tracing) {
    var tempElem = document.createElement('button');
    tempElem.classList.add('tab');
    tempElem.id = 'trace';
    tempElem.innerHTML = 'Trace';
    document.getElementById('pegjs_ast').parentNode.insertBefore(tempElem, document.getElementById('pegjs_ast').nextSibling);

    tempElem = document.createElement('pre');
    tempElem.id = 'output_trace';
    output_pegjs_ast.parentNode.insertBefore(tempElem, output_pegjs_ast.nextSibling);
    var output_trace = document.getElementById('output_trace');
}

// load local storage data from previous page load
if (window.localStorage.getItem('unicodemath')) {
    input.innerHTML = window.localStorage.getItem('unicodemath').replace(/LINEBREAK/g, '\n');
    draw();
}
if (window.localStorage.getItem('active_tab')) {
    setActiveTab(window.localStorage.getItem('active_tab'));
} else {
    setActiveTab(activeTab);
}
if (window.localStorage.getItem('history')) {
    hist = JSON.parse(window.localStorage.getItem('history'));
    displayHistory();
}

// compile and draw mathml code from input field
async function draw() {

    // if required, wait for the parser to be generated, via
    // https://stackoverflow.com/a/39914235
    function sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
    while (typeof ummlParser === "undefined") {
        await sleep(10);
    }

    // avoid doing anything if the input hasn't changed – e.g. when the
    // user has only been moving the cursor
    if (input.value == prevInputValue) {
        return;
    }
    prevInputValue = input.value;

    // clear some stuff
    codepoints.innerHTML = "";
    if (ummlConfig.tracing) {
        output_trace.innerHTML = "";
    }

    // if the input field is empty (as it is in the beginning), avoid doing much
    // with its contents
    if (input.value == "") {
        output.innerHTML = "";
        output_pegjs_ast.innerHTML = "";
        output_preprocess_ast.innerHTML = "";
        output_mathml_ast.innerHTML = "";
        output_source.innerHTML = "";
        measurements_parse.innerHTML = "";
        measurements_transform.innerHTML = "";
        measurements_pretty.innerHTML = "";
        measurements_parse.title = "";
        measurements_transform.title = "";
        measurements_pretty.title = "";
        window.localStorage.setItem('unicodemath', "");
        return;
    }

    // display code points corresponding to the characters
    var codepoints_HTML = "";
    Array.from(input.value).forEach(c => {
        var cp = c.codePointAt(0).toString(16).padStart(4, '0').toUpperCase();

        // highlight special invisible characters and spaces (via
        // https://en.wikipedia.org/wiki/Whitespace_character#Unicode,
        // https://www.ptiglobal.com/2018/04/26/the-beauty-of-unicode-zero-width-characters/,
        // https://330k.github.io/misc_tools/unicode_steganography.html)
        var invisibleChar = [
            "0009",
            "000A",
            "000B",
            "000C",
            "000D",
            "0020",
            "0085",
            "00A0",
            "1680",
            "2000",
            "2001",
            "2002",
            "2003",
            "2004",
            "2005",
            "2006",
            "2007",
            "2008",
            "2009",
            "200A",
            "200B",
            "2028",
            "2029",
            "202F",
            "205F",
            "3000",
            "180E",
            "200B",
            "200C",
            "200D",
            "200E",
            "202A",
            "202C",
            "202D",
            "2060",
            "2061",
            "2062",
            "2063",
            "2064",
            "2800",
            "FEFF",
            ].includes(cp);

        // lookup unicode data for tooltip
        var tooltip = "";
        if (typeof getCodepointData === "function") {
            try {
                var cpd = getCodepointData(cp);
                tooltip = `<b>name</b> ${cpd["name"].replace("<", "&amp;lt;").replace(">", "&amp;gt;")}<br><b>block</b> ${cpd["block"]}<br><b>category</b> ${cpd["category"]}`;
            } catch (e) {
                tooltip = "no info found";
            }
        }

        // lookup tooltip data as previously defined for the on-screen buttons
        // and prepend it
        if (symbolTooltips[c] != undefined && symbolTooltips[c] != "") {
            tooltip = symbolTooltips[c] + "<hr>" + tooltip;
        }

        codepoints_HTML += '<div class="cp' + (invisibleChar ? ' invisible-char' : '') + '" data-tooltip="' + tooltip + '"><div class="p">' + cp + '</div><div class="c">' + c + '</div></div>'

        if (c == "\n") {
            codepoints_HTML += "<br>";
        }
    });
    codepoints.innerHTML = codepoints_HTML;

    // update local storage
    window.localStorage.setItem('unicodemath', input.value.replace(/\n\r?/g, 'LINEBREAK'));

    // clear old results
    output.innerHTML = "";
    output_pegjs_ast.innerHTML = "";
    output_preprocess_ast.innerHTML = "";
    output_mathml_ast.innerHTML = "";
    output_source.innerHTML = "";

    // get input(s) – depending on the ummlConfig.splitInput option, either...
    var inp;
    if (ummlConfig.splitInput) {
        inp = input.value.split("\n");  // ...process each line of input seperately...
    } else {
        inp = [input.value];  // ...or treat the entire input as a UnicodeMath expression
    }

    // compile inputs and accumulate outputs
    var m_parse = [];
    var m_preprocess = [];
    var m_transform = [];
    var m_pretty = [];
    var output_HTML = "";
    var output_pegjs_ast_HTML = "";
    var output_preprocess_ast_HTML = "";
    var output_mathml_ast_HTML = "";
    var output_source_HTML = "";
    inp.forEach(val => {

        // ignore empty lines
        if (val.trim() == "") {
            return;
        }

        // tell the user that unicodemath delimiters aren't required if they've
        // used them
        if (val.includes("⁅") || val.includes("⁆")) {
            output_HTML += '<div class="notice">Note that the ⁅UnicodeMath delimiters⁆ you\'ve used in the expression ↓below↓ aren\'t required – ' + (ummlConfig.splitInput? 'each line of the' : 'the entire') + ' input is automatically treated as a UnicodeMath expression.</div>';
        }

        if (!ummlConfig.outputLaTeX) {

            // mathml output
            var mathml, details;
            ({mathml, details} = unicodemathml(val, ummlConfig.displaystyle));
            output_HTML += mathml;
            output_source_HTML += highlightMathML(escapeMathMLSpecialChars(indentMathML(mathml))) + "\n";

            // show parse tree and mathml ast
            if (details["intermediates"]) {
                var pegjs_ast = details["intermediates"]["parse"];
                var preprocess_ast = details["intermediates"]["preprocess"];
                var mathml_ast = details["intermediates"]["transform"];

                output_pegjs_ast_HTML += highlightJson(pegjs_ast) + "\n";
                output_preprocess_ast_HTML += highlightJson(preprocess_ast) + "\n";
                output_mathml_ast_HTML += highlightJson(JSON.stringify(mathml_ast, null, 2)) + "\n";
            }
        } else {

            // latex output
            var latex, details;
            ({latex, details} = unicodemathtex(val, ummlConfig.displaystyle));
            output_HTML += latex;
            output_source_HTML += escapeMathMLSpecialChars(latex) + "\n";

            // show parse tree
            if (details["intermediates"]) {
                var pegjs_ast = details["intermediates"]["parse"];
                var preprocess_ast = details["intermediates"]["preprocess"];

                output_pegjs_ast_HTML += highlightJson(pegjs_ast) + "\n";
                output_preprocess_ast_HTML += highlightJson(preprocess_ast) + "\n";
            }
        }

        // tally measurements
        var extractMeasurement = name => parseInt(details["measurements"][name], 10);
        if (details["measurements"]) {
            m_parse.push(extractMeasurement("parse"));
            m_preprocess.push(extractMeasurement("preprocess"));
            m_transform.push(extractMeasurement("transform"));
            m_pretty.push(extractMeasurement("pretty"));
        }
    });

    // write outputs to dom (doing this inside the loop becomes excruciatingly
    // slow when more than a few dozen inputs are present)
    output.innerHTML = output_HTML;
    output_pegjs_ast.innerHTML = output_pegjs_ast_HTML;
    output_preprocess_ast.innerHTML = output_preprocess_ast_HTML;
    output_mathml_ast.innerHTML = output_mathml_ast_HTML;
    output_source.innerHTML = output_source_HTML;

    // display measurements
    var sum = a => a.reduce((a, b) => a + b, 0);
    measurements_parse.innerHTML = sum(m_parse) + 'ms';
    measurements_preprocess.innerHTML = sum(m_preprocess) + 'ms';
    measurements_transform.innerHTML = sum(m_transform) + 'ms';
    measurements_pretty.innerHTML = sum(m_pretty) + 'ms';
    if (m_parse.length > 1) {
        measurements_parse.title = m_parse.map(m => m + 'ms').join(" + ");
        measurements_preprocess.title = m_preprocess.map(m => m + 'ms').join(" + ");
        measurements_transform.title = m_transform.map(m => m + 'ms').join(" + ");
        measurements_pretty.title = m_pretty.map(m => m + 'ms').join(" + ");
    } else {
        measurements_parse.title = "";
        measurements_preprocess.title = "";
        measurements_transform.title = "";
        measurements_pretty.title = "";
    }

    // if mathjax is loaded, tell it to redraw math
    if (loadMathJax && typeof MathJax != "undefined") {
        MathJax.Hub.Queue(["Typeset", MathJax.Hub, output]);
    }
}

// add a symbol (or string) to history
function addToHistory(symbols) {

    // remove previous occurrences of symbols from history
    hist = hist.filter(s => s != symbols);

    hist.push(symbols);
    localStorage.setItem('history', JSON.stringify(hist));

    displayHistory();
}

function displayHistory() {

    // don't overwhelm the browser
    var historySize = 50;

    //                  ↙ clone array before reversing
    var histo = hist.slice().reverse().slice(0,historySize).map(c => {

        // get tooltip data
        var t = "";
        if (symbolTooltips[c] != undefined && symbolTooltips[c] != "") {
            t = symbolTooltips[c];
        }

        return `<button class="unicode" data-tooltip="${t}">${c}</button>`;
    });
    document.getElementById('history').innerHTML = histo.join('');
}

function setActiveTab(id) {
    if (!document.getElementById(id)) {
        id = activeTab;
    }

    Array.from(document.getElementsByClassName('tab')).map(t => t.classList.remove('active'));
    document.getElementById(id).classList.add('active');

    Array.from(document.querySelectorAll(".tabcontent pre")).map(p => p.style.display = "none");
    document.getElementById("output_" + id).style.display = "block";

    window.localStorage.setItem('active_tab', id);
}

$(input).on("change keyup paste", function() {
    draw();
});
$('button.tab').click(function () {
    setActiveTab(this.id);
});

// insert one or multiple characters at the current cursor position of
// the input field or, if there is no cursor, append them to its value,
// via https://stackoverflow.com/a/11077016
function insertAtCursorPos(symbols) {
    if (input.selectionStart || input.selectionStart == '0') {
        var startPos = input.selectionStart;
        var endPos = input.selectionEnd;
        input.value = input.value.substring(0, startPos)
            + symbols
            + input.value.substring(endPos, input.value.length);
        input.selectionStart = startPos + symbols.length;
        input.selectionEnd = startPos + symbols.length;
    } else {
        input.value += symbols;
    }
    input.focus();
    draw();
}

// because the history is updated after page load, which kills any
// previously defined event handlers, we can't simply do
// "$('.button').click(...)"
$(document).on('click', function (e) {
    if ($(e.target).hasClass('unicode')) {
        insertAtCursorPos(e.target.innerText);
        addToHistory(e.target.innerText);
    } else if ($(e.target).hasClass('example')) {
        insertAtCursorPos(e.target.innerText);
    }
});

// custom codepoint insertion
$('#codepoint').keypress(function (e) {
    var key = e.which;
    if (key == 13) {  // enter
        $('button#insert_codepoint').click();
    }
});
$('button#insert_codepoint').click(function () {
    var symbol = String.fromCodePoint("0x" + $('#codepoint').val())
    insertAtCursorPos(symbol);
    addToHistory(symbol);
});

// custom control word insertion
// should match controlWords variable in unicodemathml.js
var controlWords = {

    // from tech note: Appendix B. Character Keywords and Properties
    'above': '2534',
    'acute': '0301',
    'aleph': '2135',
    'alpha': '03B1',
    'amalg': '2210',
    'angle': '2220',
    'aoint': '2233',
    'approx': '2248',
    'asmash': '2B06',
    'ast': '2217',
    'asymp': '224D',
    'atop': '00A6',
    'Bar': '033F',
    'bar': '0305',
    'because': '2235',
    'begin': '3016',
    'below': '252C',
    'beta': '03B2',
    'beth': '2136',
    'bot': '22A5',
    'bigcap': '22C2',
    'bigcup': '22C2',
    'bigodot': '2A00',
    'bigoplus': '2A01',
    'bigotimes': '2A02',
    'bigsqcup': '2A06',
    'biguplus': '2A04',
    'bigvee': '22C1',
    'bigwedge': '22C0',
    'bowtie': '22C8',
    'bot': '22A5',
    'box': '25A1',
    'bra': '27E8',
    'breve': '0306',
    'bullet': '2219',
    'cap': '2229',
    'cbrt': '221B',
    'cdot': '22C5',
    'cdots': '22EF',
    'check': '030C',
    'chi': '03C7',
    'circ': '2218',
    'close': '2524',
    'clubsuit': '2663',
    'coint': '2232',
    'cong': '2245',
    'cup': '222A',
    'daleth': '2138',
    'dashv': '22A3',
    'Dd': '2145',
    'dd': '2146',
    'ddddot': '20DC',
    'dddot': '20DB',
    'ddot': '0308',
    'ddots': '22F1',
    'degree': '00B0',
    'Delta': '0394',
    'delta': '03B4',
    'diamond': '22C4',
    'diamondsuit': '2662',
    'div': '00F7',
    'dot': '0307',
    'doteq': '2250',
    'dots': '2026',
    'Downarrow': '21D3',
    'downarrow': '2193',
    'dsmash': '2B07',
    'ee': '2147',
    'ell': '2113',
    'emptyset': '2205',
    'emsp': '2003',
    'end': '3017',
    'ensp': '2002',
    'epsilon': '03F5',
    'eqarray': '2588',
    'eqno': '0023',
    'equiv': '2261',
    'eta': '03B7',
    'exists': '2203',
    'forall': '2200',
    'funcapply': '2061',
    'Gamma': '0393',
    'gamma': '03B3',
    'ge': '2265',
    'geq': '2265',
    'gets': '2190',
    'gg': '226B',
    'gimel': '2137',
    'grave': '0300',
    'hairsp': '200A',
    'hat': '0302',
    'hbar': '210F',
    'heartsuit': '2661',
    'hookleftarrow': '21A9',
    'hookrightarrow': '21AA',
    'hphantom': '2B04',
    'hsmash': '2B0C',
    'hvec': '20D1',
    'ii': '2148',
    'iiiint': '2A0C',
    'iiint': '222D',
    'iint': '222C',
    'Im': '2111',
    'imath': '0131',
    'in': '2208',
    'inc': '2206',
    'infty': '221E',
    'int': '222B',
    'iota': '03B9',
    'jj': '2149',
    'jmath': '0237',
    'kappa': '03BA',
    'ket': '27E9',
    'Lambda': '039B',
    'lambda': '03BB',
    'langle': '27E8',
    'lbrace': '007B',
    'lbrack': '005B',
    'lceil': '2308',
    'ldiv': '2215',
    'ldots': '2026',
    'le': '2264',
    'Leftarrow': '21D0',
    'leftarrow': '2190',
    'leftharpoondown': '21BD',
    'leftharpoonup': '21BC',
    'Leftrightarrow': '21D4',
    'leftrightarrow': '2194',
    'leq': '2264',
    'lfloor': '230A',
    'll': '226A',
    'Longleftarrow': '27F8',
    'longleftarrow': '27F5',
    'Longleftrightarrow': '27FA',
    'longleftrightarrow': '27F7',
    'Longrightarrow': '27F9',
    'longrightarrow': '27F6',
    'mapsto': '21A6',
    'matrix': '25A0',
    'medsp': '205F',
    'mid': '2223',
    'models': '22A8',
    'mp': '2213',
    'mu': '03BC',
    'nabla': '2207',
    'naryand': '2592',
    'nbsp': '00A0',
    'ndiv': '2298',
    'ne': '2260',
    'nearrow': '2197',
    'neg': '00AC',
    'neq': '2260',
    'ni': '220B',
    'norm': '2016',
    'nu': '03BD',
    'nwarrow': '2196',
    'odot': '2299',
    'of': '2592',
    'oiiint': '2230',
    'oiint': '222F',
    'oint': '222E',
    'Omega': '03A9',
    'omega': '03C9',
    'ominus': '2296',
    'open': '251C',
    'oplus': '2295',
    'oslash': '2298',
    'otimes': '2297',
    'over': '002F',
    'overbar': '00AF',
    'overbrace': '23DE',
    'overparen': '23DC',
    'parallel': '2225',
    'partial': '2202',
    'phantom': '27E1',
    'Phi': '03A6',
    'phi': '03D5',
    'Pi': '03A0',
    'pi': '03C0',
    'pm': '00B1',
    'pppprime': '2057',
    'ppprime': '2034',
    'pprime': '2033',
    'prcue': '227C',
    'prec': '227A',
    'preceq': '2AAF',
    'preccurlyeq': '227C',
    'prime': '2032',
    'prod': '220F',
    'propto': '221D',
    'Psi': '03A8',
    'psi': '03C8',
    'qdrt': '221C',
    'rangle': '27E9',
    'ratio': '2236',
    'rbrace': '007D',
    'rbrack': '005D',
    'rceil': '2309',
    'rddots': '22F0',
    'Re': '211C',
    'rect': '25AD',
    'rfloor': '230B',
    'rho': '03C1',
    'Rightarrow': '21D2',
    'rightarrow': '2192',
    'rightharpoondown': '21C1',
    'rightharpoonup': '21C0',
    'rrect': '25A2',
    'sdiv': '2044',
    'searrow': '2198',
    'setminus': '2216',
    'Sigma': '03A3',
    'sigma': '03C3',
    'sim': '223C',
    'simeq': '2243',
    'smash': '2B0D',
    'spadesuit': '2660',
    'sqcap': '2293',
    'sqcup': '2294',
    'sqrt': '221A',
    'sqsubseteq': '2291',
    'sqsuperseteq': '2292',
    'star': '22C6',
    'subset': '2282',
    'subseteq': '2286',
    'succ': '227B',
    'succeq': '227D',
    'sum': '2211',
    'superset': '2283',
    'superseteq': '2287',
    'swarrow': '2199',
    'tau': '03C4',
    'therefore': '2234',
    'Theta': '0398',
    'theta': '03B8',
    'thicksp': '2005',
    'thinsp': '2006',
    'tilde': '0303',
    'times': '00D7',
    'to': '2192',
    'top': '22A4',
    'tvec': '20E1',
    'underbar': '2581',
    'underbrace': '23DF',
    'underparen': '23DD',
    'Uparrow': '21D1',
    'uparrow': '2191',
    'Updownarrow': '21D5',
    'updownarrow': '2195',
    'uplus': '228E',
    'Upsilon': '03A5',
    'upsilon': '03C5',
    'varepsilon': '03B5',
    'varphi': '03C6',
    'varpi': '03D6',
    'varrho': '03F1',
    'varsigma': '03C2',
    'vartheta': '03D1',
    'vbar': '2502',
    'vdash': '22A2',
    'vdots': '22EE',
    'vec': '20D7',
    'vee': '2228',
    'Vert': '2016',
    'vert': '007C',
    'vphantom': '21F3',
    'vthicksp': '2004',
    'wedge': '2227',
    'wp': '2118',
    'wr': '2240',
    'Xi': '039E',
    'xi': '03BE',
    'zeta': '03B6',
    'zwnj': '200C',
    'zwsp': '200B',

    // based on section 3.6, "Square Roots and Radicals" of tech note
    'root': '221A',

    // based on https://www.cs.bgu.ac.il/~khitron/Equation%20Editor.pdf
    'boxdot': '22A1',
    'boxminus': '229F',
    'boxplus': '229E',
    'degc': '2103',
    'degf': '2109',
    'Deltaeq': '225C',
    'frown': '2311',
    'inc': '2206',
    'left': '251C',
    'lmoust': '23B0',
    'contain': '220B',
    'perp': '22A5',
    'right': '2524',
    'rmoust': '23B1',
    'smile': '2323',
    'overbracket': '23B4',
    'underbracket': '23B5',
    'overshell': '23E0',
    'undershell': '23E1'
};
$('#controlword').keydown(function (e) {
    $('#controlword').css('color', 'black');
});
$('#controlword').keypress(function (e) {
    var key = e.which;
    if (key == 13) {  // enter
        $('button#insert_controlword').click();
    }
});
$('button#insert_controlword').click(function () {
    var cw = $('#controlword').val();
    if (!(cw in controlWords)) {

        // try removing leading slash
        cw = cw.split("\\")[1];
    }
    if (cw in controlWords) {
        var symbol = String.fromCodePoint("0x" + controlWords[cw]);
        insertAtCursorPos(symbol);
        addToHistory(symbol);
    } else {
        $('#controlword').css('color', 'red');
    }
});

// math font conversion
// should match mathFonts variable in unicodemathml.js
var mathFonts = {

    // courtesy of
    // https://en.wikipedia.org/wiki/Mathematical_Alphanumeric_Symbols
    // and sublime text's multiple cursors
    'A': {'serif-bold': '𝐀', 'serif-italic': '𝐴', 'serif-bolditalic': '𝑨', 'sans-normal': '𝖠', 'sans-bold': '𝗔', 'sans-italic': '𝘈', 'sans-bolditalic': '𝘼', 'script-normal': '𝒜', 'script-bold': '𝓐', 'fraktur-normal': '𝔄', 'fraktur-bold': '𝕬', 'monospace-normal': '𝙰', 'doublestruck-normal': '𝔸'},
    'B': {'serif-bold': '𝐁', 'serif-italic': '𝐵', 'serif-bolditalic': '𝑩', 'sans-normal': '𝖡', 'sans-bold': '𝗕', 'sans-italic': '𝘉', 'sans-bolditalic': '𝘽', 'script-normal': 'ℬ', 'script-bold': '𝓑', 'fraktur-normal': '𝔅', 'fraktur-bold': '𝕭', 'monospace-normal': '𝙱', 'doublestruck-normal': '𝔹'},
    'C': {'serif-bold': '𝐂', 'serif-italic': '𝐶', 'serif-bolditalic': '𝑪', 'sans-normal': '𝖢', 'sans-bold': '𝗖', 'sans-italic': '𝘊', 'sans-bolditalic': '𝘾', 'script-normal': '𝒞', 'script-bold': '𝓒', 'fraktur-normal': 'ℭ', 'fraktur-bold': '𝕮', 'monospace-normal': '𝙲', 'doublestruck-normal': 'ℂ'},
    'D': {'serif-bold': '𝐃', 'serif-italic': '𝐷', 'serif-bolditalic': '𝑫', 'sans-normal': '𝖣', 'sans-bold': '𝗗', 'sans-italic': '𝘋', 'sans-bolditalic': '𝘿', 'script-normal': '𝒟', 'script-bold': '𝓓', 'fraktur-normal': '𝔇', 'fraktur-bold': '𝕯', 'monospace-normal': '𝙳', 'doublestruck-normal': '𝔻'},
    'E': {'serif-bold': '𝐄', 'serif-italic': '𝐸', 'serif-bolditalic': '𝑬', 'sans-normal': '𝖤', 'sans-bold': '𝗘', 'sans-italic': '𝘌', 'sans-bolditalic': '𝙀', 'script-normal': 'ℰ', 'script-bold': '𝓔', 'fraktur-normal': '𝔈', 'fraktur-bold': '𝕰', 'monospace-normal': '𝙴', 'doublestruck-normal': '𝔼'},
    'F': {'serif-bold': '𝐅', 'serif-italic': '𝐹', 'serif-bolditalic': '𝑭', 'sans-normal': '𝖥', 'sans-bold': '𝗙', 'sans-italic': '𝘍', 'sans-bolditalic': '𝙁', 'script-normal': 'ℱ', 'script-bold': '𝓕', 'fraktur-normal': '𝔉', 'fraktur-bold': '𝕱', 'monospace-normal': '𝙵', 'doublestruck-normal': '𝔽'},
    'G': {'serif-bold': '𝐆', 'serif-italic': '𝐺', 'serif-bolditalic': '𝑮', 'sans-normal': '𝖦', 'sans-bold': '𝗚', 'sans-italic': '𝘎', 'sans-bolditalic': '𝙂', 'script-normal': '𝒢', 'script-bold': '𝓖', 'fraktur-normal': '𝔊', 'fraktur-bold': '𝕲', 'monospace-normal': '𝙶', 'doublestruck-normal': '𝔾'},
    'H': {'serif-bold': '𝐇', 'serif-italic': '𝐻', 'serif-bolditalic': '𝑯', 'sans-normal': '𝖧', 'sans-bold': '𝗛', 'sans-italic': '𝘏', 'sans-bolditalic': '𝙃', 'script-normal': 'ℋ', 'script-bold': '𝓗', 'fraktur-normal': 'ℌ', 'fraktur-bold': '𝕳', 'monospace-normal': '𝙷', 'doublestruck-normal': 'ℍ'},
    'I': {'serif-bold': '𝐈', 'serif-italic': '𝐼', 'serif-bolditalic': '𝑰', 'sans-normal': '𝖨', 'sans-bold': '𝗜', 'sans-italic': '𝘐', 'sans-bolditalic': '𝙄', 'script-normal': 'ℐ', 'script-bold': '𝓘', 'fraktur-normal': 'ℑ', 'fraktur-bold': '𝕴', 'monospace-normal': '𝙸', 'doublestruck-normal': '𝕀'},
    'J': {'serif-bold': '𝐉', 'serif-italic': '𝐽', 'serif-bolditalic': '𝑱', 'sans-normal': '𝖩', 'sans-bold': '𝗝', 'sans-italic': '𝘑', 'sans-bolditalic': '𝙅', 'script-normal': '𝒥', 'script-bold': '𝓙', 'fraktur-normal': '𝔍', 'fraktur-bold': '𝕵', 'monospace-normal': '𝙹', 'doublestruck-normal': '𝕁'},
    'K': {'serif-bold': '𝐊', 'serif-italic': '𝐾', 'serif-bolditalic': '𝑲', 'sans-normal': '𝖪', 'sans-bold': '𝗞', 'sans-italic': '𝘒', 'sans-bolditalic': '𝙆', 'script-normal': '𝒦', 'script-bold': '𝓚', 'fraktur-normal': '𝔎', 'fraktur-bold': '𝕶', 'monospace-normal': '𝙺', 'doublestruck-normal': '𝕂'},
    'L': {'serif-bold': '𝐋', 'serif-italic': '𝐿', 'serif-bolditalic': '𝑳', 'sans-normal': '𝖫', 'sans-bold': '𝗟', 'sans-italic': '𝘓', 'sans-bolditalic': '𝙇', 'script-normal': 'ℒ', 'script-bold': '𝓛', 'fraktur-normal': '𝔏', 'fraktur-bold': '𝕷', 'monospace-normal': '𝙻', 'doublestruck-normal': '𝕃'},
    'M': {'serif-bold': '𝐌', 'serif-italic': '𝑀', 'serif-bolditalic': '𝑴', 'sans-normal': '𝖬', 'sans-bold': '𝗠', 'sans-italic': '𝘔', 'sans-bolditalic': '𝙈', 'script-normal': 'ℳ', 'script-bold': '𝓜', 'fraktur-normal': '𝔐', 'fraktur-bold': '𝕸', 'monospace-normal': '𝙼', 'doublestruck-normal': '𝕄'},
    'N': {'serif-bold': '𝐍', 'serif-italic': '𝑁', 'serif-bolditalic': '𝑵', 'sans-normal': '𝖭', 'sans-bold': '𝗡', 'sans-italic': '𝘕', 'sans-bolditalic': '𝙉', 'script-normal': '𝒩', 'script-bold': '𝓝', 'fraktur-normal': '𝔑', 'fraktur-bold': '𝕹', 'monospace-normal': '𝙽', 'doublestruck-normal': 'ℕ'},
    'O': {'serif-bold': '𝐎', 'serif-italic': '𝑂', 'serif-bolditalic': '𝑶', 'sans-normal': '𝖮', 'sans-bold': '𝗢', 'sans-italic': '𝘖', 'sans-bolditalic': '𝙊', 'script-normal': '𝒪', 'script-bold': '𝓞', 'fraktur-normal': '𝔒', 'fraktur-bold': '𝕺', 'monospace-normal': '𝙾', 'doublestruck-normal': '𝕆'},
    'P': {'serif-bold': '𝐏', 'serif-italic': '𝑃', 'serif-bolditalic': '𝑷', 'sans-normal': '𝖯', 'sans-bold': '𝗣', 'sans-italic': '𝘗', 'sans-bolditalic': '𝙋', 'script-normal': '𝒫', 'script-bold': '𝓟', 'fraktur-normal': '𝔓', 'fraktur-bold': '𝕻', 'monospace-normal': '𝙿', 'doublestruck-normal': 'ℙ'},
    'Q': {'serif-bold': '𝐐', 'serif-italic': '𝑄', 'serif-bolditalic': '𝑸', 'sans-normal': '𝖰', 'sans-bold': '𝗤', 'sans-italic': '𝘘', 'sans-bolditalic': '𝙌', 'script-normal': '𝒬', 'script-bold': '𝓠', 'fraktur-normal': '𝔔', 'fraktur-bold': '𝕼', 'monospace-normal': '𝚀', 'doublestruck-normal': 'ℚ'},
    'R': {'serif-bold': '𝐑', 'serif-italic': '𝑅', 'serif-bolditalic': '𝑹', 'sans-normal': '𝖱', 'sans-bold': '𝗥', 'sans-italic': '𝘙', 'sans-bolditalic': '𝙍', 'script-normal': 'ℛ', 'script-bold': '𝓡', 'fraktur-normal': 'ℜ', 'fraktur-bold': '𝕽', 'monospace-normal': '𝚁', 'doublestruck-normal': 'ℝ'},
    'S': {'serif-bold': '𝐒', 'serif-italic': '𝑆', 'serif-bolditalic': '𝑺', 'sans-normal': '𝖲', 'sans-bold': '𝗦', 'sans-italic': '𝘚', 'sans-bolditalic': '𝙎', 'script-normal': '𝒮', 'script-bold': '𝓢', 'fraktur-normal': '𝔖', 'fraktur-bold': '𝕾', 'monospace-normal': '𝚂', 'doublestruck-normal': '𝕊'},
    'T': {'serif-bold': '𝐓', 'serif-italic': '𝑇', 'serif-bolditalic': '𝑻', 'sans-normal': '𝖳', 'sans-bold': '𝗧', 'sans-italic': '𝘛', 'sans-bolditalic': '𝙏', 'script-normal': '𝒯', 'script-bold': '𝓣', 'fraktur-normal': '𝔗', 'fraktur-bold': '𝕿', 'monospace-normal': '𝚃', 'doublestruck-normal': '𝕋'},
    'U': {'serif-bold': '𝐔', 'serif-italic': '𝑈', 'serif-bolditalic': '𝑼', 'sans-normal': '𝖴', 'sans-bold': '𝗨', 'sans-italic': '𝘜', 'sans-bolditalic': '𝙐', 'script-normal': '𝒰', 'script-bold': '𝓤', 'fraktur-normal': '𝔘', 'fraktur-bold': '𝖀', 'monospace-normal': '𝚄', 'doublestruck-normal': '𝕌'},
    'V': {'serif-bold': '𝐕', 'serif-italic': '𝑉', 'serif-bolditalic': '𝑽', 'sans-normal': '𝖵', 'sans-bold': '𝗩', 'sans-italic': '𝘝', 'sans-bolditalic': '𝙑', 'script-normal': '𝒱', 'script-bold': '𝓥', 'fraktur-normal': '𝔙', 'fraktur-bold': '𝖁', 'monospace-normal': '𝚅', 'doublestruck-normal': '𝕍'},
    'W': {'serif-bold': '𝐖', 'serif-italic': '𝑊', 'serif-bolditalic': '𝑾', 'sans-normal': '𝖶', 'sans-bold': '𝗪', 'sans-italic': '𝘞', 'sans-bolditalic': '𝙒', 'script-normal': '𝒲', 'script-bold': '𝓦', 'fraktur-normal': '𝔚', 'fraktur-bold': '𝖂', 'monospace-normal': '𝚆', 'doublestruck-normal': '𝕎'},
    'X': {'serif-bold': '𝐗', 'serif-italic': '𝑋', 'serif-bolditalic': '𝑿', 'sans-normal': '𝖷', 'sans-bold': '𝗫', 'sans-italic': '𝘟', 'sans-bolditalic': '𝙓', 'script-normal': '𝒳', 'script-bold': '𝓧', 'fraktur-normal': '𝔛', 'fraktur-bold': '𝖃', 'monospace-normal': '𝚇', 'doublestruck-normal': '𝕏'},
    'Y': {'serif-bold': '𝐘', 'serif-italic': '𝑌', 'serif-bolditalic': '𝒀', 'sans-normal': '𝖸', 'sans-bold': '𝗬', 'sans-italic': '𝘠', 'sans-bolditalic': '𝙔', 'script-normal': '𝒴', 'script-bold': '𝓨', 'fraktur-normal': '𝔜', 'fraktur-bold': '𝖄', 'monospace-normal': '𝚈', 'doublestruck-normal': '𝕐'},
    'Z': {'serif-bold': '𝐙', 'serif-italic': '𝑍', 'serif-bolditalic': '𝒁', 'sans-normal': '𝖹', 'sans-bold': '𝗭', 'sans-italic': '𝘡', 'sans-bolditalic': '𝙕', 'script-normal': '𝒵', 'script-bold': '𝓩', 'fraktur-normal': 'ℨ', 'fraktur-bold': '𝖅', 'monospace-normal': '𝚉', 'doublestruck-normal': 'ℤ'},
    'a': {'serif-bold': '𝐚', 'serif-italic': '𝑎', 'serif-bolditalic': '𝒂', 'sans-normal': '𝖺', 'sans-bold': '𝗮', 'sans-italic': '𝘢', 'sans-bolditalic': '𝙖', 'script-normal': '𝒶', 'script-bold': '𝓪', 'fraktur-normal': '𝔞', 'fraktur-bold': '𝖆', 'monospace-normal': '𝚊', 'doublestruck-normal': '𝕒'},
    'b': {'serif-bold': '𝐛', 'serif-italic': '𝑏', 'serif-bolditalic': '𝒃', 'sans-normal': '𝖻', 'sans-bold': '𝗯', 'sans-italic': '𝘣', 'sans-bolditalic': '𝙗', 'script-normal': '𝒷', 'script-bold': '𝓫', 'fraktur-normal': '𝔟', 'fraktur-bold': '𝖇', 'monospace-normal': '𝚋', 'doublestruck-normal': '𝕓'},
    'c': {'serif-bold': '𝐜', 'serif-italic': '𝑐', 'serif-bolditalic': '𝒄', 'sans-normal': '𝖼', 'sans-bold': '𝗰', 'sans-italic': '𝘤', 'sans-bolditalic': '𝙘', 'script-normal': '𝒸', 'script-bold': '𝓬', 'fraktur-normal': '𝔠', 'fraktur-bold': '𝖈', 'monospace-normal': '𝚌', 'doublestruck-normal': '𝕔'},
    'd': {'serif-bold': '𝐝', 'serif-italic': '𝑑', 'serif-bolditalic': '𝒅', 'sans-normal': '𝖽', 'sans-bold': '𝗱', 'sans-italic': '𝘥', 'sans-bolditalic': '𝙙', 'script-normal': '𝒹', 'script-bold': '𝓭', 'fraktur-normal': '𝔡', 'fraktur-bold': '𝖉', 'monospace-normal': '𝚍', 'doublestruck-normal': '𝕕'},
    'e': {'serif-bold': '𝐞', 'serif-italic': '𝑒', 'serif-bolditalic': '𝒆', 'sans-normal': '𝖾', 'sans-bold': '𝗲', 'sans-italic': '𝘦', 'sans-bolditalic': '𝙚', 'script-normal': 'ℯ', 'script-bold': '𝓮', 'fraktur-normal': '𝔢', 'fraktur-bold': '𝖊', 'monospace-normal': '𝚎', 'doublestruck-normal': '𝕖'},
    'f': {'serif-bold': '𝐟', 'serif-italic': '𝑓', 'serif-bolditalic': '𝒇', 'sans-normal': '𝖿', 'sans-bold': '𝗳', 'sans-italic': '𝘧', 'sans-bolditalic': '𝙛', 'script-normal': '𝒻', 'script-bold': '𝓯', 'fraktur-normal': '𝔣', 'fraktur-bold': '𝖋', 'monospace-normal': '𝚏', 'doublestruck-normal': '𝕗'},
    'g': {'serif-bold': '𝐠', 'serif-italic': '𝑔', 'serif-bolditalic': '𝒈', 'sans-normal': '𝗀', 'sans-bold': '𝗴', 'sans-italic': '𝘨', 'sans-bolditalic': '𝙜', 'script-normal': 'ℊ', 'script-bold': '𝓰', 'fraktur-normal': '𝔤', 'fraktur-bold': '𝖌', 'monospace-normal': '𝚐', 'doublestruck-normal': '𝕘'},
    'h': {'serif-bold': '𝐡', 'serif-italic': 'ℎ', 'serif-bolditalic': '𝒉', 'sans-normal': '𝗁', 'sans-bold': '𝗵', 'sans-italic': '𝘩', 'sans-bolditalic': '𝙝', 'script-normal': '𝒽', 'script-bold': '𝓱', 'fraktur-normal': '𝔥', 'fraktur-bold': '𝖍', 'monospace-normal': '𝚑', 'doublestruck-normal': '𝕙'},
    'i': {'serif-bold': '𝐢', 'serif-italic': '𝑖', 'serif-bolditalic': '𝒊', 'sans-normal': '𝗂', 'sans-bold': '𝗶', 'sans-italic': '𝘪', 'sans-bolditalic': '𝙞', 'script-normal': '𝒾', 'script-bold': '𝓲', 'fraktur-normal': '𝔦', 'fraktur-bold': '𝖎', 'monospace-normal': '𝚒', 'doublestruck-normal': '𝕚'},
    'j': {'serif-bold': '𝐣', 'serif-italic': '𝑗', 'serif-bolditalic': '𝒋', 'sans-normal': '𝗃', 'sans-bold': '𝗷', 'sans-italic': '𝘫', 'sans-bolditalic': '𝙟', 'script-normal': '𝒿', 'script-bold': '𝓳', 'fraktur-normal': '𝔧', 'fraktur-bold': '𝖏', 'monospace-normal': '𝚓', 'doublestruck-normal': '𝕛'},
    'k': {'serif-bold': '𝐤', 'serif-italic': '𝑘', 'serif-bolditalic': '𝒌', 'sans-normal': '𝗄', 'sans-bold': '𝗸', 'sans-italic': '𝘬', 'sans-bolditalic': '𝙠', 'script-normal': '𝓀', 'script-bold': '𝓴', 'fraktur-normal': '𝔨', 'fraktur-bold': '𝖐', 'monospace-normal': '𝚔', 'doublestruck-normal': '𝕜'},
    'l': {'serif-bold': '𝐥', 'serif-italic': '𝑙', 'serif-bolditalic': '𝒍', 'sans-normal': '𝗅', 'sans-bold': '𝗹', 'sans-italic': '𝘭', 'sans-bolditalic': '𝙡', 'script-normal': '𝓁', 'script-bold': '𝓵', 'fraktur-normal': '𝔩', 'fraktur-bold': '𝖑', 'monospace-normal': '𝚕', 'doublestruck-normal': '𝕝'},
    'm': {'serif-bold': '𝐦', 'serif-italic': '𝑚', 'serif-bolditalic': '𝒎', 'sans-normal': '𝗆', 'sans-bold': '𝗺', 'sans-italic': '𝘮', 'sans-bolditalic': '𝙢', 'script-normal': '𝓂', 'script-bold': '𝓶', 'fraktur-normal': '𝔪', 'fraktur-bold': '𝖒', 'monospace-normal': '𝚖', 'doublestruck-normal': '𝕞'},
    'n': {'serif-bold': '𝐧', 'serif-italic': '𝑛', 'serif-bolditalic': '𝒏', 'sans-normal': '𝗇', 'sans-bold': '𝗻', 'sans-italic': '𝘯', 'sans-bolditalic': '𝙣', 'script-normal': '𝓃', 'script-bold': '𝓷', 'fraktur-normal': '𝔫', 'fraktur-bold': '𝖓', 'monospace-normal': '𝚗', 'doublestruck-normal': '𝕟'},
    'o': {'serif-bold': '𝐨', 'serif-italic': '𝑜', 'serif-bolditalic': '𝒐', 'sans-normal': '𝗈', 'sans-bold': '𝗼', 'sans-italic': '𝘰', 'sans-bolditalic': '𝙤', 'script-normal': 'ℴ', 'script-bold': '𝓸', 'fraktur-normal': '𝔬', 'fraktur-bold': '𝖔', 'monospace-normal': '𝚘', 'doublestruck-normal': '𝕠'},
    'p': {'serif-bold': '𝐩', 'serif-italic': '𝑝', 'serif-bolditalic': '𝒑', 'sans-normal': '𝗉', 'sans-bold': '𝗽', 'sans-italic': '𝘱', 'sans-bolditalic': '𝙥', 'script-normal': '𝓅', 'script-bold': '𝓹', 'fraktur-normal': '𝔭', 'fraktur-bold': '𝖕', 'monospace-normal': '𝚙', 'doublestruck-normal': '𝕡'},
    'q': {'serif-bold': '𝐪', 'serif-italic': '𝑞', 'serif-bolditalic': '𝒒', 'sans-normal': '𝗊', 'sans-bold': '𝗾', 'sans-italic': '𝘲', 'sans-bolditalic': '𝙦', 'script-normal': '𝓆', 'script-bold': '𝓺', 'fraktur-normal': '𝔮', 'fraktur-bold': '𝖖', 'monospace-normal': '𝚚', 'doublestruck-normal': '𝕢'},
    'r': {'serif-bold': '𝐫', 'serif-italic': '𝑟', 'serif-bolditalic': '𝒓', 'sans-normal': '𝗋', 'sans-bold': '𝗿', 'sans-italic': '𝘳', 'sans-bolditalic': '𝙧', 'script-normal': '𝓇', 'script-bold': '𝓻', 'fraktur-normal': '𝔯', 'fraktur-bold': '𝖗', 'monospace-normal': '𝚛', 'doublestruck-normal': '𝕣'},
    's': {'serif-bold': '𝐬', 'serif-italic': '𝑠', 'serif-bolditalic': '𝒔', 'sans-normal': '𝗌', 'sans-bold': '𝘀', 'sans-italic': '𝘴', 'sans-bolditalic': '𝙨', 'script-normal': '𝓈', 'script-bold': '𝓼', 'fraktur-normal': '𝔰', 'fraktur-bold': '𝖘', 'monospace-normal': '𝚜', 'doublestruck-normal': '𝕤'},
    't': {'serif-bold': '𝐭', 'serif-italic': '𝑡', 'serif-bolditalic': '𝒕', 'sans-normal': '𝗍', 'sans-bold': '𝘁', 'sans-italic': '𝘵', 'sans-bolditalic': '𝙩', 'script-normal': '𝓉', 'script-bold': '𝓽', 'fraktur-normal': '𝔱', 'fraktur-bold': '𝖙', 'monospace-normal': '𝚝', 'doublestruck-normal': '𝕥'},
    'u': {'serif-bold': '𝐮', 'serif-italic': '𝑢', 'serif-bolditalic': '𝒖', 'sans-normal': '𝗎', 'sans-bold': '𝘂', 'sans-italic': '𝘶', 'sans-bolditalic': '𝙪', 'script-normal': '𝓊', 'script-bold': '𝓾', 'fraktur-normal': '𝔲', 'fraktur-bold': '𝖚', 'monospace-normal': '𝚞', 'doublestruck-normal': '𝕦'},
    'v': {'serif-bold': '𝐯', 'serif-italic': '𝑣', 'serif-bolditalic': '𝒗', 'sans-normal': '𝗏', 'sans-bold': '𝘃', 'sans-italic': '𝘷', 'sans-bolditalic': '𝙫', 'script-normal': '𝓋', 'script-bold': '𝓿', 'fraktur-normal': '𝔳', 'fraktur-bold': '𝖛', 'monospace-normal': '𝚟', 'doublestruck-normal': '𝕧'},
    'w': {'serif-bold': '𝐰', 'serif-italic': '𝑤', 'serif-bolditalic': '𝒘', 'sans-normal': '𝗐', 'sans-bold': '𝘄', 'sans-italic': '𝘸', 'sans-bolditalic': '𝙬', 'script-normal': '𝓌', 'script-bold': '𝔀', 'fraktur-normal': '𝔴', 'fraktur-bold': '𝖜', 'monospace-normal': '𝚠', 'doublestruck-normal': '𝕨'},
    'x': {'serif-bold': '𝐱', 'serif-italic': '𝑥', 'serif-bolditalic': '𝒙', 'sans-normal': '𝗑', 'sans-bold': '𝘅', 'sans-italic': '𝘹', 'sans-bolditalic': '𝙭', 'script-normal': '𝓍', 'script-bold': '𝔁', 'fraktur-normal': '𝔵', 'fraktur-bold': '𝖝', 'monospace-normal': '𝚡', 'doublestruck-normal': '𝕩'},
    'y': {'serif-bold': '𝐲', 'serif-italic': '𝑦', 'serif-bolditalic': '𝒚', 'sans-normal': '𝗒', 'sans-bold': '𝘆', 'sans-italic': '𝘺', 'sans-bolditalic': '𝙮', 'script-normal': '𝓎', 'script-bold': '𝔂', 'fraktur-normal': '𝔶', 'fraktur-bold': '𝖞', 'monospace-normal': '𝚢', 'doublestruck-normal': '𝕪'},
    'z': {'serif-bold': '𝐳', 'serif-italic': '𝑧', 'serif-bolditalic': '𝒛', 'sans-normal': '𝗓', 'sans-bold': '𝘇', 'sans-italic': '𝘻', 'sans-bolditalic': '𝙯', 'script-normal': '𝓏', 'script-bold': '𝔃', 'fraktur-normal': '𝔷', 'fraktur-bold': '𝖟', 'monospace-normal': '𝚣', 'doublestruck-normal': '𝕫'},
    'ı': {'serif-italic': '𝚤'},
    'ȷ': {'serif-italic': '𝚥'},
    'Α': {'serif-bold': '𝚨', 'serif-italic': '𝛢', 'serif-bolditalic': '𝜜', 'sans-bold': '𝝖', 'sans-bolditalic': '𝞐'},
    'Β': {'serif-bold': '𝚩', 'serif-italic': '𝛣', 'serif-bolditalic': '𝜝', 'sans-bold': '𝝗', 'sans-bolditalic': '𝞑'},
    'Γ': {'serif-bold': '𝚪', 'serif-italic': '𝛤', 'serif-bolditalic': '𝜞', 'sans-bold': '𝝘', 'sans-bolditalic': '𝞒'},
    'Δ': {'serif-bold': '𝚫', 'serif-italic': '𝛥', 'serif-bolditalic': '𝜟', 'sans-bold': '𝝙', 'sans-bolditalic': '𝞓'},
    'Ε': {'serif-bold': '𝚬', 'serif-italic': '𝛦', 'serif-bolditalic': '𝜠', 'sans-bold': '𝝚', 'sans-bolditalic': '𝞔'},
    'Ζ': {'serif-bold': '𝚭', 'serif-italic': '𝛧', 'serif-bolditalic': '𝜡', 'sans-bold': '𝝛', 'sans-bolditalic': '𝞕'},
    'Η': {'serif-bold': '𝚮', 'serif-italic': '𝛨', 'serif-bolditalic': '𝜢', 'sans-bold': '𝝜', 'sans-bolditalic': '𝞖'},
    'Θ': {'serif-bold': '𝚯', 'serif-italic': '𝛩', 'serif-bolditalic': '𝜣', 'sans-bold': '𝝝', 'sans-bolditalic': '𝞗'},
    'Ι': {'serif-bold': '𝚰', 'serif-italic': '𝛪', 'serif-bolditalic': '𝜤', 'sans-bold': '𝝞', 'sans-bolditalic': '𝞘'},
    'Κ': {'serif-bold': '𝚱', 'serif-italic': '𝛫', 'serif-bolditalic': '𝜥', 'sans-bold': '𝝟', 'sans-bolditalic': '𝞙'},
    'Λ': {'serif-bold': '𝚲', 'serif-italic': '𝛬', 'serif-bolditalic': '𝜦', 'sans-bold': '𝝠', 'sans-bolditalic': '𝞚'},
    'Μ': {'serif-bold': '𝚳', 'serif-italic': '𝛭', 'serif-bolditalic': '𝜧', 'sans-bold': '𝝡', 'sans-bolditalic': '𝞛'},
    'Ν': {'serif-bold': '𝚴', 'serif-italic': '𝛮', 'serif-bolditalic': '𝜨', 'sans-bold': '𝝢', 'sans-bolditalic': '𝞜'},
    'Ξ': {'serif-bold': '𝚵', 'serif-italic': '𝛯', 'serif-bolditalic': '𝜩', 'sans-bold': '𝝣', 'sans-bolditalic': '𝞝'},
    'Ο': {'serif-bold': '𝚶', 'serif-italic': '𝛰', 'serif-bolditalic': '𝜪', 'sans-bold': '𝝤', 'sans-bolditalic': '𝞞'},
    'Π': {'serif-bold': '𝚷', 'serif-italic': '𝛱', 'serif-bolditalic': '𝜫', 'sans-bold': '𝝥', 'sans-bolditalic': '𝞟'},
    'Ρ': {'serif-bold': '𝚸', 'serif-italic': '𝛲', 'serif-bolditalic': '𝜬', 'sans-bold': '𝝦', 'sans-bolditalic': '𝞠'},
    'ϴ': {'serif-bold': '𝚹', 'serif-italic': '𝛳', 'serif-bolditalic': '𝜭', 'sans-bold': '𝝧', 'sans-bolditalic': '𝞡'},
    'Σ': {'serif-bold': '𝚺', 'serif-italic': '𝛴', 'serif-bolditalic': '𝜮', 'sans-bold': '𝝨', 'sans-bolditalic': '𝞢'},
    'Τ': {'serif-bold': '𝚻', 'serif-italic': '𝛵', 'serif-bolditalic': '𝜯', 'sans-bold': '𝝩', 'sans-bolditalic': '𝞣'},
    'Υ': {'serif-bold': '𝚼', 'serif-italic': '𝛶', 'serif-bolditalic': '𝜰', 'sans-bold': '𝝪', 'sans-bolditalic': '𝞤'},
    'Φ': {'serif-bold': '𝚽', 'serif-italic': '𝛷', 'serif-bolditalic': '𝜱', 'sans-bold': '𝝫', 'sans-bolditalic': '𝞥'},
    'Χ': {'serif-bold': '𝚾', 'serif-italic': '𝛸', 'serif-bolditalic': '𝜲', 'sans-bold': '𝝬', 'sans-bolditalic': '𝞦'},
    'Ψ': {'serif-bold': '𝚿', 'serif-italic': '𝛹', 'serif-bolditalic': '𝜳', 'sans-bold': '𝝭', 'sans-bolditalic': '𝞧'},
    'Ω': {'serif-bold': '𝛀', 'serif-italic': '𝛺', 'serif-bolditalic': '𝜴', 'sans-bold': '𝝮', 'sans-bolditalic': '𝞨'},
    '∇': {'serif-bold': '𝛁', 'serif-italic': '𝛻', 'serif-bolditalic': '𝜵', 'sans-bold': '𝝯', 'sans-bolditalic': '𝞩'},
    'α': {'serif-bold': '𝛂', 'serif-italic': '𝛼', 'serif-bolditalic': '𝜶', 'sans-bold': '𝝰', 'sans-bolditalic': '𝞪'},
    'β': {'serif-bold': '𝛃', 'serif-italic': '𝛽', 'serif-bolditalic': '𝜷', 'sans-bold': '𝝱', 'sans-bolditalic': '𝞫'},
    'γ': {'serif-bold': '𝛄', 'serif-italic': '𝛾', 'serif-bolditalic': '𝜸', 'sans-bold': '𝝲', 'sans-bolditalic': '𝞬'},
    'δ': {'serif-bold': '𝛅', 'serif-italic': '𝛿', 'serif-bolditalic': '𝜹', 'sans-bold': '𝝳', 'sans-bolditalic': '𝞭'},
    'ε': {'serif-bold': '𝛆', 'serif-italic': '𝜀', 'serif-bolditalic': '𝜺', 'sans-bold': '𝝴', 'sans-bolditalic': '𝞮'},
    'ζ': {'serif-bold': '𝛇', 'serif-italic': '𝜁', 'serif-bolditalic': '𝜻', 'sans-bold': '𝝵', 'sans-bolditalic': '𝞯'},
    'η': {'serif-bold': '𝛈', 'serif-italic': '𝜂', 'serif-bolditalic': '𝜼', 'sans-bold': '𝝶', 'sans-bolditalic': '𝞰'},
    'θ': {'serif-bold': '𝛉', 'serif-italic': '𝜃', 'serif-bolditalic': '𝜽', 'sans-bold': '𝝷', 'sans-bolditalic': '𝞱'},
    'ι': {'serif-bold': '𝛊', 'serif-italic': '𝜄', 'serif-bolditalic': '𝜾', 'sans-bold': '𝝸', 'sans-bolditalic': '𝞲'},
    'κ': {'serif-bold': '𝛋', 'serif-italic': '𝜅', 'serif-bolditalic': '𝜿', 'sans-bold': '𝝹', 'sans-bolditalic': '𝞳'},
    'λ': {'serif-bold': '𝛌', 'serif-italic': '𝜆', 'serif-bolditalic': '𝝀', 'sans-bold': '𝝺', 'sans-bolditalic': '𝞴'},
    'μ': {'serif-bold': '𝛍', 'serif-italic': '𝜇', 'serif-bolditalic': '𝝁', 'sans-bold': '𝝻', 'sans-bolditalic': '𝞵'},
    'ν': {'serif-bold': '𝛎', 'serif-italic': '𝜈', 'serif-bolditalic': '𝝂', 'sans-bold': '𝝼', 'sans-bolditalic': '𝞶'},
    'ξ': {'serif-bold': '𝛏', 'serif-italic': '𝜉', 'serif-bolditalic': '𝝃', 'sans-bold': '𝝽', 'sans-bolditalic': '𝞷'},
    'ο': {'serif-bold': '𝛐', 'serif-italic': '𝜊', 'serif-bolditalic': '𝝄', 'sans-bold': '𝝾', 'sans-bolditalic': '𝞸'},
    'π': {'serif-bold': '𝛑', 'serif-italic': '𝜋', 'serif-bolditalic': '𝝅', 'sans-bold': '𝝿', 'sans-bolditalic': '𝞹'},
    'ρ': {'serif-bold': '𝛒', 'serif-italic': '𝜌', 'serif-bolditalic': '𝝆', 'sans-bold': '𝞀', 'sans-bolditalic': '𝞺'},
    'ς': {'serif-bold': '𝛓', 'serif-italic': '𝜍', 'serif-bolditalic': '𝝇', 'sans-bold': '𝞁', 'sans-bolditalic': '𝞻'},
    'σ': {'serif-bold': '𝛔', 'serif-italic': '𝜎', 'serif-bolditalic': '𝝈', 'sans-bold': '𝞂', 'sans-bolditalic': '𝞼'},
    'τ': {'serif-bold': '𝛕', 'serif-italic': '𝜏', 'serif-bolditalic': '𝝉', 'sans-bold': '𝞃', 'sans-bolditalic': '𝞽'},
    'υ': {'serif-bold': '𝛖', 'serif-italic': '𝜐', 'serif-bolditalic': '𝝊', 'sans-bold': '𝞄', 'sans-bolditalic': '𝞾'},
    'φ': {'serif-bold': '𝛗', 'serif-italic': '𝜑', 'serif-bolditalic': '𝝋', 'sans-bold': '𝞅', 'sans-bolditalic': '𝞿'},
    'χ': {'serif-bold': '𝛘', 'serif-italic': '𝜒', 'serif-bolditalic': '𝝌', 'sans-bold': '𝞆', 'sans-bolditalic': '𝟀'},
    'ψ': {'serif-bold': '𝛙', 'serif-italic': '𝜓', 'serif-bolditalic': '𝝍', 'sans-bold': '𝞇', 'sans-bolditalic': '𝟁'},
    'ω': {'serif-bold': '𝛚', 'serif-italic': '𝜔', 'serif-bolditalic': '𝝎', 'sans-bold': '𝞈', 'sans-bolditalic': '𝟂'},
    '∂': {'serif-bold': '𝛛', 'serif-italic': '𝜕', 'serif-bolditalic': '𝝏', 'sans-bold': '𝞉', 'sans-bolditalic': '𝟃'},
    'ϵ': {'serif-bold': '𝛜', 'serif-italic': '𝜖', 'serif-bolditalic': '𝝐', 'sans-bold': '𝞊', 'sans-bolditalic': '𝟄'},
    'ϑ': {'serif-bold': '𝛝', 'serif-italic': '𝜗', 'serif-bolditalic': '𝝑', 'sans-bold': '𝞋', 'sans-bolditalic': '𝟅'},
    'ϰ': {'serif-bold': '𝛞', 'serif-italic': '𝜘', 'serif-bolditalic': '𝝒', 'sans-bold': '𝞌', 'sans-bolditalic': '𝟆'},
    'ϕ': {'serif-bold': '𝛟', 'serif-italic': '𝜙', 'serif-bolditalic': '𝝓', 'sans-bold': '𝞍', 'sans-bolditalic': '𝟇'},
    'ϱ': {'serif-bold': '𝛠', 'serif-italic': '𝜚', 'serif-bolditalic': '𝝔', 'sans-bold': '𝞎', 'sans-bolditalic': '𝟈'},
    'ϖ': {'serif-bold': '𝛡', 'serif-italic': '𝜛', 'serif-bolditalic': '𝝕', 'sans-bold': '𝞏', 'sans-bolditalic': '𝟉'},
    'Ϝ': {'serif-bold': '𝟊'},
    'ϝ': {'serif-bold': '𝟋'},
    '0': {'serif-bold': '𝟎', 'doublestruck-normal': '𝟘', 'sans-normal': '𝟢', 'sans-bold': '𝟬', 'monospace-normal': '𝟶'},
    '1': {'serif-bold': '𝟏', 'doublestruck-normal': '𝟙', 'sans-normal': '𝟣', 'sans-bold': '𝟭', 'monospace-normal': '𝟷'},
    '2': {'serif-bold': '𝟐', 'doublestruck-normal': '𝟚', 'sans-normal': '𝟤', 'sans-bold': '𝟮', 'monospace-normal': '𝟸'},
    '3': {'serif-bold': '𝟑', 'doublestruck-normal': '𝟛', 'sans-normal': '𝟥', 'sans-bold': '𝟯', 'monospace-normal': '𝟹'},
    '4': {'serif-bold': '𝟒', 'doublestruck-normal': '𝟜', 'sans-normal': '𝟦', 'sans-bold': '𝟰', 'monospace-normal': '𝟺'},
    '5': {'serif-bold': '𝟓', 'doublestruck-normal': '𝟝', 'sans-normal': '𝟧', 'sans-bold': '𝟱', 'monospace-normal': '𝟻'},
    '6': {'serif-bold': '𝟔', 'doublestruck-normal': '𝟞', 'sans-normal': '𝟨', 'sans-bold': '𝟲', 'monospace-normal': '𝟼'},
    '7': {'serif-bold': '𝟕', 'doublestruck-normal': '𝟟', 'sans-normal': '𝟩', 'sans-bold': '𝟳', 'monospace-normal': '𝟽'},
    '8': {'serif-bold': '𝟖', 'doublestruck-normal': '𝟠', 'sans-normal': '𝟪', 'sans-bold': '𝟴', 'monospace-normal': '𝟾'},
    '9': {'serif-bold': '𝟗', 'doublestruck-normal': '𝟡', 'sans-normal': '𝟫', 'sans-bold': '𝟵', 'monospace-normal': '𝟿'},
};
$('#mathchar').keyup(function (e) {
    $('.mathfont').removeClass("disabled");

    var char = $('#mathchar').val();
    if (char == "") {
        return;
    }
    var fonts;
    try {
        fonts = Object.keys(mathFonts[char]);
    } catch (e) {
        fonts = [];
    }

    $('.mathfont').each(function () {
        if (!(fonts.includes(this.id))) {
            $(this).addClass("disabled");
        }
    });
});
function getInputSelection() {
    if (input.selectionStart || input.selectionStart == '0') {
        var s = input.selectionStart;
        var e = input.selectionEnd;
        if (s == e) {
            return null;  // no selection
        } else {
            return input.value.substring(s, e);
        }
    } else {
        return null;  // no selection
    }
}
$('button.mathfont').click(function () {
    var font = this.id;

    var char = $('#mathchar').val();
    if (char != "") {
        var symbol;
        try {
            symbol = mathFonts[char][font];
            if (symbol == undefined) {
                throw undefined;
            }
        } catch (e) {
            return;
        }
        insertAtCursorPos(symbol);
        addToHistory(symbol);
    } else if (getInputSelection() != null) {  // if no character entered, try converting
        var symbols = [];
        Array.from(getInputSelection()).forEach(char => {

            // also convert the current character if it already has been
            // converted to something previously – i.e. look to which "base
            // char" it corresponds to, and modify the char variable
            // accordingly
            Object.keys(mathFonts).forEach(base => {
                Object.values(mathFonts[base]).forEach(sym => {
                    if (char == sym) {
                        char = base;
                    }
                });
            });

            var symbol;
            try {
                symbol = mathFonts[char][font];
                if (symbol == undefined) {
                    throw undefined;
                }
            } catch (e) {
                symbol = char;
            }
            symbols.push(symbol);
        });
        insertAtCursorPos(symbols.join(""));
        input.focus();
        draw();
    } else {
        // nothing to be done
    }
});

// button tooltips
function showTooltip(x, y, text) {
    if (text != null && text != "") {
        $(document.body).append($('<div class="tooltip" style="left: ' + x + 'px; top: ' + y + 'px;">' + text + '</div>'));
    }
}
function hideTooltip() {
    $(".tooltip").remove();
}
$('button').hover(function (e) {
    var elem = this;
    var x = $(elem).offset().left;
    var y = $(elem).offset().top + $(elem).outerHeight(true) + 1;
    var text = elem.getAttribute("data-tooltip");
    showTooltip(x, y, text);
}, hideTooltip);

$('#codepoints').on('mouseover', '.cp', function (e) {
    var elem = this;
    var x = $(elem).offset().left + 0.3 * $(elem).outerWidth(true);
    var y = $(elem).offset().top + 0.8 * $(elem).outerHeight(true);
    var text = elem.getAttribute("data-tooltip");
    showTooltip(x, y, text);
});
$('#codepoints').on('mouseout', '.cp', hideTooltip);

// explanatory tooltips
$('[data-explanation]').hover(function (e) {
    var elem = this;
    var x = $(elem).offset().left;
    var y = $(elem).offset().top + $(elem).outerHeight(true) + 1;
    var text = elem.getAttribute("data-explanation");
    showTooltip(x, y, text);
}, hideTooltip);
