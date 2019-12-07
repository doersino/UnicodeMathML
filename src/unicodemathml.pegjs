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
    function nestLeft(lbl, lis) {
        lis.reverse();
        var ret = lis[0];
        lis = lis.slice(1,lis.length);
        for (var elem in lis) {
            ret = label(lbl, [lis[elem], ret]);
        }
        return ret;
    }

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
        a.forEach(function (e) {
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
nn = nASCII  // note that all characters in the Nd category should be included
             // here, but there's no easy/elegant/performant way of matching on
             // Unicode categories
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
    = αASCII
    / [\u0391-\u03A9\u03B1-\u03C9]  // greek letters
    // note that all characters in the L* categories should be included here,
    // but there's no easy/elegant/performant way of matching on Unicode
    // categories
αn
    = αnMath
    / αnOther
    / emoji
diacritic
    = [\u0300-\u036F\u20D0-\u20FF]  // Combining Diacritical Marks Block +
                                    // Combining Diacritical Marks for Symbols Block
unicodeFraction = [↉½⅓⅔¼¾⅕⅖⅗⅘⅙⅚⅐⅛⅜⅝⅞⅑]
opArray
    = "█"  // matrix
    / "■"  // array
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
arow = __? h:exp? t:(__? "&" __? exp)* __? {
    return {arow: [h].concat(t.map(a => a[3]))};
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
mrow = __? h:exp t:(__? "&" __? exp)* __? {
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
