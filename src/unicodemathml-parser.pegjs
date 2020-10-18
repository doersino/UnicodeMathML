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
    / [\u0041-\u005A\u00C0-\u00D6\u00D8-\u00DE\u0100\u0102\u0104\u0106\u0108\u010A\u010C\u010E\u0110\u0112\u0114\u0116\u0118\u011A\u011C\u011E\u0120\u0122\u0124\u0126\u0128\u012A\u012C\u012E\u0130\u0132\u0134\u0136\u0139\u013B\u013D\u013F\u0141\u0143\u0145\u0147\u014A\u014C\u014E\u0150\u0152\u0154\u0156\u0158\u015A\u015C\u015E\u0160\u0162\u0164\u0166\u0168\u016A\u016C\u016E\u0170\u0172\u0174\u0176\u0178-\u0179\u017B\u017D\u0181-\u0182\u0184\u0186-\u0187\u0189-\u018B\u018E-\u0191\u0193-\u0194\u0196-\u0198\u019C-\u019D\u019F-\u01A0\u01A2\u01A4\u01A6-\u01A7\u01A9\u01AC\u01AE-\u01AF\u01B1-\u01B3\u01B5\u01B7-\u01B8\u01BC\u01C4\u01C7\u01CA\u01CD\u01CF\u01D1\u01D3\u01D5\u01D7\u01D9\u01DB\u01DE\u01E0\u01E2\u01E4\u01E6\u01E8\u01EA\u01EC\u01EE\u01F1\u01F4\u01F6-\u01F8\u01FA\u01FC\u01FE\u0200\u0202\u0204\u0206\u0208\u020A\u020C\u020E\u0210\u0212\u0214\u0216\u0218\u021A\u021C\u021E\u0220\u0222\u0224\u0226\u0228\u022A\u022C\u022E\u0230\u0232\u023A-\u023B\u023D-\u023E\u0241\u0243-\u0246\u0248\u024A\u024C\u024E\u0370\u0372\u0376\u037F\u0386\u0388-\u038A\u038C\u038E-\u038F\u0391-\u03A1\u03A3-\u03AB\u03CF\u03D2-\u03D4\u03D8\u03DA\u03DC\u03DE\u03E0\u03E2\u03E4\u03E6\u03E8\u03EA\u03EC\u03EE\u03F4\u03F7\u03F9-\u03FA\u03FD-\u042F\u0460\u0462\u0464\u0466\u0468\u046A\u046C\u046E\u0470\u0472\u0474\u0476\u0478\u047A\u047C\u047E\u0480\u048A\u048C\u048E\u0490\u0492\u0494\u0496\u0498\u049A\u049C\u049E\u04A0\u04A2\u04A4\u04A6\u04A8\u04AA\u04AC\u04AE\u04B0\u04B2\u04B4\u04B6\u04B8\u04BA\u04BC\u04BE\u04C0-\u04C1\u04C3\u04C5\u04C7\u04C9\u04CB\u04CD\u04D0\u04D2\u04D4\u04D6\u04D8\u04DA\u04DC\u04DE\u04E0\u04E2\u04E4\u04E6\u04E8\u04EA\u04EC\u04EE\u04F0\u04F2\u04F4\u04F6\u04F8\u04FA\u04FC\u04FE\u0500\u0502\u0504\u0506\u0508\u050A\u050C\u050E\u0510\u0512\u0514\u0516\u0518\u051A\u051C\u051E\u0520\u0522\u0524\u0526\u0528\u052A\u052C\u052E\u0531-\u0556\u10A0-\u10C5\u10C7\u10CD\u13A0-\u13F5\u1C90-\u1CBA\u1CBD-\u1CBF\u1E00\u1E02\u1E04\u1E06\u1E08\u1E0A\u1E0C\u1E0E\u1E10\u1E12\u1E14\u1E16\u1E18\u1E1A\u1E1C\u1E1E\u1E20\u1E22\u1E24\u1E26\u1E28\u1E2A\u1E2C\u1E2E\u1E30\u1E32\u1E34\u1E36\u1E38\u1E3A\u1E3C\u1E3E\u1E40\u1E42\u1E44\u1E46\u1E48\u1E4A\u1E4C\u1E4E\u1E50\u1E52\u1E54\u1E56\u1E58\u1E5A\u1E5C\u1E5E\u1E60\u1E62\u1E64\u1E66\u1E68\u1E6A\u1E6C\u1E6E\u1E70\u1E72\u1E74\u1E76\u1E78\u1E7A\u1E7C\u1E7E\u1E80\u1E82\u1E84\u1E86\u1E88\u1E8A\u1E8C\u1E8E\u1E90\u1E92\u1E94\u1E9E\u1EA0\u1EA2\u1EA4\u1EA6\u1EA8\u1EAA\u1EAC\u1EAE\u1EB0\u1EB2\u1EB4\u1EB6\u1EB8\u1EBA\u1EBC\u1EBE\u1EC0\u1EC2\u1EC4\u1EC6\u1EC8\u1ECA\u1ECC\u1ECE\u1ED0\u1ED2\u1ED4\u1ED6\u1ED8\u1EDA\u1EDC\u1EDE\u1EE0\u1EE2\u1EE4\u1EE6\u1EE8\u1EEA\u1EEC\u1EEE\u1EF0\u1EF2\u1EF4\u1EF6\u1EF8\u1EFA\u1EFC\u1EFE\u1F08-\u1F0F\u1F18-\u1F1D\u1F28-\u1F2F\u1F38-\u1F3F\u1F48-\u1F4D\u1F59\u1F5B\u1F5D\u1F5F\u1F68-\u1F6F\u1FB8-\u1FBB\u1FC8-\u1FCB\u1FD8-\u1FDB\u1FE8-\u1FEC\u1FF8-\u1FFB\u2102\u2107\u210B-\u210D\u2110-\u2112\u2115\u2119-\u211D\u2124\u2126\u2128\u212A-\u212D\u2130-\u2133\u213E-\u213F\u2183\u2C00-\u2C2E\u2C60\u2C62-\u2C64\u2C67\u2C69\u2C6B\u2C6D-\u2C70\u2C72\u2C75\u2C7E-\u2C80\u2C82\u2C84\u2C86\u2C88\u2C8A\u2C8C\u2C8E\u2C90\u2C92\u2C94\u2C96\u2C98\u2C9A\u2C9C\u2C9E\u2CA0\u2CA2\u2CA4\u2CA6\u2CA8\u2CAA\u2CAC\u2CAE\u2CB0\u2CB2\u2CB4\u2CB6\u2CB8\u2CBA\u2CBC\u2CBE\u2CC0\u2CC2\u2CC4\u2CC6\u2CC8\u2CCA\u2CCC\u2CCE\u2CD0\u2CD2\u2CD4\u2CD6\u2CD8\u2CDA\u2CDC\u2CDE\u2CE0\u2CE2\u2CEB\u2CED\u2CF2\uA640\uA642\uA644\uA646\uA648\uA64A\uA64C\uA64E\uA650\uA652\uA654\uA656\uA658\uA65A\uA65C\uA65E\uA660\uA662\uA664\uA666\uA668\uA66A\uA66C\uA680\uA682\uA684\uA686\uA688\uA68A\uA68C\uA68E\uA690\uA692\uA694\uA696\uA698\uA69A\uA722\uA724\uA726\uA728\uA72A\uA72C\uA72E\uA732\uA734\uA736\uA738\uA73A\uA73C\uA73E\uA740\uA742\uA744\uA746\uA748\uA74A\uA74C\uA74E\uA750\uA752\uA754\uA756\uA758\uA75A\uA75C\uA75E\uA760\uA762\uA764\uA766\uA768\uA76A\uA76C\uA76E\uA779\uA77B\uA77D-\uA77E\uA780\uA782\uA784\uA786\uA78B\uA78D\uA790\uA792\uA796\uA798\uA79A\uA79C\uA79E\uA7A0\uA7A2\uA7A4\uA7A6\uA7A8\uA7AA-\uA7AE\uA7B0-\uA7B4\uA7B6\uA7B8\uA7BA\uA7BC\uA7BE\uA7C2\uA7C4-\uA7C7\uA7C9\uA7F5\uFF21-\uFF3A\u0061-\u007A\u00B5\u00DF-\u00F6\u00F8-\u00FF\u0101\u0103\u0105\u0107\u0109\u010B\u010D\u010F\u0111\u0113\u0115\u0117\u0119\u011B\u011D\u011F\u0121\u0123\u0125\u0127\u0129\u012B\u012D\u012F\u0131\u0133\u0135\u0137-\u0138\u013A\u013C\u013E\u0140\u0142\u0144\u0146\u0148-\u0149\u014B\u014D\u014F\u0151\u0153\u0155\u0157\u0159\u015B\u015D\u015F\u0161\u0163\u0165\u0167\u0169\u016B\u016D\u016F\u0171\u0173\u0175\u0177\u017A\u017C\u017E-\u0180\u0183\u0185\u0188\u018C-\u018D\u0192\u0195\u0199-\u019B\u019E\u01A1\u01A3\u01A5\u01A8\u01AA-\u01AB\u01AD\u01B0\u01B4\u01B6\u01B9-\u01BA\u01BD-\u01BF\u01C6\u01C9\u01CC\u01CE\u01D0\u01D2\u01D4\u01D6\u01D8\u01DA\u01DC-\u01DD\u01DF\u01E1\u01E3\u01E5\u01E7\u01E9\u01EB\u01ED\u01EF-\u01F0\u01F3\u01F5\u01F9\u01FB\u01FD\u01FF\u0201\u0203\u0205\u0207\u0209\u020B\u020D\u020F\u0211\u0213\u0215\u0217\u0219\u021B\u021D\u021F\u0221\u0223\u0225\u0227\u0229\u022B\u022D\u022F\u0231\u0233-\u0239\u023C\u023F-\u0240\u0242\u0247\u0249\u024B\u024D\u024F-\u0293\u0295-\u02AF\u0371\u0373\u0377\u037B-\u037D\u0390\u03AC-\u03CE\u03D0-\u03D1\u03D5-\u03D7\u03D9\u03DB\u03DD\u03DF\u03E1\u03E3\u03E5\u03E7\u03E9\u03EB\u03ED\u03EF-\u03F3\u03F5\u03F8\u03FB-\u03FC\u0430-\u045F\u0461\u0463\u0465\u0467\u0469\u046B\u046D\u046F\u0471\u0473\u0475\u0477\u0479\u047B\u047D\u047F\u0481\u048B\u048D\u048F\u0491\u0493\u0495\u0497\u0499\u049B\u049D\u049F\u04A1\u04A3\u04A5\u04A7\u04A9\u04AB\u04AD\u04AF\u04B1\u04B3\u04B5\u04B7\u04B9\u04BB\u04BD\u04BF\u04C2\u04C4\u04C6\u04C8\u04CA\u04CC\u04CE-\u04CF\u04D1\u04D3\u04D5\u04D7\u04D9\u04DB\u04DD\u04DF\u04E1\u04E3\u04E5\u04E7\u04E9\u04EB\u04ED\u04EF\u04F1\u04F3\u04F5\u04F7\u04F9\u04FB\u04FD\u04FF\u0501\u0503\u0505\u0507\u0509\u050B\u050D\u050F\u0511\u0513\u0515\u0517\u0519\u051B\u051D\u051F\u0521\u0523\u0525\u0527\u0529\u052B\u052D\u052F\u0560-\u0588\u10D0-\u10FA\u10FD-\u10FF\u13F8-\u13FD\u1C80-\u1C88\u1D00-\u1D2B\u1D6B-\u1D77\u1D79-\u1D9A\u1E01\u1E03\u1E05\u1E07\u1E09\u1E0B\u1E0D\u1E0F\u1E11\u1E13\u1E15\u1E17\u1E19\u1E1B\u1E1D\u1E1F\u1E21\u1E23\u1E25\u1E27\u1E29\u1E2B\u1E2D\u1E2F\u1E31\u1E33\u1E35\u1E37\u1E39\u1E3B\u1E3D\u1E3F\u1E41\u1E43\u1E45\u1E47\u1E49\u1E4B\u1E4D\u1E4F\u1E51\u1E53\u1E55\u1E57\u1E59\u1E5B\u1E5D\u1E5F\u1E61\u1E63\u1E65\u1E67\u1E69\u1E6B\u1E6D\u1E6F\u1E71\u1E73\u1E75\u1E77\u1E79\u1E7B\u1E7D\u1E7F\u1E81\u1E83\u1E85\u1E87\u1E89\u1E8B\u1E8D\u1E8F\u1E91\u1E93\u1E95-\u1E9D\u1E9F\u1EA1\u1EA3\u1EA5\u1EA7\u1EA9\u1EAB\u1EAD\u1EAF\u1EB1\u1EB3\u1EB5\u1EB7\u1EB9\u1EBB\u1EBD\u1EBF\u1EC1\u1EC3\u1EC5\u1EC7\u1EC9\u1ECB\u1ECD\u1ECF\u1ED1\u1ED3\u1ED5\u1ED7\u1ED9\u1EDB\u1EDD\u1EDF\u1EE1\u1EE3\u1EE5\u1EE7\u1EE9\u1EEB\u1EED\u1EEF\u1EF1\u1EF3\u1EF5\u1EF7\u1EF9\u1EFB\u1EFD\u1EFF-\u1F07\u1F10-\u1F15\u1F20-\u1F27\u1F30-\u1F37\u1F40-\u1F45\u1F50-\u1F57\u1F60-\u1F67\u1F70-\u1F7D\u1F80-\u1F87\u1F90-\u1F97\u1FA0-\u1FA7\u1FB0-\u1FB4\u1FB6-\u1FB7\u1FBE\u1FC2-\u1FC4\u1FC6-\u1FC7\u1FD0-\u1FD3\u1FD6-\u1FD7\u1FE0-\u1FE7\u1FF2-\u1FF4\u1FF6-\u1FF7\u210A\u210E-\u210F\u2113\u212F\u2134\u2139\u213C-\u213D\u214E\u2184\u2C30-\u2C5E\u2C61\u2C65-\u2C66\u2C68\u2C6A\u2C6C\u2C71\u2C73-\u2C74\u2C76-\u2C7B\u2C81\u2C83\u2C85\u2C87\u2C89\u2C8B\u2C8D\u2C8F\u2C91\u2C93\u2C95\u2C97\u2C99\u2C9B\u2C9D\u2C9F\u2CA1\u2CA3\u2CA5\u2CA7\u2CA9\u2CAB\u2CAD\u2CAF\u2CB1\u2CB3\u2CB5\u2CB7\u2CB9\u2CBB\u2CBD\u2CBF\u2CC1\u2CC3\u2CC5\u2CC7\u2CC9\u2CCB\u2CCD\u2CCF\u2CD1\u2CD3\u2CD5\u2CD7\u2CD9\u2CDB\u2CDD\u2CDF\u2CE1\u2CE3-\u2CE4\u2CEC\u2CEE\u2CF3\u2D00-\u2D25\u2D27\u2D2D\uA641\uA643\uA645\uA647\uA649\uA64B\uA64D\uA64F\uA651\uA653\uA655\uA657\uA659\uA65B\uA65D\uA65F\uA661\uA663\uA665\uA667\uA669\uA66B\uA66D\uA681\uA683\uA685\uA687\uA689\uA68B\uA68D\uA68F\uA691\uA693\uA695\uA697\uA699\uA69B\uA723\uA725\uA727\uA729\uA72B\uA72D\uA72F-\uA731\uA733\uA735\uA737\uA739\uA73B\uA73D\uA73F\uA741\uA743\uA745\uA747\uA749\uA74B\uA74D\uA74F\uA751\uA753\uA755\uA757\uA759\uA75B\uA75D\uA75F\uA761\uA763\uA765\uA767\uA769\uA76B\uA76D\uA76F\uA771-\uA778\uA77A\uA77C\uA77F\uA781\uA783\uA785\uA787\uA78C\uA78E\uA791\uA793-\uA795\uA797\uA799\uA79B\uA79D\uA79F\uA7A1\uA7A3\uA7A5\uA7A7\uA7A9\uA7AF\uA7B5\uA7B7\uA7B9\uA7BB\uA7BD\uA7BF\uA7C3\uA7C8\uA7CA\uA7F6\uA7FA\uAB30-\uAB5A\uAB60-\uAB68\uAB70-\uABBF\uFB00-\uFB06\uFB13-\uFB17\uFF41-\uFF5A\u01C5\u01C8\u01CB\u01F2\u1F88-\u1F8F\u1F98-\u1F9F\u1FA8-\u1FAF\u1FBC\u1FCC\u1FFC\u02B0-\u02C1\u02C6-\u02D1\u02E0-\u02E4\u02EC\u02EE\u0374\u037A\u0559\u0640\u06E5-\u06E6\u07F4-\u07F5\u07FA\u081A\u0824\u0828\u0971\u0E46\u0EC6\u10FC\u17D7\u1843\u1AA7\u1C78-\u1C7D\u1D2C-\u1D6A\u1D78\u1D9B-\u1DBF\u2071\u207F\u2090-\u209C\u2C7C-\u2C7D\u2D6F\u2E2F\u3005\u3031-\u3035\u303B\u309D-\u309E\u30FC-\u30FE\uA015\uA4F8-\uA4FD\uA60C\uA67F\uA69C-\uA69D\uA717-\uA71F\uA770\uA788\uA7F8-\uA7F9\uA9CF\uA9E6\uAA70\uAADD\uAAF3-\uAAF4\uAB5C-\uAB5F\uAB69\uFF70\uFF9E-\uFF9F\u00AA\u00BA\u01BB\u01C0-\u01C3\u0294\u05D0-\u05EA\u05EF-\u05F2\u0620-\u063F\u0641-\u064A\u066E-\u066F\u0671-\u06D3\u06D5\u06EE-\u06EF\u06FA-\u06FC\u06FF\u0710\u0712-\u072F\u074D-\u07A5\u07B1\u07CA-\u07EA\u0800-\u0815\u0840-\u0858\u0860-\u086A\u08A0-\u08B4\u08B6-\u08C7\u0904-\u0939\u093D\u0950\u0958-\u0961\u0972-\u0980\u0985-\u098C\u098F-\u0990\u0993-\u09A8\u09AA-\u09B0\u09B2\u09B6-\u09B9\u09BD\u09CE\u09DC-\u09DD\u09DF-\u09E1\u09F0-\u09F1\u09FC\u0A05-\u0A0A\u0A0F-\u0A10\u0A13-\u0A28\u0A2A-\u0A30\u0A32-\u0A33\u0A35-\u0A36\u0A38-\u0A39\u0A59-\u0A5C\u0A5E\u0A72-\u0A74\u0A85-\u0A8D\u0A8F-\u0A91\u0A93-\u0AA8\u0AAA-\u0AB0\u0AB2-\u0AB3\u0AB5-\u0AB9\u0ABD\u0AD0\u0AE0-\u0AE1\u0AF9\u0B05-\u0B0C\u0B0F-\u0B10\u0B13-\u0B28\u0B2A-\u0B30\u0B32-\u0B33\u0B35-\u0B39\u0B3D\u0B5C-\u0B5D\u0B5F-\u0B61\u0B71\u0B83\u0B85-\u0B8A\u0B8E-\u0B90\u0B92-\u0B95\u0B99-\u0B9A\u0B9C\u0B9E-\u0B9F\u0BA3-\u0BA4\u0BA8-\u0BAA\u0BAE-\u0BB9\u0BD0\u0C05-\u0C0C\u0C0E-\u0C10\u0C12-\u0C28\u0C2A-\u0C39\u0C3D\u0C58-\u0C5A\u0C60-\u0C61\u0C80\u0C85-\u0C8C\u0C8E-\u0C90\u0C92-\u0CA8\u0CAA-\u0CB3\u0CB5-\u0CB9\u0CBD\u0CDE\u0CE0-\u0CE1\u0CF1-\u0CF2\u0D04-\u0D0C\u0D0E-\u0D10\u0D12-\u0D3A\u0D3D\u0D4E\u0D54-\u0D56\u0D5F-\u0D61\u0D7A-\u0D7F\u0D85-\u0D96\u0D9A-\u0DB1\u0DB3-\u0DBB\u0DBD\u0DC0-\u0DC6\u0E01-\u0E30\u0E32-\u0E33\u0E40-\u0E45\u0E81-\u0E82\u0E84\u0E86-\u0E8A\u0E8C-\u0EA3\u0EA5\u0EA7-\u0EB0\u0EB2-\u0EB3\u0EBD\u0EC0-\u0EC4\u0EDC-\u0EDF\u0F00\u0F40-\u0F47\u0F49-\u0F6C\u0F88-\u0F8C\u1000-\u102A\u103F\u1050-\u1055\u105A-\u105D\u1061\u1065-\u1066\u106E-\u1070\u1075-\u1081\u108E\u1100-\u1248\u124A-\u124D\u1250-\u1256\u1258\u125A-\u125D\u1260-\u1288\u128A-\u128D\u1290-\u12B0\u12B2-\u12B5\u12B8-\u12BE\u12C0\u12C2-\u12C5\u12C8-\u12D6\u12D8-\u1310\u1312-\u1315\u1318-\u135A\u1380-\u138F\u1401-\u166C\u166F-\u167F\u1681-\u169A\u16A0-\u16EA\u16F1-\u16F8\u1700-\u170C\u170E-\u1711\u1720-\u1731\u1740-\u1751\u1760-\u176C\u176E-\u1770\u1780-\u17B3\u17DC\u1820-\u1842\u1844-\u1878\u1880-\u1884\u1887-\u18A8\u18AA\u18B0-\u18F5\u1900-\u191E\u1950-\u196D\u1970-\u1974\u1980-\u19AB\u19B0-\u19C9\u1A00-\u1A16\u1A20-\u1A54\u1B05-\u1B33\u1B45-\u1B4B\u1B83-\u1BA0\u1BAE-\u1BAF\u1BBA-\u1BE5\u1C00-\u1C23\u1C4D-\u1C4F\u1C5A-\u1C77\u1CE9-\u1CEC\u1CEE-\u1CF3\u1CF5-\u1CF6\u1CFA\u2135-\u2138\u2D30-\u2D67\u2D80-\u2D96\u2DA0-\u2DA6\u2DA8-\u2DAE\u2DB0-\u2DB6\u2DB8-\u2DBE\u2DC0-\u2DC6\u2DC8-\u2DCE\u2DD0-\u2DD6\u2DD8-\u2DDE\u3006\u303C\u3041-\u3096\u309F\u30A1-\u30FA\u30FF\u3105-\u312F\u3131-\u318E\u31A0-\u31BF\u31F0-\u31FF\u3400-\u4DBF\u4E00-\u9FFC\uA000-\uA014\uA016-\uA48C\uA4D0-\uA4F7\uA500-\uA60B\uA610-\uA61F\uA62A-\uA62B\uA66E\uA6A0-\uA6E5\uA78F\uA7F7\uA7FB-\uA801\uA803-\uA805\uA807-\uA80A\uA80C-\uA822\uA840-\uA873\uA882-\uA8B3\uA8F2-\uA8F7\uA8FB\uA8FD-\uA8FE\uA90A-\uA925\uA930-\uA946\uA960-\uA97C\uA984-\uA9B2\uA9E0-\uA9E4\uA9E7-\uA9EF\uA9FA-\uA9FE\uAA00-\uAA28\uAA40-\uAA42\uAA44-\uAA4B\uAA60-\uAA6F\uAA71-\uAA76\uAA7A\uAA7E-\uAAAF\uAAB1\uAAB5-\uAAB6\uAAB9-\uAABD\uAAC0\uAAC2\uAADB-\uAADC\uAAE0-\uAAEA\uAAF2\uAB01-\uAB06\uAB09-\uAB0E\uAB11-\uAB16\uAB20-\uAB26\uAB28-\uAB2E\uABC0-\uABE2\uAC00-\uD7A3\uD7B0-\uD7C6\uD7CB-\uD7FB\uF900-\uFA6D\uFA70-\uFAD9\uFB1D\uFB1F-\uFB28\uFB2A-\uFB36\uFB38-\uFB3C\uFB3E\uFB40-\uFB41\uFB43-\uFB44\uFB46-\uFBB1\uFBD3-\uFD3D\uFD50-\uFD8F\uFD92-\uFDC7\uFDF0-\uFDFB\uFE70-\uFE74\uFE76-\uFEFC\uFF66-\uFF6F\uFF71-\uFF9D\uFFA0-\uFFBE\uFFC2-\uFFC7\uFFCA-\uFFCF\uFFD2-\uFFD6\uFFDA-\uFFDC]
    // note that this is all BMP characters from the L* categories, based on https://www.unicode.org/Public/13.0.0/ucd/extracted/DerivedGeneralCategory-13.0.0d3.txt and `grep "; L" DerivedGeneralCategory-13.0.0d3.txt | cut -f1 -d " " | grep -v '[0-9a-fA-F]\{5\}' | sed -e 's/\.\./-/' | sed -e 's/\([0-9a-fA-F]\{4\}\)/\\u\1/g' | tr -d '\n'` (via https://github.com/pegjs/pegjs/blob/master/examples/javascript.pegjs#L374) sans double-struck characters \u2145 and \u2146-\u2149 and with \uFFD2-\uFFD7 replaced by \uFFD2-\uFFD6 to exclude the typewriter font marker
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
