! Copyright (C) 2023 CapitalEx.
! See https://factorcode.org/license.txt for BSD license.
USING: help.markup help.syntax kernel strings ;
IN: snarl

HELP: new-wiki
{ $values
    dir: string
}
{ $description
    Consturcts a new wiki at { $snippet "dir" } .
} ;

HELP: build-wiki
{ $values
    dir: string
}
{ $description 
    When given a directory as a string, Snarl will convert { $snippet ".farkup" } 
    files into { $snippet ".html" } files using the Chloe templates provided.


    For generating a new wiki, see \ new-wiki .
} ;

ARTICLE: "snarl" "Snarl"
Snarl " (" { $vocab-link "snarl" } ") " is a flat-file wiki generator. It's markup language is 
{ $link "farkup" } , and templates are written in xml using { $link "html.templates.chloe" } . It is not a feature rich
static site generator however. Additionally, Snarl imposes no hard requirments on your 
articles. However, it will use the { $snippet "= First Heading =" } as the article 
title instead of the filename.

Snarl does not provide pluggins, themeing (aside from CSS), markup macros,
data injection, " inline " factor inside templates and markup. The only 
data aviable to inject into templates are the following:

{ $list 
    { "Page Title as " { $snippet "title" } }
    { "Flat listing of headers as " { $snippet "headers" } }
    { "Direct backlinks to current article as " { $snippet "backlinks" } }
    { "Alphabetical collection of pages as " { $snippet "sitemap" } } }
$nl


{ $heading "Getting started" }
You can generate a new wiki using \ new-wiki  and build an existing wiki using
\ build-wiki . You can combine these into the following one-liner:
{ $code
    "\"~/your-wiki\" [ new-wiki ] [ build-wiki ] bi"
} $nl

Finally, example templates are provided in { $snippet "snarl/_template" } .

{ $see-also "snarl.cli" \ new-wiki \ build-wiki }
;

ABOUT: "snarl"
