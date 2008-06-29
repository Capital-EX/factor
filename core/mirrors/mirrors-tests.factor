USING: mirrors tools.test assocs kernel arrays accessors words
namespaces math slots ;
IN: mirrors.tests

TUPLE: foo bar baz ;

C: <foo> foo

[ { "delegate" "bar" "baz" } ] [ 1 2 <foo> <mirror> keys ] unit-test

[ 1 t ] [ "bar" 1 2 <foo> <mirror> at* ] unit-test

[ f f ] [ "hi" 1 2 <foo> <mirror> at* ] unit-test

[ 3 ] [
    3 "baz" 1 2 <foo> [ <mirror> set-at ] keep foo-baz
] unit-test

[ 3 "hi" 1 2 <foo> <mirror> set-at ] must-fail

[ 3 "numerator" 1/2 <mirror> set-at ] must-fail

[ "foo" ] [
    gensym [
        <mirror> [
            "foo" "name" set
        ] bind
    ] [ name>> ] bi
] unit-test

[ gensym <mirror> [ "compiled" off ] bind ] must-fail

TUPLE: declared-mirror-test
{ "a" integer initial: 0 } ;

[ 5 ] [
    3 declared-mirror-test boa <mirror> [
        5 "a" set
        "a" get
    ] bind
] unit-test

[ 3 declared-mirror-test boa <mirror> [ t "a" set ] bind ] must-fail

TUPLE: color
{ "red" integer }
{ "green" integer }
{ "blue" integer } ;

[ T{ color f 0 0 0 } ] [
    1 2 3 color boa [ <mirror> clear-assoc ] keep
] unit-test
