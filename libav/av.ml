external mux: string -> string -> string -> string = "caml_mux"

exception MediaError

let merge dest video audio =
  let responce = mux dest ("file:" ^ video) ("file:" ^ audio) in
  if responce <> "AV_MUX_FAIL" then responce else raise MediaError
