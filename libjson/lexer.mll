{
  open Lexing
  open Parser

  exception SyntaxError of string

  let next_line lexbuf =
    let pos = lexbuf.lex_curr_p in
    lexbuf.lex_curr_p <- {
      pos with pos_bol = lexbuf.lex_curr_pos;
               pos_lnum = pos.pos_lnum + 1
      }

  let encode escape =
    Char.chr (int_of_string ("0x" ^ String.sub escape 2 4))
}

let digit = ['0'-'9']
let alpha = ['A'-'F'] | ['a'-'f']
let hex = digit | alpha
let unicode = '\\' 'u' hex hex hex hex
let frac = '.' digit*
let exp = ['e' 'E'] ['-' '+']? digit+
let int = '-'? digit+
let float = '-'? digit* frac? exp?
let white = [' ' '\t']+
let newline = '\r' | '\n' | "\r\n"

rule read =
  parse
  | white { read lexbuf }
  | newline { next_line lexbuf; read lexbuf }
  | int { INT (int_of_string (Lexing.lexeme lexbuf)) }
  | float { FLOAT (float_of_string (Lexing.lexeme lexbuf)) }
  | "true" { TRUE }
  | "false" { FALSE }
  | "null" { NULL }
  | '\"' { read_string (Buffer.create 17) lexbuf }
  | ':' { COLON }
  | ',' { COMMA }
  | '[' { LEFT_BRACK }
  | ']' { RIGHT_BRACK }
  | '{' { LEFT_BRACE }
  | '}' { RIGHT_BRACE }
  | _ { raise (SyntaxError ("Unexpected char: " ^ Lexing.lexeme lexbuf)) }
  | eof { EOF }
and read_string buf =
  parse
  | '\"' { STRING (Buffer.contents buf) }
  | '\\' '/' { Buffer.add_char buf '/'; read_string buf lexbuf }
  | '\\' '\\' { Buffer.add_char buf '\\'; read_string buf lexbuf }
  | '\\' 'b' { Buffer.add_char buf '\b'; read_string buf lexbuf }
  | '\\' 'f' { Buffer.add_char buf '\012'; read_string buf lexbuf }
  | '\\' 'r' { Buffer.add_char buf '\r'; read_string buf lexbuf }
  | '\\' 'n' { Buffer.add_char buf '\n'; read_string buf lexbuf }
  | '\\' 't' { Buffer.add_char buf '\t'; read_string buf lexbuf }
  | unicode { Buffer.add_char buf (encode (Lexing.lexeme lexbuf)); read_string buf lexbuf }
  | [^ '\"' '\\']+ { Buffer.add_string buf (Lexing.lexeme lexbuf); read_string buf lexbuf }
  | _ { raise (SyntaxError ("Illegal string character: " ^ Lexing.lexeme lexbuf)) }
  | eof { raise (SyntaxError ("String terminated by EOF")) }
