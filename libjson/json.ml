open Lexing
open Printf

let print_position outx lexbuf =
  let pos = lexbuf.lex_curr_p in
  fprintf outx "%s:%d:%d" pos.pos_fname pos.pos_lnum (pos.pos_cnum - pos.pos_bol +1)

let parse_with_error lexbuf =
  try Parser.decl Lexer.read lexbuf with
  | Lexer.Syntax_error msg ->
     fprintf stderr "%a: %s\n" print_position lexbuf msg;
     `Null
  | Parsing.Parse_error ->
     fprintf stderr "%a: syntax error\n" print_position lexbuf;
     exit (-1)

let rec parse_json lexbuf =
  parse_with_error lexbuf

let parse (json: string) =
  let lexbuf = Lexing.from_string json in
  parse_json lexbuf

let typeof = function
  | `Integer _ -> "int"
  | `Float _ -> "float"
  | `Bool _ -> "bool"
  | `String _ -> "string"
  | `Array _ -> "array"
  | `Object _ -> "object"

exception Not_numeric_value
exception Not_stringable_value
exception Not_array
exception Empty_array
exception Not_object
exception Empty_object

let as_int nmr =
  match nmr with
  | `Integer nmr -> nmr
  | _ -> raise Not_numeric_value

let as_float nmr =
  match nmr with
  | `Float nmr -> nmr
  | _ -> raise Not_numeric_value

let as_string str =
  match str with
  | `String str -> str
  | _ -> raise Not_stringable_value

let rec get_mem (n: int) a =
  match a with
  | `Array ([]) -> raise Empty_array
  | `Array (a) -> List.nth a n
  | _ -> raise Not_array

let rec get_child (k: string) o =
  match o with
  | `Object ([]) -> raise Empty_object
  | `Object (o) -> List.assoc k o
  | _ -> raise Not_object
