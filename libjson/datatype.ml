type stt = [
  | `Integer of int
  | `Float of float
  | `Bool of bool
  | `String of string
  | `Array of stt list
  | `Object of (string * stt) list
  | `Null
  ]
