//////////////////////
// HELPER FUNCTIONS //
//////////////////////

{
    // wrap value in JSON object {label: value}
    function label(lbl, val) {
        return {[lbl]: val};
    }

    // left-associative (i.e. right-deep) nesting with labeling
    // [a, b, c] => {label: [a, {label: [b, c]}]}
    // currently unused
    /*function nestLeft(lbl, lis) {
        lis.reverse();
        var ret = lis[0];
        lis = lis.slice(1,lis.length);
        for (var elem in lis) {
            ret = label(lbl, [lis[elem], ret]);
        }
        return ret;
    }*/

    // right-associative (i.e. left-deep) nesting with labeling
    // [a, b, c] => {label: [{label: [a, b]}, c]}
    function nestRight(lbl, lis) {
        var ret = lis[0];
        lis = lis.slice(1);
        for (var elem in lis) {
            ret = label(lbl, [ret, lis[elem]]);
        }
        return ret;
    }

    // special case of right-associative (i.e. left-deep) nesting with labeling
    // [[a, +], [b, /], c] => {label: {symbol: /, of: [{label: {symbol: +, of: [a, b]}}, c]}}
    function nestRight2(lbl, lis) {
        var ret = lis[0][0];
        var sym = lis[0][1];
        for (var i = 1; i < lis.length; i++) {
            if (i == lis.length - 1) {
                // don't forget the second component of the final element of lis
                ret = label(lbl, {symbol: sym, of: [ret, lis[i]]});
            } else {
                ret = label(lbl, {symbol: sym, of: [ret, lis[i][0]]});
                sym = lis[i][1];
            }
        }
        return ret;
    }

    // replaces characters of "chars" found in "sources" with correspondingly
    // positioned characters in "targets". all arguments can be strings or
    // lists. returns a string
    function replaceMap(sources, targets, chars) {

        // convert all inputs to lists if necessary
        if (typeof sources === 'string') {
            sources = sources.split('');
        }
        if (typeof targets === 'string') {
            targets = targets.split('');
        }
        if (typeof chars === 'string') {
            chars = chars.split('');
        }

        // perform the lookups
        return chars.map(c => targets[sources.indexOf(c)]).join('');
    }

    // flattens an array of values and arrays
    // flatten([[1,2],3,[4]]) => [1, 2, 3, 4]
    function flatten(a) {
        var aFlat = [];
        a.forEach(e => {
            if (Array.isArray(e)) {
                e.forEach(i => aFlat.push(i));
            } else {
                aFlat.push(e);
            }
        });
        return aFlat;
    }
}

////////////////
// ENTRY RULE //
////////////////

// PEG.js starts parsing from the top-most rule in the parser definition unless
// otherwise configured, so here we go
unicodemath = "\n"* c:(exp newlines)* n:(eqnumber?) "\n"* {
    return {unicodemath: {content: flatten(c.map(e => [e[0]].concat(e[1]))), eqnumber: n}};
}

// an arbitrary number (including zero) of successive newlines
newlines = n:"\n"* {
    return n.map(x => ({newline: null}));
}

// syntax for equation numbers is "#n", where the equation number n may not
// contain line breaks
eqnumber = opEqNumber n:(((! "\n") char)+) {
    return n.map(x => x[1]).join("");
}


//////////////////
// HELPER RULES //
//////////////////

// a bitmask, i.e. a number. converts the parsed list of digits to a proper
// number already
bitmask = n:[0-9]+ {
    return parseInt(n.join(''))
}

// standard ascii space (i would've named this ⌴, but PEG.js doesn't permit that
// symbol in identifiers)
_ = " "

// many ascii spaces
__ = w:_+ {
    return w.join('');
}


////////////////
// SUBPARSERS //
////////////////

// subparsers are not really a thing in PEG.js, so i just put collections of
// rules that are sort of disconnected from the rest of the rules below

// Unicode subscripts (⚠ generated AST should match the normal subscript AST)
nUnicodeSub = s:([₊₋]?) n:[₀₁₂₃₄₅₆₇₈₉]+ {
    var nPrime = {number: replaceMap("₀₁₂₃₄₅₆₇₈₉", "0123456789", n)};
    if (s) {
        return [{operator: replaceMap("₊₋", "+-", s)}, nPrime];
    }
    return nPrime;
}
opUnicodeSub
    = o:"₊₋" {return {operator: "\u00B1"}}  // 4.1 Character Translations
    / o:"₋₊" {return {operator: "\u2213"}}
    / o:[₊₋₌] {
        return {operator: replaceMap("₊₋₌", "+-=", o)};
    }
factorUnicodeSub
    = nUnicodeSub
    / "₍" e:unicodeSub "₎" {
        return {bracketed: {open: "(", close: ")", content: e}};
    }
elementUnicodeSub = factorUnicodeSub+

// allows any order of operators and operands
unicodeSub = ex:(elementUnicodeSub / opUnicodeSub)+ {
    return {expr: ex};
}

// more strict, only allows "well-formed" expressions
//unicodeSub = h:elementUnicodeSub t:(opUnicodeSub elementUnicodeSub)* {
//    return {expr: flatten([{element: h}].concat(t.map(a => [a[0], {element: a[1]}])))};
//}

// Unicode superscripts (⚠ generated AST should match the normal superscript AST)
nUnicodeSup = s:([⁺⁻]?) n:[⁰¹²³⁴⁵⁶⁷⁸⁹]+ {
    var nPrime = {number: replaceMap("⁰¹²³⁴⁵⁶⁷⁸⁹", "0123456789", n)};
    if (s) {
        return [{operator: replaceMap("⁺⁻", "+-", s)}, nPrime];
    }
    return nPrime;
}
atomsUnicodeSup = a:[ⁱⁿ]+ {
    return {atoms: {chars: replaceMap("ⁱⁿ", "in", a)}};
}
opUnicodeSup
    = o:"⁺⁻" {return {operator: "\u00B1"}}  // 4.1 Character Translations
    / o:"⁻⁺" {return {operator: "\u2213"}}
    / o:[⁺⁻⁼] {
        return {operator: replaceMap("⁺⁻⁼", "+-=", o)};
    }
factorUnicodeSup
    = atomsUnicodeSup
    / nUnicodeSup
    / "⁽" e:unicodeSup "⁾" {
        return {bracketed: {open: "(", close: ")", content: e}};
    }
elementUnicodeSup = factorUnicodeSup+

// allows any order of operators and operands
unicodeSup = ex:(elementUnicodeSup / opUnicodeSup)+ {
    return {expr: ex};
}

// more strict, only allows "well-formed" expressions
//unicodeSup = h:elementUnicodeSup t:(opUnicodeSup elementUnicodeSup)* {
//    return {expr: flatten([{element: h}].concat(t.map(a => [a[0], {element: a[1]}])))};
//}


/////////////////////
// LEXER-ISH RULES //
/////////////////////

// PEG.js knows no separation between lexer and parser, but the following parse
// rules mainly categorize input into different groups of symbols. Note that
// large lists of literal alternatives, e.g. "a" / "b" / ... / "n" have been
// collapsed into regex-style ranges [ab...n] for dramatically increased
// performance.
ε = ""
char = .
nASCII = [0-9]
nn
    = nASCII  // ⚡ performance optimization (since most numbers will consist of Arabic numerals)
    / [\u0030-\u0039\u0660-\u0669\u06F0-\u06F9\u07C0-\u07C9\u0966-\u096F\u09E6-\u09EF\u0A66-\u0A6F\u0AE6-\u0AEF\u0B66-\u0B6F\u0BE6-\u0BEF\u0C66-\u0C6F\u0CE6-\u0CEF\u0D66-\u0D6F\u0DE6-\u0DEF\u0E50-\u0E59\u0ED0-\u0ED9\u0F20-\u0F29\u1040-\u1049\u1090-\u1099\u17E0-\u17E9\u1810-\u1819\u1946-\u194F\u19D0-\u19D9\u1A80-\u1A89\u1A90-\u1A99\u1B50-\u1B59\u1BB0-\u1BB9\u1C40-\u1C49\u1C50-\u1C59\uA620-\uA629\uA8D0-\uA8D9\uA900-\uA909\uA9D0-\uA9D9\uA9F0-\uA9F9\uAA50-\uAA59\uABF0-\uABF9\uFF10-\uFF19]
    // note that this is all BMP characters from the Nd category, based on https://www.unicode.org/Public/13.0.0/ucd/extracted/DerivedGeneralCategory-13.0.0d3.txt and `grep "; Nd" DerivedGeneralCategory-13.0.0d3.txt | cut -f1 -d " " | grep -v '[0-9a-fA-F]\{5\}' | sed -e 's/\.\./-/' | sed -e 's/\([0-9a-fA-F]\{4\}\)/\\u\1/g' | tr -d '\n'` (via https://github.com/pegjs/pegjs/blob/master/examples/javascript.pegjs#L374)
αASCII = [A-Za-z]
αnMath
    // Private Use Area range corresponding to Mathematical Alphanumeric Symbols
    // block (a substitution step is performed right before parsing, its inverse
    // is then mapped over the parse tree) + Letterlike Symbols block (contains,
    // among other things, symbols missing from the Mathematical Alphanumeric
    // Symbols block) sans size override operator Ⅎ
    = [\uE000-\uE3FF\u2102-\u2131\u2133\u2134]
/*emoji  // generated by ../utils/emoji.py
    = [\u231A-\u231B]
    / [\u23E9-\u23EC]
    / "\u23F0"
    / "\u23F3"
    / [\u25FD-\u25FE]
    / [\u2614-\u2615]
    / [\u2648-\u2653]
    / "\u267F"
    / "\u2693"
    / "\u26A1"
    / [\u26AA-\u26AB]
    / [\u26BD-\u26BE]
    / [\u26C4-\u26C5]
    / "\u26CE"
    / "\u26D4"
    / "\u26EA"
    / [\u26F2-\u26F3]
    / "\u26F5"
    / "\u26FA"
    / "\u26FD"
    / "\u2705"
    / [\u270A-\u270B]
    / "\u2728"
    / "\u274C"
    / "\u274E"
    / [\u2753-\u2755]
    / "\u2757"
    / [\u2795-\u2797]
    / "\u27B0"
    / "\u27BF"
    / [\u2B1B-\u2B1C]
    / "\u2B50"
    / "\u2B55"
    / [\uE400-\uE808]*/
emoji = [\u231A-\u231B\u23E9-\u23EC\u23F0\u23F3\u25FD-\u25FE\u2614-\u2615\u2648-\u2653\u267F\u2693\u26A1\u26AA-\u26AB\u26BD-\u26BE\u26C4-\u26C5\u26CE\u26D4\u26EA\u26F2-\u26F3\u26F5\u26FA\u26FD\u2705\u270A-\u270B\u2728\u274C\u274E\u2753-\u2755\u2757\u2795-\u2797\u27B0\u27BF\u2B1B-\u2B1C\u2B50\u2B55\uE400-\uE808]  // ⚡ performance optimization
αnOther
    = αASCII  // ⚡ performance optimization (since most letters will be from the Roman alphabet)
    / [\u0391-\u03A9\u03B1-\u03C9]  // greek letters  // ⚡ performance optimization (since many letter will be from the Greek alphabet)
    / [A-Za-z\u00AA\u00B5\u00BA\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u02C1\u02C6-\u02D1\u02E0-\u02E4\u02EC\u02EE\u0370-\u0374\u0376\u0377\u037A-\u037D\u037F\u0386\u0388-\u038A\u038C\u038E-\u03A1\u03A3-\u03F5\u03F7-\u0481\u048A-\u052F\u0531-\u0556\u0559\u0560-\u0588\u05D0-\u05EA\u05EF-\u05F2\u0620-\u064A\u066E\u066F\u0671-\u06D3\u06D5\u06E5\u06E6\u06EE\u06EF\u06FA-\u06FC\u06FF\u0710\u0712-\u072F\u074D-\u07A5\u07B1\u07CA-\u07EA\u07F4\u07F5\u07FA\u0800-\u0815\u081A\u0824\u0828\u0840-\u0858\u0860-\u086A\u08A0-\u08B4\u08B6-\u08BD\u0904-\u0939\u093D\u0950\u0958-\u0961\u0971-\u0980\u0985-\u098C\u098F\u0990\u0993-\u09A8\u09AA-\u09B0\u09B2\u09B6-\u09B9\u09BD\u09CE\u09DC\u09DD\u09DF-\u09E1\u09F0\u09F1\u09FC\u0A05-\u0A0A\u0A0F\u0A10\u0A13-\u0A28\u0A2A-\u0A30\u0A32\u0A33\u0A35\u0A36\u0A38\u0A39\u0A59-\u0A5C\u0A5E\u0A72-\u0A74\u0A85-\u0A8D\u0A8F-\u0A91\u0A93-\u0AA8\u0AAA-\u0AB0\u0AB2\u0AB3\u0AB5-\u0AB9\u0ABD\u0AD0\u0AE0\u0AE1\u0AF9\u0B05-\u0B0C\u0B0F\u0B10\u0B13-\u0B28\u0B2A-\u0B30\u0B32\u0B33\u0B35-\u0B39\u0B3D\u0B5C\u0B5D\u0B5F-\u0B61\u0B71\u0B83\u0B85-\u0B8A\u0B8E-\u0B90\u0B92-\u0B95\u0B99\u0B9A\u0B9C\u0B9E\u0B9F\u0BA3\u0BA4\u0BA8-\u0BAA\u0BAE-\u0BB9\u0BD0\u0C05-\u0C0C\u0C0E-\u0C10\u0C12-\u0C28\u0C2A-\u0C39\u0C3D\u0C58-\u0C5A\u0C60\u0C61\u0C80\u0C85-\u0C8C\u0C8E-\u0C90\u0C92-\u0CA8\u0CAA-\u0CB3\u0CB5-\u0CB9\u0CBD\u0CDE\u0CE0\u0CE1\u0CF1\u0CF2\u0D05-\u0D0C\u0D0E-\u0D10\u0D12-\u0D3A\u0D3D\u0D4E\u0D54-\u0D56\u0D5F-\u0D61\u0D7A-\u0D7F\u0D85-\u0D96\u0D9A-\u0DB1\u0DB3-\u0DBB\u0DBD\u0DC0-\u0DC6\u0E01-\u0E30\u0E32\u0E33\u0E40-\u0E46\u0E81\u0E82\u0E84\u0E86-\u0E8A\u0E8C-\u0EA3\u0EA5\u0EA7-\u0EB0\u0EB2\u0EB3\u0EBD\u0EC0-\u0EC4\u0EC6\u0EDC-\u0EDF\u0F00\u0F40-\u0F47\u0F49-\u0F6C\u0F88-\u0F8C\u1000-\u102A\u103F\u1050-\u1055\u105A-\u105D\u1061\u1065\u1066\u106E-\u1070\u1075-\u1081\u108E\u10A0-\u10C5\u10C7\u10CD\u10D0-\u10FA\u10FC-\u1248\u124A-\u124D\u1250-\u1256\u1258\u125A-\u125D\u1260-\u1288\u128A-\u128D\u1290-\u12B0\u12B2-\u12B5\u12B8-\u12BE\u12C0\u12C2-\u12C5\u12C8-\u12D6\u12D8-\u1310\u1312-\u1315\u1318-\u135A\u1380-\u138F\u13A0-\u13F5\u13F8-\u13FD\u1401-\u166C\u166F-\u167F\u1681-\u169A\u16A0-\u16EA\u16F1-\u16F8\u1700-\u170C\u170E-\u1711\u1720-\u1731\u1740-\u1751\u1760-\u176C\u176E-\u1770\u1780-\u17B3\u17D7\u17DC\u1820-\u1878\u1880-\u1884\u1887-\u18A8\u18AA\u18B0-\u18F5\u1900-\u191E\u1950-\u196D\u1970-\u1974\u1980-\u19AB\u19B0-\u19C9\u1A00-\u1A16\u1A20-\u1A54\u1AA7\u1B05-\u1B33\u1B45-\u1B4B\u1B83-\u1BA0\u1BAE\u1BAF\u1BBA-\u1BE5\u1C00-\u1C23\u1C4D-\u1C4F\u1C5A-\u1C7D\u1C80-\u1C88\u1C90-\u1CBA\u1CBD-\u1CBF\u1CE9-\u1CEC\u1CEE-\u1CF3\u1CF5\u1CF6\u1CFA\u1D00-\u1DBF\u1E00-\u1F15\u1F18-\u1F1D\u1F20-\u1F45\u1F48-\u1F4D\u1F50-\u1F57\u1F59\u1F5B\u1F5D\u1F5F-\u1F7D\u1F80-\u1FB4\u1FB6-\u1FBC\u1FBE\u1FC2-\u1FC4\u1FC6-\u1FCC\u1FD0-\u1FD3\u1FD6-\u1FDB\u1FE0-\u1FEC\u1FF2-\u1FF4\u1FF6-\u1FFC\u2071\u207F\u2090-\u209C\u2102\u2107\u210A-\u2113\u2115\u2119-\u211D\u2124\u2126\u2128\u212A-\u212D\u212F-\u2139\u213C-\u213F\u214E\u2183\u2184\u2C00-\u2C2E\u2C30-\u2C5E\u2C60-\u2CE4\u2CEB-\u2CEE\u2CF2\u2CF3\u2D00-\u2D25\u2D27\u2D2D\u2D30-\u2D67\u2D6F\u2D80-\u2D96\u2DA0-\u2DA6\u2DA8-\u2DAE\u2DB0-\u2DB6\u2DB8-\u2DBE\u2DC0-\u2DC6\u2DC8-\u2DCE\u2DD0-\u2DD6\u2DD8-\u2DDE\u2E2F\u3005\u3006\u3031-\u3035\u303B\u303C\u3041-\u3096\u309D-\u309F\u30A1-\u30FA\u30FC-\u30FF\u3105-\u312F\u3131-\u318E\u31A0-\u31BA\u31F0-\u31FF\u3400-\u4DB5\u4E00-\u9FEF\uA000-\uA48C\uA4D0-\uA4FD\uA500-\uA60C\uA610-\uA61F\uA62A\uA62B\uA640-\uA66E\uA67F-\uA69D\uA6A0-\uA6E5\uA717-\uA71F\uA722-\uA788\uA78B-\uA7BF\uA7C2-\uA7C6\uA7F7-\uA801\uA803-\uA805\uA807-\uA80A\uA80C-\uA822\uA840-\uA873\uA882-\uA8B3\uA8F2-\uA8F7\uA8FB\uA8FD\uA8FE\uA90A-\uA925\uA930-\uA946\uA960-\uA97C\uA984-\uA9B2\uA9CF\uA9E0-\uA9E4\uA9E6-\uA9EF\uA9FA-\uA9FE\uAA00-\uAA28\uAA40-\uAA42\uAA44-\uAA4B\uAA60-\uAA76\uAA7A\uAA7E-\uAAAF\uAAB1\uAAB5\uAAB6\uAAB9-\uAABD\uAAC0\uAAC2\uAADB-\uAADD\uAAE0-\uAAEA\uAAF2-\uAAF4\uAB01-\uAB06\uAB09-\uAB0E\uAB11-\uAB16\uAB20-\uAB26\uAB28-\uAB2E\uAB30-\uAB5A\uAB5C-\uAB67\uAB70-\uABE2\uAC00-\uD7A3\uD7B0-\uD7C6\uD7CB-\uD7FB\uF900-\uFA6D\uFA70-\uFAD9\uFB00-\uFB06\uFB13-\uFB17\uFB1D\uFB1F-\uFB28\uFB2A-\uFB36\uFB38-\uFB3C\uFB3E\uFB40\uFB41\uFB43\uFB44\uFB46-\uFBB1\uFBD3-\uFD3D\uFD50-\uFD8F\uFD92-\uFDC7\uFDF0-\uFDFB\uFE70-\uFE74\uFE76-\uFEFC\uFF21-\uFF3A\uFF41-\uFF5A\uFF66-\uFFBE\uFFC2-\uFFC7\uFFCA-\uFFCF\uFFD2-\uFFD6\uFFDA-\uFFDC]
    // note that this is all BMP characters from the L* categories, based on https://util.unicode.org/UnicodeJsps/list-unicodeset.jsp and [:BMP:]&[:gc=L:] (with escape option checked) – as suggested by @znjameswu in https://github.com/doersino/UnicodeMathML/issues/2 – sans double-struck characters \u2145 and \u2146-\u2149 and with \uFFD2-\uFFD7 replaced by \uFFD2-\uFFD6 to exclude the typewriter font marker
αn
    = αnMath
    / αnOther
    / emoji
diacritic
    = [\u0300-\u036F\u20D0-\u20FF]  // Combining Diacritical Marks Block +
                                    // Combining Diacritical Marks for Symbols Block
unicodeFraction = [↉½⅓⅔¼¾⅕⅖⅗⅘⅙⅚⅐⅛⅜⅝⅞⅑]
opArray
    = "█"  // array
    / "■"  // matrix
    / "@"  // row separator
    / "&"  // column separator
opOpen = [([{⟨〖⌈⌊]
opClose = [)}⟩〗⌉⌋] / "]"
opDecimal = "." / ","
opHbracket = [⏜⏝⏞⏟⏠⏡⎴⎵¯]  // no underbar since U+2581 is used for enclosures
opStretchyArrow = [←→↔⇐⇒⇔↩↪↼⇀↽⇁⊢⊣⟵⟶⟷⟸⟹⟺↦⊨]
/*opNary  // not all of these are mentioned in the tech note, but they all fit
          // in here (most of them are n-ary)
    = "∑" / "⅀" / "⨊"
    / "∏" / "∐"
    / "⨋"
    / "∫" / "∬" / "∭" / "⨌"
    / "∮" / "∯" / "∰"
    / "∱" / "⨑" / "∲" / "∳"
    / "⨍" / "⨎"
    / "⨏" / "⨕" / "⨖" / "⨗" / "⨘"
    / "⨙" / "⨚"
    / "⨛" / "⨜"
    / "⨒" / "⨓" / "⨔"
    / "⋀" / "⋁"
    / "⋂" / "⋃"
    / "⨃" / "⨄"
    / "⨅" / "⨆"
    / "⨀" / "⨁" / "⨂"
    / "⨉" / "⫿"*/
opNary = [∑⅀⨊∏∐⨋∫∬∭⨌∮∯∰∱⨑∲∳⨍⨎⨏⨕⨖⨗⨘⨙⨚⨛⨜⨒⨓⨔⋀⋁⋂⋃⨃⨄⨅⨆⨀⨁⨂⨉⫿]  // ⚡ performance optimization
opNaryand = "▒"  // "\of"
opDoublestruck = [ⅅⅆⅇⅈⅉ]
opAtop = "¦"
opChoose = "⒞"
opFraction
    = "/"       // normal fraction ¹-₂
    / "\u2044"  // skewed fraction ¹/₂
    / "\u2215"  // linear fraction 1/2
    / "\u2298"  // small fraction
opEnclosure = "▭" / "̄" / "▁" / "▢" / "○" / "⟌" / "⃧" / "⬭"
opEqNumber = "#"
opPhantom = "⟡" / "⬄" / "⇳"
opSmash = "⬍" / "⬆" / "⬇" / "⬌"
opAbstractBox = "□"
opRoot = "√" / "∛" / "∜"
opSubSup = "_" / "^"
opAboveBelow = "┬" / "┴"
opSizeOverride = "Ⅎ"
opColor = "✎"
opBgColor = "☁"
opCommentOpen = "⫷"
opCommentClose = "⫸"
opTt = "ￗ"
/*opBuildup
    = opArray
    / opOpen / "├"
    / opClose / "┤"
    /// opDecimal  // commenting this out enables using , and . as operators,
                   // numbers still have precedence either way
    / "|"
    / "│"
    / "∣"
    / opHbracket
    // opStretchyArrow  // commented out since these can also be operators
    / opNary
    / opNaryand
    / opDoublestruck
    / opAtop
    / opChoose
    / opFraction
    / opEnclosure
    / opEqNumber
    / opPhantom
    / opSmash
    / opAbstractBox
    / opRoot
    / opSubSup
    / opAboveBelow
    / opSizeOverride
    / opColor
    / opBgColor
    / opCommentOpen
    / opCommentClose
    / opTt*/
opBuildup = [█■@&([{⟨〖⌈⌊├)}⟩〗⌉⌋┤|│∣⏜⏝⏞⏟⏠⏡⎴⎵¯∑⅀⨊∏∐⨋∫∬∭⨌∮∯∰∱⨑∲∳⨍⨎⨏⨕⨖⨗⨘⨙⨚⨛⨜⨒⨓⨔⋀⋁⋂⋃⨃⨄⨅⨆⨀⨁⨂⨉⫿▒ⅅⅆⅇⅈⅉ¦⒞/\u2044\u2215\u2298▭̄▁▢○⟌⃧⬭#⟡⬄⇳⬍⬆⬇⬌□√∛∜_^┬┴Ⅎ✎☁⫷⫸ￗ] / "]"  // ⚡ performance optimization
other = !(_ / αn / nn / diacritic / unicodeFraction / opBuildup / "\n") char


////////////////////////////
// THE MEAT OF THE PARSER //
////////////////////////////

exp = __? ex:((element / operator) __?)+ {
    return {expr: ex.map(e => e[0])};
}

// the grammar given in the tech note prescribes alternating operators and
// operands, but that's overly restrictive and has no discernible advantages
//exp = h:element wss? t:(operator wss? element wss?)* {
//    return {expr: flatten([{element: h}].concat(t.map(a => [a[0], {element: a[2]}])))};
//}

operator
    = s:mathspaces {  // spaces
        return s
    }
    / ",  " {  // tech note, section 3.14: "If two spaces follow, the comma is
               // rendered as a clause separator (a relatively large space
               // follows the comma)."
        return [{operator: ","}, {spaces: {space: 9}}];
    }
    / " :" {  // tech note, section 3.14: "<space> ‘:’ is displayed as Unicode
              // RATIO U+2236."
        return {operator: "\u2236"};
    }
    / (& basicOperator) e:(subsupScript / abovebelowScript) {  // scripted opers
        return e;
    }
    / basicOperator
basicOperator  // normal or negated operators
    = negatedOperator
    / o:rawOperator {
        return {operator: o};
    }
negatedOperator
    = o:rawOperator "\u0338" {  // negated operators
        return {negatedoperator: o};
    }
    / "/" o:rawOperator {  // negated operators
        return {negatedoperator: o};
    }
rawOperator
    = mappedOperator
    / o:other {
        return o[1];
    }
mappedOperator  // character translations noted in section 4.1 of the tech note
    = "*"  {return "\u2217"}
    / "-+" {return "\u2213"}
    / "-"  {return "\u2212"}
    / "+-" {return "\u00B1"}
    / "<=" {return "\u2264"}
    / ">=" {return "\u2265"}
    / "~=" {return "\u2245"}
    / "::" {return "\u2237"}
    / ":=" {return "\u2254"}
    / "<<" {return "\u226A"}
    / ">>" {return "\u226B"}
    / "->" {return "\u2192"}
    / "!!" {return "\u203C"}
    / "..." {return "…"}  // not in the tech note, but seems sensible

// ❶ elements: low-precedence constructs (i.e. ones with low-precedence
//    operators – thus they are likely to be at the outer level of an expression
//    imagined in tree form)
element
    = array
    / matrix
    / nary
    / phantomSmash
    / o:operand !(__? (opFraction !rawOperator / opAtop / opChoose)) {return o}  // ⚡ performance optimization
    / fraction
    / atop
    ///operand  // ⚡ performance optimization

// equation arrays
array = "█(" r:arows ")" {
    return {array: r};
}
arows = h:arow t:("@" arow)* {
    return {arows: [h].concat(t.map(a => a[1]))};
}
arow = __? h:(exp / emptycell)? t:(__? "&" __? (exp / emptycell))* __? {
    return {arow: [h].concat(t.map(a => a[3]))};
}
emptycell = "" {
    return {atoms: {spaces: {space: 0}}};
}

// matrices
matrix
    = "■(" r:mrows ")" {
        return {matrix: r};
    }
    / "⒨(" r:mrows ")" {
        return {bracketed: {open: "(", close: ")", content: {matrix: r}}};
    }
mrows = h:mrow t:("@" mrow)* {
    return {mrows: [h].concat(t.map(a => a[1]))};
}
mrow = __? h:(exp / emptycell) t:(__? "&" __? (exp / emptycell))* __? {
    return {mrow: [h].concat(t.map(a => a[3]))};
}

// n-ary operations such as sums and integrals (this is fairly complex and
// refers to a bunch of rules defined further down)
nary = o:opNary m:bitmask? s:(script / abscript)? opNaryand a:element {
    if (s == null) {
        s = {type: "subsup"}
    }
    s.base = {opnary: o};
    return {nary: {mask: m, limits: {script: s}, naryand: a}};
}

// various kinds of phantoms and smashes
phantomSmash = phantom / smash
phantom
    = "⟡(" m:bitmask "&" e:exp ")" {
        return {phantom: {mask: m, symbol: null, of: e}};
    }
    / s:opPhantom "(" e:exp ")" {
        return {phantom: {mask: null, symbol: s, of: e}};
    }
smash = s:opSmash "(" e:exp ")" {
    return {smash: {symbol: s, of: e}};
}

// fractions
fraction
    = f:unicodeFraction {  // not mentioned in the tech note, but should clearly
                           // be syntactic sugar for the corresponding "proper"
                           // fractions, via unicodefractions.com
        return {unicodefraction: f};
    }
    / r:(operand __? opFraction __?)+ t:operand {
        return nestRight2("fraction", r.map(a => [a[0], a[2]]).concat([t]));
    }

// fractions without a horizontal rule, e.g. for binomial coefficients
atop
    = r:(operand __? opAtop __?)+ t:operand {
        return nestRight("atop", r.map(a => a[0]).concat([t]));
    }
    / r:operand __? opChoose __? t:operand {  // syntactic sugar for binomial
                                              // coefficients
        return {binom: {top: r, bottom: t}};
    }

// ❷ operands/factors: medium-precedence constructs, comprising constructs
//    which may occur inside scripts as well as the various kinds of scripts
//    themselves (which may not in all cases occur directly within each other,
//    hence the separation between factor and sfactor)
operand = factor+
factor
    = preScript
    / !(functionName) e:entity !("_" / "^" / "┬" / "┴" / "'" / "′" / "″" / "‴" / "⁗" / "‼" / "!" / [₀₁₂₃₄₅₆₇₈₉₊₋₌₍₎⁰¹²³⁴⁵⁶⁷⁸⁹ⁱⁿ⁺⁻⁼⁽⁾]) {return e}  // ⚡ performance optimization
    / subsupScript
    / abovebelowScript
    / sfactor  // covers all other constructs

// normal subscripts and superscripts – these are fairly involved since there's
// a lot of options for combining scripts:
// * if the first script is a Unicode (suffix U) script (i.e. ₁), the second
//   script (if present) can be another Unicode script *or* a LaTeX-style script
// * if the first script is a LaTeX-style (suffix L) script (e.g. _1), the
//   second script (if present) must be one too
// * LaTeX-style scripts may *contain* Unicode scripts, e.g. a^b₁
// * LaTeX-style scripts may also repeat, e.g. a_b_c_d (but not a_b^c_d)
// note that these normal subscripts and superscript (or portions thereof) are
// also referenced in the grammar rules for prescrips, nary operations and
// functions (and they interact with primes in the transformation stage) – they
// do a lot of heavy lifting!
subsupScript
    = subsupSubsup
    / subsupSubscript
    / subsupSuperscript
script = s:(subsup / sub / sup) {
    s.type = "subsup";
    return s;
}
scriptU = s:(subsupU / subU / supU) {
    s.type = "subsup";
    return s;
}
scriptL = s:(subsupL / subL / supL) {
    s.type = "subsup";
    return s;
}
subsupSubsup = o:scriptbase s:subsup __? {
    s.base = o;
    s.type = "subsup";
    return {script: s};
}
subsup  // mixed Unicode/LaTeX-style
    = b:subU p:(supU / supL) {
        return {low: b.low, high: p.high};
    }
    / p:supU b:(subU / subL) {
        return {low: b.low, high: p.high};
    }
    / subsupL
subsupU  // only Unicode
    = b:subU p:supU {
        return {low: b.low, high: p.high};
    }
    / p:supU b:subU {
        return {low: b.low, high: p.high};
    }
subsupL  // only LaTeX-style
    = b:subL p:supL {
        return {low: b.low, high: p.high};
    }
    / p:supL b:subL {
        return {low: b.low, high: p.high};
    }
subsupSubscript = o:scriptbase s:sub __? {
    s.base = o;
    s.type = "subsup";
    return {script: s};
}
sub = subU / subL
subU
    = b:unicodeSub {
        return {low: b};
    }
subL
    = b:("_" (soperand))+ {  // allow nested subscripts
        var prevLow = b[0][1];
        for (let x of b.slice(1)) {
            prevLow = {script: {type: "subsup", base: prevLow, low: x[1]}};
        }
        return {low: prevLow};
    }
subsupSuperscript = o:scriptbase s:sup __? {
    s.base = o;
    s.type = "subsup";
    return {script: s};
}
sup = supU / supL
supU
    = p:unicodeSup {
        return {high: p};
    }
supL
    = p:("^" (soperand))+ {  // allow nested subscripts
        var prevHigh = p[0][1];
        for (let x of p.slice(1)) {
            prevHigh = {script: {type: "subsup", base: prevHigh, high: x[1]}};
        }
        return {high: prevHigh};
    }

// prescripts (reusing some of the subsup infrastructure)
preScript
    = "(" __? s:script __? ")" o:operand {
        s.base = o;
        s.type = "pre";
        if (s.hasOwnProperty("low")) {
            s.prelow = s.low;
            delete s.low;
        }
        if (s.hasOwnProperty("high")) {
            s.prehigh = s.high;
            delete s.high;
        }
        return {script: s};
    }
    / s:scriptU o:operand {  // Unicode scripts require no space between
                             // prescript and base
        s.base = o;
        s.type = "pre";
        if (s.hasOwnProperty("low")) {
            s.prelow = s.low;
            delete s.low;
        }
        if (s.hasOwnProperty("high")) {
            s.prehigh = s.high;
            delete s.high;
        }
        return {script: s};
    }
    / s:script _ o:operand {  // mixed or LaTeX-style-only scripts *do* require
                              // a space between prescript and base (in fact, if
                              // the second script of a subsup were a Unicode
                              // script, no space would be strictly required –
                              // but that'd be a mess to integrate into the
                              // grammar)
        s.base = o;
        s.type = "pre";
        if (s.hasOwnProperty("low")) {
            s.prelow = s.low;
            delete s.low;
        }
        if (s.hasOwnProperty("high")) {
            s.prehigh = s.high;
            delete s.high;
        }
        return {script: s};
    }

// scripts above or below the base operand
abovebelowScript
    = abovebelowAbovebelow
    / abovebelowAbove
    / abovebelowBelow
abscript = s:(abovebelow / above / below) {
    s.type = "abovebelow";
    return s;
}
abovebelowAbovebelow = o:scriptbase s:abovebelow __? {
    s.base = o;
    s.type = "abovebelow";
    return {script: s};
}
abovebelow
    = "┬" b:soperand "┴" p:soperand {
        return {low: b, high: p};
    }
    / "┴" p:soperand "┬" b:soperand {
        return {low: b, high: p};
    }
abovebelowAbove = o:scriptbase s:above __? {
    s.base = o;
    s.type = "abovebelow";
    return {script: s};
}
above = "┴" p:(abovebelowAbove / soperand) {
    return {high: p};
}
abovebelowBelow = o:scriptbase s:below __? {
    s.base = o;
    s.type = "abovebelow";
    return {script: s};
}
below = "┬" b:(abovebelowBelow / soperand) {
    return {low: b};
}

// base of all three kinds of script (see primedbase further down)
scriptbase
    = "|" {  // enable using pipe symbol as scriptbase
        return {atoms: {chars: "|"}};
    }
    / e:primedbase (!prime) {return e}  // ⚡ performance optimization
    / primed
    /// primedbase  // ⚡ performance optimization

// contents of scripts
soperand
    = sfactor+
    / o:basicOperator e:sfactor+ {  // for e.g. ∫_-∞^∞
        return [o, e];
    }
    / o:basicOperator+ {  // for e.g. ℕ^+
        return o;
    }

// ❸ high-precedence constructs
sfactor
    = enclosed
    / abstractbox
    / hbrack
    / root
    / function
    / text
    / sizeOverride
    / colored
    / comment
    / tt
    / o:scriptbase s:scriptU {  // this could be called subsupSubsupU, but
                                // without potential trailing spaces
        s.base = o;
        return {script: s};
    }
    / e:entity !("'" / "′" / "″" / "‴" / "⁗" / "‼" / "!") {return e}  // ⚡ performance optimization
    / primed
    / factorial
    /// entity  // ⚡ performance optimization
    / "∞" {  // for correct spacing of e.g. ∫_-∞^∞
        return {atoms: {chars: "∞"}};
    }

// terms enclosed in rectangles, circles, etc.
enclosed
    = "▭(" m:bitmask "&" o:exp ")" {
        return {enclosed: {mask: m, symbol: null, of: o}};
    }
    / e:opEnclosure "(" o:exp ")" {  // ⚡ performance optimization
        return {enclosed: {mask: null, symbol: e, of: o}};
    }
    / e:opEnclosure o:operand {
        return {enclosed: {mask: null, symbol: e, of: o}};
    }

// abstract boxes
abstractbox = opAbstractBox "(" m:bitmask "&" o:exp ")" {
    return {abstractbox: {mask: m, of: o}};
}

// stretchy horizontal brackets above or below terms
hbrack = b:opHbracket o:operand {
    return {hbrack: {bracket: b, of: o}};
}

// roots of various degrees
root
    = "√(" d:operand "&" o:exp ")" {  // *can* use exp here due to the presence
                                      // of a closing backet (could use it for
                                      // the other roots as well if PEG.js could
                                      // be switched into a less greedy mode)
        return {root: {degree: d, of: o}};
    }
    / "√" d:exp opNaryand o:operand {  // alternate notation, e.g. √a+b▒c
        return {root: {degree: d, of: o}};
    }
    / "√" o:operand {
        return {sqrt: o};  // could return {root: {degree: null, of: o}} here,
                           // but treating this as a special case allows
                           // emitting the more semantically meaningful <msqrt>
                           // tag
    }
    / "∛" o:operand {
        return {root: {degree: {number: "3"}, of: o}};
    }
    / "∜" o:operand {
        return {root: {degree: {number: "4"}, of: o}};
    }

// "built-in" functions. the invisible function apply character can be used to
// glue function name and operand together. tech note, section 3.5: "If the
// Function Apply operator is immediately followed by a subscript or superscript
// expression, that expression should be applied to the function name"
function
    = f:functionName ("\u2061" / opNaryand) s:script? __? o:operand {
        if (s != null) {
            s.base = {atoms: {chars: f}};
            return {function: {f: {script: s}, of: o}};
        } else {
            return {function: {f: {atoms: {chars: f}}, of: o}};
        }
    }
    / f:functionName __? o:operand {
        return {function: {f: {atoms: {chars: f}}, of: o}};
    }
functionName
    // via https://www.cs.bgu.ac.il/~khitron/Equation%20Editor.pdf
    = "sin"
    / "sec"
    / "asin"
    / "asec"
    / "arcsin"
    / "arcsec"
    / "sinh"
    / "sech"
    / "asinh"
    / "asech"
    / "arcsinh"
    / "arcsech"
    / "cos"
    / "csc"
    / "acos"
    / "acsc"
    / "arccos"
    / "arccsc"
    / "cosh"
    / "csch"
    / "acosh"
    / "acsch"
    / "arccosh"
    / "arccsch"
    / "tan"
    / "cot"
    / "atan"
    / "acot"
    / "arctan"
    / "arccot"
    / "tanh"
    / "coth"
    / "atanh"
    / "acoth"
    / "arctanh"
    / "arccoth"
    / "arg"
    / "det"
    / "exp"
    / "lim"
    / "def"
    / "dim"
    / "gcd"
    / "ker"
    / "Pr"
    / "deg"
    / "erf"
    / "hom"
    / "log"
    / "lg"
    / "ln"
    / "min"
    / "max"
    / "inf"
    / "sup"
    / "mod"

    // additional functions
    / "lcm"  // "least common multiple"
    / "lub"  // "least upper bound" => sup
    / "glb"  // "greatest lower bound" => inf
    / "lim inf"  // ⚠ space is a non-breaking space and must be entered as such
    / "lim sup"  // ⚠ space is a non-breaking space and must be entered as such

// unprocessed (plain) text
text = '"' c:("\\\"" / (! '"') char)+ '"' {  // see sec. 3.15
    return {text: c.map(v => v[1]).join("")};
}

// font size adjustments
sizeOverride = opSizeOverride s:[A-D] o:(operand / basicOperator) {
    return {sizeoverride: {size: s, of: o}};
}

// ✎ non-standard extensions: colors, comments and typewriter font
colored
    = opColor "(" c:color "&" o:exp ")" {
        return {colored: {color: c, of: o}};
    }
    / opBgColor "(" c:color "&" o:exp ")" {
        return {bgcolored: {color: c, of: o}};
    }
color = co:(!"&" char)+ {  // colors can be anything – it's up to the mathml
                           // renderer to interpret these
    return co.map(c => c[1]).join('');
}
comment = opCommentOpen c:(("\\" opCommentClose) / (! opCommentClose) char)* opCommentClose {
    return {comment: c.map(v => v[1]).join("")};
}
tt = opTt "(" t:("\\)" / (! ")") char)* ")" {
        return {tt: t.map(v => v[1]).join("")};
    }

// identifiers and other constructs with one or many primes
primed = e:primedbase p:prime+ {
    return {primed: {base: e, primes: p.reduce((a, b) => a + b, 0)}}
}
primedbase
    = entity
    / basicOperator
    / o:opNary {
        return {opnary: o};
    }
prime
    = ("'" / "′") {
        return 1;  // for later conversion into one or more Unicode primes
    }
    / "″" {
        return 2;
    }
    / "‴" {
        return 3;
    }
    / "⁗" {
        return 4;
    }

// single and double factorials
factorial
    = e:entity ("‼" / "!!") {
        return {factorial: {factorial: e}};
    }
    / e:entity "!" {
        return {factorial: e};
    }

// ❹ highest-precendence constructs (and brackets/grouping, which is high-
//    precedence with regard to what's outside the brackets, but low-precedence
//    wrt their contents, which are full, standalone expressions)
entity
    = e:expBracket !("\u00A0" / diacritic) {return e}  // ⚡ performance optimization
    / atoms
    / doublestruck
    / number
    /// expBracket  // ⚡ performance optimization

// characters and words, protentially with diacritics
atoms = as:atom+ {
    function k(obj) {
        return Object.keys(obj)[0];
    }
    function v(obj) {
        return Object.values(obj)[0];
    }

    // group successive characters into one "chars" node. this is made a bit
    // complicated by the presence of diacriticized terms, which are
    // interspersed with these "groupable" nodes
    var atoms = [];
    var curChars = "";
    for (var a of as) {
        if (k(a) == "char") {
            curChars += v(a);
        } else {
            if (curChars != "") {
                atoms.push({chars: curChars});
                curChars = ""
            }
            atoms.push(a);
        }
    }
    if (curChars != "") {
        atoms.push({chars: curChars});
    }

    return {atoms: atoms};
}
atom
    = diacriticized
    / "\\" c:char {  // "literal"/escape operator
        return {operator: c};
    }
    / c:αn {
        return {char: c};
    }
    / mathspaces  // for use as null args in e.g. scriptbases to steer kerning

// diacriticized characters, numbers and expressions
diacriticized = b:diacriticbase d:diacritics {
    return {diacriticized: {base: b, diacritics: d}};
}
diacriticbase
    = c:αn {
        return {chars: c};
    }
    / n:nn {
        return {number: n};
    }
    / "(" e:exp ")" "\u00A0"? {  // optional non-breaking space to visually
                                 // decouple diacritic from closing bracket in
                                 // plaintext
        return e;
    }
diacritics = d:diacritic+ {
    return d;
}

// math spaces (can also be used as operators, see way further up)
mathspaces = s:mathspace+ {
    return {spaces: s};
}
mathspace
    = "\u200B" {
        return {space: 0};  // 0/18 em
    }
    / "\u200A" {
        return {space: 1};
    }
    / "\u200A" "\u200A" {
        return {space: 2};
    }
    / "\u2009" {
        return {space: 3};
    }
    / "\u205F" {
        return {space: 4};
    }
    / "\u2005" {
        return {space: 5};
    }
    / "\u2004" {
        return {space: 6};
    }
    / "\u2004" "\u200A" {
        return {space: 7};
    }
    / "\u2002" {
        return {space: 9};
    }
    / "\u2003" {
        return {space: 18};
    }
    / "\u2007" {
        return {space: "digit"};
    }
    / "\u00A0" {
        return {space: "space"};
    }

// numbers, e.g. 1.1 or 1 or .1
number = o:opDecimal b:digits {
        return {number: o + b};
    }
    / a:digits o:opDecimal b:digits {
        return {number: a + o + b};
    }
    / a:digits {
        return {number: a};
    }
digits = n:nn+ {
    return n.join('');
}

// double-struck characters
doublestruck = d:opDoublestruck {
    return {doublestruck: d};
}

// bracketed expressions
expBracket
    = expBracketOpen (expBracketContents / ε) !expBracketClose {

        // better error message than PEG.js would emit, also removes long
        // blocking (which stems almost entirely from PEG.js's error message
        // assembly) when parens are not matched in some situations
        error("Non-matching brackets present or error within brackets")
    }
    / ("||" / "‖") e:exp ("||" / "‖") {
        return {bracketed: {open: "‖", close: "‖", content: e}};
    }
    / "|" e:exp "|" {
        return {bracketed: {open: "|", close: "|", content: e}};
    }
    / "|" e:exp !")" cl:expBracketClose {  // not explicitly mentioned in the
                                           // tech note, but enables
                                           // 𝜌 = ∑_𝜓▒P_𝜓 |𝜓⟩⟨𝜓| + 1
        return {bracketed: {open: "|", close: cl, content: e}};
    }
    / op:expBracketOpen __? cl:expBracketClose {  // empty bracket pairs
        return {bracketed: {open: op, close: cl, content: {atoms: {spaces: {space: 0}}}}};
    }
    / op:expBracketOpen e:expBracketContents cl:expBracketClose {
        return {bracketed: {open: op, close: cl, content: e}};
    }
    / "©(" r:arows ")" {  // cases
        return {bracketed: {open: "{", close: "", content: {array: r}}};  // }
    }
expBracketOpen
    = "〖" {
        return "";
    }
    / op:opOpen {
        return op;
    }
    / "├" m:bitmask op:(opOpen / opClose) {
        return {bracket: op, size: m};
    }
    / "├" op:(opOpen / opClose / "|" / "‖") {
        return op;
    }
    / "├" {
        return "";
    }
expBracketClose
    = "〗" {
        return "";
    }
    / cl:opClose {
        return cl;
    }
    / "| " {  // followed by space, to support bra vectors in dirac notation
        return "|";
    }
    / ("|| " / "‖ ") {  // to support bra vectors in dirac notation
        return "‖";
    }
    / "┤" m:bitmask cl:(opOpen / opClose) {
        return {bracket: cl, size: m};
    }
    / "┤" cl:(opOpen / opClose / "|" / "‖") {
        return cl;
    }
    / "┤" {
        return "";
    }
expBracketContents
    = e:exp !("│" / "∣") {return e}  // ⚡ performance optimization
    / r:(exp "│")+ t:exp {  // U+2502
        return {separated: {separator: "│", of: r.map(a => a[0]).concat([t])}};
    }
    / r:(exp "∣")+ t:exp {  // U+2223
        return {separated: {separator: "∣", of: r.map(a => a[0]).concat([t])}};
    }
    /// exp  // ⚡ performance optimization
