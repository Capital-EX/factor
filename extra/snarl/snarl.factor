! Copyright (C) 2023 CapitalEx.
! See https://factorcode.org/license.txt for BSD license.
USING: accessors arrays assocs calendar combinators
combinators.extras combinators.short-circuit command-line farkup
formatting html.forms html.templates html.templates.chloe
interpolate io io.directories io.encodings.utf8 io.files
io.files.info io.streams.string kernel linked-sets math
multiline namespaces sequences sequences.deep sets sorting
sorting.human splitting strings system tools.time unicode
xml.data xml.traversal ;
FROM: xml.data => xml? ;
FROM: namespaces => set ;
IN: snarl

<PRIVATE
CONSTANT: index [=[ = Hello, Snarl! =

Welcome to your [[snarl|Snarl]] wiki! Just start adding articles by creating %.farkup%. Make sure to include a top-level header for each article!]=]

CONSTANT: about-snarl [=[ = Snarl =
_A flat-file wiki generator!_

Snarl is my personal flat-file wiki generator. It takes a pile of %.farkup% files and turns them into the wiki you are looking at. There is no structural hierachy nor database only files! Wiki pages are written using [[https://concatenative.org/wiki/view/Farkup|Farkup]].

However, it isn't feature rich. _But it isn't meant to be!_. Their isn't an advance templating. Nor, does Snarl feature theming outside of it's %style.css%. The only "advance" features Snarl has is computing backlinks and providing a _flat_ listing of headers in the current article. The only searching of pages is the [[sitemap|Site Map]].

If you need fancy, [[https://getzola.org|Zola]] pretty nice.]=]

CONSTANT: HEADINGS { "h1" "h2" "h3" "h4" "h5" "h6" }

! Dynamic state
SYMBOLS: wiki-dir current-page page-titles backlinks headers site-pages ;
: ready-backlinks ( -- ) H{ } clone backlinks  set ;
: ready-headers   ( -- ) H{ } clone headers    set ;
: ready-pages     ( -- ) V{ } clone site-pages set ;

: get-backlinks ( name -- backlinks ) backlinks get [ drop 0 <linked-set> ] cache ;
: get-headers   ( name -- headers   ) headers   get [ drop 0 <linked-set> ] cache ;


! File interactions
: clear-output-dir ( -- ) 
    wiki-dir get I"${0}/public" dup directory-files 
    [ ".html" tail? ] filter 
    [ "/" glue delete-file ] with each ; inline

: output-file ( page -- file-name ) name>> wiki-dir get I"${0}/public/${1}.html" ; inline
: page-template    ( -- chloe ) wiki-dir get I"${}/_templates/wiki-page" <chloe> ; inline
: article-template ( -- chloe ) wiki-dir get I"${}/_templates/wiki-article" <chloe> ; inline
: get-sitemap-template ( -- chloe ) wiki-dir get I"${}/_templates/wiki-sitemap" <chloe> ; inline

: pages         (         -- sequence  ) wiki-dir get I"${}/pages" directory-files ; inline
: write-sitemap ( content --           ) wiki-dir get I"${}/public/sitemap.html" utf8 set-file-contents ; inline
: page-farkup   ( name    -- farkup    ) wiki-dir get I"${0}/pages/${1}.farkup" utf8 file-contents farkup>xml  ;


! Utilities
: humani-sort-with ( seq quot: ( obj1 -- value ) -- sortedseq )
    [ bi@ humani<=> ] curry sort-with ; inline

: deep-tags-with-names ( tag sequence -- tags-seq )
    [ dup xml? [ body>> ] when ] [ [ assure-name ] map ] bi*
     '[ _ [ swap tag-named? ] with any? ] { } deep-filter-as ;

: generate-id ( body -- id )
    >lower [ letter? not ] split-when harvest "-" join ;

: tag>string ( tag -- string ) 
    { } flatten-as [ blank? ] trim concat ;
    
: titlize ( name -- titlized ) 
    "_- " split harvest [ capitalize ] map! " " join ;

: page-title ( xml -- title )
    "h1" tag-named dup [ tag>string titlize ] when ;

: set-values ( value name -- )
    [ members dup empty? not ]
    [ [ "has " prepend set-value ] [ set-value ] bi ] bi* ;


! Tuples for holding data
TUPLE: backlink name display url ;
: <backlink> ( page -- backlink ) 
    [ name>> ] [ title>> titlize ] [ name>> I"${}.html" ] tri \ backlink boa ;

TUPLE: page name filename article title ;
: <page> ( name filename article title/f -- page ) [ over titlize ] unless* \ page boa ;

TUPLE: header text id ;
C: <header> header

! setting form values
: set-headers   ( page  -- ) name>> get-headers "headers" set-values ;
: set-title     ( page  -- ) title>> "title" set-value ;
: set-article   ( page  -- ) article>> "article" set-value ;

: set-backlinks ( page  -- ) 
    name>> get-backlinks members [ display>> ] humani-sort-with
        "backlinks" set-values ;

: set-sitemap  ( -- ) 
    site-pages get [ title>> first 1string ] collect-by
        [ 2array { "category" "members" } swap H{ } zip-as ] { } assoc>map 
        [ "category" of ] humani-sort-with "sitemap" set-value ;


! Farkup XML manipulation
: find-links ( xml -- xml links ) dup "a" deep-tags-named ;

: save-backlink ( backlink current -- ) 
    [ <backlink> ] dip "href" attr get-backlinks adjoin ;

: save-backlinks ( links -- links )
    dup current-page get '[ _ swap save-backlink  ] each ;

: set-html-links ( links -- )
    [ "href" attr "http" head? ] reject
    [ dup "href" attr I"${}.html" "href" set-attr ] each ;

: handle-outbound-links ( xml -- xml ) 
     find-links save-backlinks set-html-links ;

: find-headers ( xml -- xml headers ) dup HEADINGS deep-tags-with-names ;

: save-header ( tag name -- )
    [ tag>string dup generate-id I"#${}" <header> ] dip get-headers adjoin ;

: save-headers ( xml -- xml )
     dup current-page get name>> '[ _ save-header ] each ;

: set-header-ids ( xml -- )
    [ dup tag>string generate-id "id" set-attr ] each ;

: handle-headers ( xml -- xml )
     find-headers save-headers set-header-ids ;

: collect-page-info ( page -- page )
    dup [ site-pages get push ] [ current-page set ] [ article>> ] tri
        handle-outbound-links handle-headers drop ;


! Wiki Building
: make-page ( chloe -- string )
    page-template [ with-boilerplate ] with-string-writer ;

: wiki-page ( name -- page )
    "." split1 drop 
        dup  I"${}.html" 
        over page-farkup
        dup  page-title 
    <page> collect-page-info ;

: get-wiki-pages ( -- sequence )
    ready-backlinks 
    ready-headers 
    ready-pages 
    pages [ wiki-page ] map ;

: build-page ( page -- string )
    begin-form {
        [ set-title      ]
        [ set-article    ]
        [ set-backlinks  ]
        [ set-headers    ]
    } cleave article-template make-page ;

: build-pages ( pages -- )
    [ [ build-page ] 
      [ output-file  ] bi utf8 set-file-contents ] each ;

: generate-sitemap ( -- )
    begin-form 
    set-sitemap 
    get-sitemap-template 
    make-page 
    write-sitemap ;

: build-statistics ( nanoseconds -- )
    benchmark nanoseconds duration>milliseconds >float
    "Done in %.3fms\n" printf
    site-pages get length I"Created ${} page(s)" print ; inline

! Wiki project generation
: print-and-quit ( message -- )
    print flush 0 exit ;
: print-is-not-dir   ( -- ) "Target must by directory."       print-and-quit ;
: print-is-not-empty ( -- ) "Target directory must be empty." print-and-quit ;

: copy-template ( dir formatter -- )
    [ "vocab:snarl/_template" ] 2dip bi@ copy-file ; inline

: validate-dir ( dir -- )
    dup { [ file-exists? ] [               directory? not ] } 1&& [ print-is-not-dir   ] when
    dup { [ file-exists? ] [ directory-entries empty? not ] } 1&& [ print-is-not-empty ] when
    dup file-exists? [ drop ] [ make-directories ] if ;

: copy-files ( dir -- )
    dup dup validate-dir
    [ I"${}/public/styles.css"           ] 
    [ I"${}/_templates/wiki-article.xml" ]  
    [ I"${}/_templates/wiki-page.xml"    ]  
    [ I"${}/_templates/wiki-sitemap.xml" ]
        [ copy-template ] quad-curry@ quad
    "/public/syntax.css" append "vocab:xmode/code2html/stylesheet.css" swap copy-file ;

: create-welcome-pages ( dir -- )
    I"${}/pages" dup make-directories
        [ "/index.farkup" append index       swap utf8 set-file-contents ]
        [ "/snarl.farkup" append about-snarl swap utf8 set-file-contents ] bi ;
PRIVATE>

! Wiki construction words
: new-wiki ( dir -- )
    [ copy-files ]
    [ create-welcome-pages ] bi 
    "Wiki created!" print ;

: build-wiki ( dir -- )
    [ wiki-dir set 
      clear-output-dir
      get-wiki-pages
      build-pages
      generate-sitemap ] build-statistics ;


! CLI interface
<PRIVATE
: print-help ( -- )
[[ Usage: snarl [command] [dir]

Command:
      build DIR        compiles a wiki to html file
        new DIR        creates a new wiki in the current dir

    help, --help, -h   shows this help
]] print-and-quit ;

: handle-command ( args -- )
    dup first [ CHAR: - = ] trim-head {
        { "build"   [ second   build-wiki ] }
        { "new"     [ second     new-wiki ] }
        { "help"    [  drop    print-help ] }
        { "h"       [  drop    print-help ] }
        [ 2drop print-help ]
    } case ;

: usage ( x -- )
    "Usage: snarl ${} DIR\n" interpolate ;

: validate ( commands -- command )
    dup length 2 < [ print-help 0 exit ] when ;


: main ( -- )
    command-line get validate {
        { [ dup empty? ]     [ drop print-help ] }
        { [ dup length 2 > ] [ drop print-help ] }
        [ handle-command ]
    } cond ;
PRIVATE>

MAIN: main