! Copyright (C) 2022 CapitalEx
! See http://factorcode.org/license.txt for BSD license.
USING: accessors arrays assocs combinators compiler.units
formatting grouping.extras hash-sets hashtables io
io.encodings.utf8 io.files kernel multiline namespaces peg.ebnf
regexp sequences sequences.deep sequences.parser sets sorting
splitting strings unicode vocabs vocabs.loader ;
FROM: namespaces => set ;
IN: lint.vocabs

<PRIVATE
SYMBOL: old-dictionary
SYMBOL: LINT-VOCABS-REGEX

: tokenize ( string -- sequence-parser )
    <sequence-parser> ;

: skip-after ( sequence-parser seq -- sequence-parser )
   [ take-until-sequence* drop ] curry keep ;

: next-line ( sequence-parser -- sequence-parser )
    "\n" skip-after ;

DEFER: next-token

: reject-token ( sequence-parser token -- string )
    drop next-line next-token ;

: accept-token ( sequence-parser token -- string )
    nip >string ;

: comment? ( token -- ? )
    "!" = ;

: get-token ( sequence-parser -- token )
    skip-whitespace [ current blank? ] take-until ;

: next-token ( sequence-parser -- string )
    dup get-token dup comment?
        [ reject-token ] 
        [ accept-token ] if ;

: skip-token ( sequence-parser -- sequence-parser )
    dup next-token drop  ;

: quotation-mark? ( token -- ? )
    first CHAR: " = ;

: ends-with-quote? ( token -- ? )
    2 tail* [ first CHAR: \ = not ] 
            [ second CHAR: " =    ] bi and ;

: end-string? ( token -- ? )
    dup length 1 = [ quotation-mark? ] [ ends-with-quote? ] if ;

: skip-string ( sequence-parser -- sequence-parser )
    dup next-token end-string? not [ skip-string ] when ;

: is-string? ( token -- ? )
    first CHAR: " = ;

: next-word ( sequence-parser -- sequence-parser string/f )
    dup next-token break {
        ! prune syntax stuff
        { ""          [ f ] }
        { "FROM:"     [ ";" skip-after f ] }
        { "IN:"       [ skip-token f ] }
        { "SYMBOL:"   [ skip-token f ] }
        { "SYMBOLS:"  [ ";" skip-after f ] }
        { "("         [ ")" skip-after f ] }
        { ":"         [ skip-token f ] }

        ! comments
        { "!"           [ next-line f ] }
        { "(("          [ "))"      skip-after f ] }
        { "/*"          [ "*/"      skip-after f ] }
        { "![["         [ "]]"      skip-after f ] }
        { "![=["        [ "]=]"     skip-after f ] }
        { "![==["       [ "]==]"    skip-after f ] }
        { "![===["      [ "]===]"   skip-after f ] }
        { "![====["     [ "]====]"  skip-after f ] }
        { "![=====["    [ "]=====]" skip-after f ] }
        { "![======["   [ "]======]" skip-after f ] }

        ! strings (special case needed for `"`)
        { "STRING:"    [ ";"       skip-after f ] }
        { "[["         [ "]]"      skip-after f ] }
        { "[=["        [ "]=]"     skip-after f ] }
        { "[==["       [ "]==]"    skip-after f ] }
        { "[===["      [ "]===]"   skip-after f ] }
        { "[====["     [ "]====]"  skip-after f ] }
        { "[=====["    [ "]=====]" skip-after f ] }
        { "[======["   [ "]======]" skip-after f ] }

        ! EBNF
        { "EBNF[["         [ "]]"      skip-after f ] }
        { "EBNF[=["        [ "]=]"     skip-after f ] }
        { "EBNF[==["       [ "]==]"    skip-after f ] }
        { "EBNF[===["      [ "]===]"   skip-after f ] }
        { "EBNF[====["     [ "]====]"  skip-after f ] }
        { "EBNF[=====["    [ "]=====]" skip-after f ] }
        { "EBNF[======["   [ "]======]" skip-after f ] }

        ! miscellaneous 
        { "POSTPONE: " [ skip-token f ] }
        { "\\"         [ skip-token f ] }
        { "!AUTHOR"    [ next-line f ] }
        { "!BROKEN"    [ next-line f ] }
        { "!BUG"       [ next-line f ] }
        { "!FIXME"     [ next-line f ] }
        { "!LICENSE"   [ next-line f ] }
        { "!LOL"       [ next-line f ] }
        { "!NOTE"      [ next-line f ] }
        { "!REVIEW"    [ next-line f ] }
        { "!TODO"      [ next-line f ] }
        { "!XXX"       [ next-line f ] }
        
        ! special cause for handling `"`
        [ dup is-string? [ drop skip-string f ] when ]
    } case ;

: all-blank? ( string -- ? )
    [ blank? ] all? ;

: ?store-word ( vector sequence-parser string/? -- vector sequence-parser )
    [ [ swap [ push ] keep ] curry dip ] when* ;

DEFER: collect

: ?keep-parsing ( vector sequence-parser -- vector )
    dup sequence-parse-end? [ drop ] [ collect ] if ;

: collect ( vector sequence-praser -- vector )
    skip-whitespace next-word 
        ?store-word ?keep-parsing 
    harvest ;

! Cache regular expression to avoid compile time slowdowns
"CHAR:\\s+\\S+\\s+|\"(\\\\\\\\|\\\\[\\\\stnrbvf0e\"]|\\\\x[a-fA-F0-9]{2}|\\\\u[a-fA-F0-9]{6}|[^\\\\\"])*\"|R/ (\\\\/|[^/])*/|\\\\\\s+(USE:|USING:)|POSTPONE:\\s+(USE:|USING:)|(?<!\\S+)! [^\n]*" <regexp>
LINT-VOCABS-REGEX set-global

: save-dictionary ( -- )
    dictionary     get clone 
    old-dictionary set       ;

: restore-dictionary ( -- )
    dictionary     get keys >hash-set
    old-dictionary get keys >hash-set
    diff members [ [ forget-vocab ] each ] with-compilation-unit ;

: vocab-loaded? ( name -- ? )
    dictionary get key? ;

: (get-words) ( name -- vocab )
    dup load-vocab words>> keys 2array ;

: no-vocab-found ( name -- empty )
    { } 2array ;

: nl>space ( string -- string )
    "\n" " " replace ;

: find-import-statements ( string -- seq )
    "USING: [^;]+ ;|USE: \\S+" <regexp> all-matching-subseqs ;

: clean-up-source ( string -- string ) 
    LINT-VOCABS-REGEX get-global "" re-replace ;

: strip-syntax ( seq -- seq )
    [ "USING: | ;|USE: " <regexp> " " re-replace ] map ;

: split-when-blank ( string -- seq )
    [ blank? ] split-when ;

: split-words ( line -- words )
    [ split-when-blank ] map flatten harvest ;

: get-unique-words ( seq -- hash-set )
    harvest split-words >hash-set ;

: [is-used?] ( hash-set  -- quot )
    '[ nip [ _ in? ] any? ] ; inline

: reject-unused-vocabs ( assoc hash-set -- seq )
    [is-used?] assoc-reject keys ;

: print-unused-vocabs ( name seq -- )
    swap "The following vocabs are unused in %s: \n" printf
        [ "    - " prepend print ] each ;

: print-no-unused-vocabs ( name _ -- )
    drop "No unused vocabs found in %s.\n" printf ;

PRIVATE>

: get-words ( name -- assoc )
    dup vocab-exists? 
        [ (get-words) ]
        [ no-vocab-found ] if ;

: get-vocabs ( string -- seq )
    nl>space find-import-statements strip-syntax split-words harvest ;

: get-imported-words ( string -- hashtable )
    save-dictionary 
        get-vocabs [ get-words ] map >hashtable 
    restore-dictionary 
    ;

: find-unused-in-string ( string -- seq )
    clean-up-source
    [ get-imported-words ] [ "\n" split get-unique-words ] bi
    reject-unused-vocabs natural-sort ; inline

: find-unused-in-file ( path -- seq )
    utf8 file-contents find-unused-in-string ;

: find-unused ( name -- seq )
    vocab-source-path dup [ find-unused-in-file ] when ;

: find-unused. ( name -- )
    dup find-unused dup empty?
        [ print-no-unused-vocabs ]
           [ print-unused-vocabs ] if ;
