! Copyright (C) 2022 CapitalEx
! See http://factorcode.org/license.txt for BSD license.
USING: accessors arrays assocs combinators
combinators.short-circuit combinators.smart compiler.units
formatting grouping.extras hash-sets hashtables io
io.encodings.utf8 io.files io.styles kernel namespaces sequences
sequences.extras sequences.parser sets sorting splitting strings
unicode vectors vocabs vocabs.loader vocabs.prettyprint
vocabs.prettyprint.private ;
FROM: namespaces => set ;
IN: lint.vocabs

<PRIVATE
SYMBOL: old-dictionary
SYMBOL: cache
 
! Words for working with the dictionary.
: save-dictionary ( -- )
    dictionary     get clone 
    old-dictionary set       ;

: restore-dictionary ( -- )
    dictionary     get keys >hash-set
    old-dictionary get keys >hash-set
    diff members [ [ forget-vocab ] each ] with-compilation-unit ;

: vocab-loaded? ( name -- ? )
    dictionary get key? ;


! Helper words
: trim-spaces ( seq -- seq )
    [ 32 = ] trim ;

: dedup-nl ( seq -- seq )
    dup [ 10 = ] all? [ members ] when ;

: tokenize ( string -- sequence-parser )
    [ blank? ] group-by
    [ last trim-spaces dedup-nl >string ] map-harvest ;

: split-at ( seq obj -- before after )
    '[ _ = ] split1-when ;

: take-until ( dst: sequence src: sequence token -- dst src )
    split-at [ append ] dip ;

: skip-after ( seq obj -- seq )
    split-at nip ;

: next-line ( sequence-parser -- sequence-parser )
    "\n" skip-after ;

: lone-quote? ( token -- ? )
    { [ length 1 = ] [ first CHAR: " = ] } 1&& ;

: ends-with-quote? ( token -- ? )
    2 tail* { [ first CHAR: \ = not ] [ second CHAR: " = ] } 1&& ;

: comment? ( token -- ? )
    "!" = ;

: string-literal? ( token -- ? )
    first CHAR: " = ;

! Words for removing syntax that should be ignored
: end-string? ( token -- ? )
    { [ lone-quote? ] [ ends-with-quote? ] } 1|| ;

: skip-string ( sequence-parser string -- sequence-parser )
    end-string? [ unclip skip-string ] unless ;

: ?handle-string ( sequence-parser string -- sequence-parser string/f )
    dup { [ empty? not ] [ string-literal? ] } 1&& [ skip-string f ] when ;

: lone-slash? ( string -- ? )
    { [ length 1 = ] [ first CHAR: " = ] } 1&& ;

: ends-with-slash? ( string -- ? )
    2 tail* { [ first CHAR: \ = not  ] [ second CHAR: / = ] } 1&& ;

: end-regex? ( string -- ? )
    { [ lone-slash? ] [ ends-with-slash? ] } 1|| ;

: skip-regex ( vector -- vector )
    unclip end-regex? [ skip-regex ] unless ;

: to-ending ( string -- string ) 
    "[" "]" replace ;

: (parse-ebnf-string) ( end acc code -- code acc )
    unclip {
        { "[[" [ "]]" take-until t ] }
        { "?[" [ "]?" take-until t ] }
        [ reach = not ]
    } case [ (parse-ebnf-string) ] [ nipd swap ] if ;

: parse-ebnf-string ( code end -- vector vector )
    swap [ V{ } clone ] dip (parse-ebnf-string) ;

: parse-ebnf ( vector -- vector vector )
    rest unclip to-ending parse-ebnf-string ;

: next-word/f ( vector -- vector string/f )
    unclip {
        ! skip over empty tokens
        { ""   [ f ] }
        { "\n" [ f ] }

        ! prune syntax stuff
        { "FROM:"     [ ";" skip-after f ] }
        { "SYMBOLS:"  [ ";" skip-after f ] }
        { "R/"        [     skip-regex f ] }
        { "("         [ ")" skip-after f ] }
        { "IN:"       [     rest       f ] }
        { "SYMBOL:"   [     rest       f ] }
        { ":"         [     rest       f ] }
        { "POSTPONE:" [     rest       f ] }
        { "\\"        [     rest       f ] }
        { "CHAR:"     [     rest       f ] }

        ! comments
        { "!"           [             next-line f           ] }
        { "(("          [ "))"       skip-after "(("        ] }
        { "/*"          [ "*/"       skip-after "/*"        ] }
        { "![["         [ "]]"       skip-after "![["       ] }
        { "![=["        [ "]=]"      skip-after "![=["      ] }
        { "![==["       [ "]==]"     skip-after "~[==["     ] }
        { "![===["      [ "]===]"    skip-after "![===["    ] }
        { "![====["     [ "]====]"   skip-after "![====["   ] }
        { "![=====["    [ "]=====]"  skip-after "![=====["  ] }
        { "![======["   [ "]======]" skip-after "![======[" ] }

        ! strings (special case needed for `"`)
        { "STRING:"    [ ";"        skip-after "STRING:"  ] }
        { "[["         [ "]]"       skip-after "[["       ] }
        { "[=["        [ "]=]"      skip-after "[=["      ] }
        { "[==["       [ "]==]"     skip-after "[==["     ] }
        { "[===["      [ "]===]"    skip-after "[===["    ] }
        { "[====["     [ "]====]"   skip-after "[====["   ] }
        { "[=====["    [ "]=====]"  skip-after "[=====["  ] }
        { "[======["   [ "]======]" skip-after "[======[" ] }

        ! EBNF
        { "EBNF:"          [            parse-ebnf        ] }
        { "EBNF[["         [ "]]"       parse-ebnf-string ] }
        { "EBNF[=["        [ "]=]"      parse-ebnf-string ] }
        { "EBNF[==["       [ "]==]"     parse-ebnf-string ] }
        { "EBNF[===["      [ "]===]"    parse-ebnf-string ] }
        { "EBNF[====["     [ "]====]"   parse-ebnf-string ] }
        { "EBNF[=====["    [ "]=====]"  parse-ebnf-string ] }
        { "EBNF[======["   [ "]======]" parse-ebnf-string ] }
        
        ! Annotations
        { "!LICENSE"   [ next-line "!LICENSE" ] }
        { "!AUTHOR"    [ next-line "!AUTHOR"  ] }
        { "!BROKEN"    [ next-line "!BROKEN"  ] }
        { "!REVIEW"    [ next-line "!REVIEW"  ] }
        { "!FIXME"     [ next-line "!FIXME"   ] }
        { "!NOTE"      [ next-line "!NOTE"    ] }
        { "!TODO"      [ next-line "!TODO"    ] }
        { "!BUG"       [ next-line "!BUG"     ] }
        { "!LOL"       [ next-line "!LOL"     ] }
        { "!XXX"       [ next-line "!XXX"     ] }
        
        [ ]
    } case ?handle-string ;

GENERIC: ?add-tokens ( vector vector string -- vector vector )
M: string ?add-tokens ( vector vector vector -- vector vector )
    [ '[ _ suffix ] dip ] when* ;

M: vector ?add-tokens ( vector vector vector -- vector vector )
    [ '[ _ append ] dip ] when* ;

: ?push ( vector vector string/? -- vector vector )
    [ '[ _ suffix ] dip ] when* ;

: ?keep-parsing-with ( vector sequence-parser quot -- vector )
    [ dup empty? not ] dip '[ @ ] [ drop ] if ; inline

: (strip-code) ( vector sequence-praser -- vector )
    next-word/f ?push [ (strip-code) ] ?keep-parsing-with harvest ;

: strip-code ( string -- string )
    tokenize V{ } clone swap (strip-code) ;


! Words for finding the words used in a program
! and stripping out import statements
: skip-imports ( vector -- vector string/? )
    unclip {
        { "USING:"  [ ";" skip-after  f ] }
        { "USE:"    [           rest  f ] }
        [ ]
    } case ;

: take-imports ( vector -- rest result )
    unclip {
        { "USING:" [ ";" split-at swap ] }
        { "USE:"   [        1 cut swap ] }
        [ drop f ]
    } case ;

: (find-used-words) ( vector sequence-parser -- vector )
    skip-imports ?add-tokens [ (find-used-words) ] ?keep-parsing-with ;

: find-used-words ( vector -- set )
    V{ } clone swap (find-used-words) fast-set ;

: (find-imports) ( vector sequence-parser -- vector )
    take-imports rot prepend swap [ (find-imports) ] ?keep-parsing-with ;

: find-imports ( vector -- seq )
    V{ } clone swap (find-imports) dup cache set ;

: (get-words) ( name -- vocab )
    dup load-vocab words>> keys 2array ;

: no-vocab-found ( name -- empty )
    { } 2array ;

: [is-used?] ( hash-set  -- quot )
    '[ nip [ _ in? ] any? ] ; inline

: reject-unused-vocabs ( assoc hash-set -- seq )
    [is-used?] assoc-reject keys ;

:: print-new-header ( seq -- )
    "Use the following header to remove unused imports: " print
    manifest-style [ cache get seq diff pprint-using ] with-nesting ;

:: print-unused-vocabs ( name seq -- )
    name "The following vocabs are unused in %s: \n" printf
    seq [ "    - " prepend print ] each 
    seq print-new-header
    nl
    nl ;

: print-no-unused-vocabs ( name _ -- )
    drop "No unused vocabs found in %s.\n" printf ;


! Private details for fetching words and imports
: get-words ( name -- assoc )
    dup vocab-exists? [ (get-words) ] [ no-vocab-found ] if ;

: get-imported-words ( string -- hashtable )
    save-dictionary
        find-imports [ get-words ] map >hashtable
    restore-dictionary ;

PRIVATE>

: ?find-unused-in-string ( vector -- array )
    [ get-imported-words ] [ find-used-words ] bi
        reject-unused-vocabs natural-sort ;

: find-unused-in-string ( string -- seq )
    strip-code [ empty? not ] [ ?find-unused-in-string ] smart-when >array ;

: find-unused-in-file ( path -- seq )
    utf8 file-contents find-unused-in-string ;

: find-unused ( name -- seq )
    vocab-source-path dup [ find-unused-in-file ] when ;

: find-unused. ( name -- )
    dup find-unused dup empty?
        [ print-no-unused-vocabs ]
           [ print-unused-vocabs ] if ;
