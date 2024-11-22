external fetch: string -> string -> string -> string -> string = "caml_fetch"

exception RequestError

let get dest url referer cookie =
  let responce = fetch dest url referer cookie in
  if responce <> "CURL_FETCH_FAIL" then responce else raise RequestError
