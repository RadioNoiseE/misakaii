%token <int> INT
%token <float> FLOAT
%token TRUE
%token FALSE
%token <string> STRING
%token COLON
%token COMMA
%token LEFT_BRACK
%token RIGHT_BRACK
%token LEFT_BRACE
%token RIGHT_BRACE
%token EOF
%token NULL

%type <Datatype.stt> decl
%start decl
%{ open Datatype %}
%%

decl:
  | expr EOF { $1 }
  ;

expr:
  | NULL { `Null }
  | INT { `Integer($1) }
  | FLOAT { `Float($1) }
  | TRUE { `Bool(true) }
  | FALSE { `Bool(false) }
  | STRING { `String($1) }
  | LEFT_BRACK array_fields RIGHT_BRACK { `Array($2) }
  | LEFT_BRACE object_fields RIGHT_BRACE { `Object($2) }
  ;

array_fields:
  | rev_array_fields { List.rev($1) }
  ;

rev_array_fields:
  | /* Null */ { [] }
  | rev_array_fields COMMA expr { $3 :: $1 }
  | expr { [$1] }
  ;

object_fields:
  | rev_object_fields { List.rev($1) }
  ;

rev_object_fields:
  | /* Null */ { [] }
  | rev_object_fields COMMA STRING COLON expr { ($3, $5) :: $1 }
  | STRING COLON expr { [($1, $3)] }
  ;
