! Copyright (C) 2007 Chris Double.
! See http://factorcode.org/license.txt for BSD license.
!
USING: kernel tools.test peg peg.ebnf ;
IN: temporary

{ T{ ebnf-non-terminal f "abc" } } [
  "abc" 'non-terminal' parse parse-result-ast 
] unit-test

{ T{ ebnf-terminal f "55" } } [
  "'55'" 'terminal' parse parse-result-ast 
] unit-test

{
  T{ ebnf-rule f 
     "digit"
     V{ 
       T{ ebnf-choice f
          V{ T{ ebnf-terminal f "1" } T{ ebnf-terminal f "2" } }
       }
       f
     }
  } 
} [
  "digit = '1' | '2'" 'rule' parse parse-result-ast
] unit-test

{
  T{ ebnf-rule f 
     "digit" 
     V{
       T{ ebnf-sequence f
          V{ T{ ebnf-terminal f "1" } T{ ebnf-terminal f "2" } }
       }
       f
     }
  }   
} [
  "digit = '1' '2'" 'rule' parse parse-result-ast
] unit-test