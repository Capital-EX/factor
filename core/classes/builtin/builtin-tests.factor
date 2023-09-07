USING: accessors classes classes.algebra classes.algebra.private
kernel math memory sequences tools.test words ;
IN: classes.builtin.tests

{ f } [
    [ word? ] instances
    [
        [ name>> "f?" = ]
        [ vocabulary>> "syntax" = ] bi and
    ] any?
] unit-test


{ f f } [
    10 not{ fixnum } instance?
    10 not{ fixnum } flatten-class <anonymous-union> instance?
] unit-test