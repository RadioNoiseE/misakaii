exception UnsupportedTarget
exception EmptyTarget
exception ErroneousTarget

type options = {
    cookie: string;
    hdr: bool;
    fourk: bool;
    eightk: bool;
    dolby: bool;
    avone: bool
  }

let usage_msg = "misakaii <url1> [<url2>] ... -cookie <file> {options}"
let input_urls = ref []
let cookie_file = ref (Sys.getenv "HOME" ^ "/.misakaii")
let opt_hdr = ref false
let opt_fourk = ref false
let opt_eightk = ref false
let opt_dolby = ref false
let opt_avone = ref false

let speclist =
  [("-cookie", Arg.Set_string cookie_file, " Specify the file containing the required cookies");
   ("-hdr", Arg.Set opt_hdr, " Request HDR video stream");
   ("-4k", Arg.Set opt_hdr, " Request 4K video stream");
   ("-8k", Arg.Set opt_eightk, " Request 8K video stream");
   ("-dolby", Arg.Set opt_dolby, " Request Dolby Vision video and Dolby Atmos audio stream");
   ("-av1", Arg.Set opt_avone, " Request AV1 encoding instead of HEVC")]

let anon_fun url =
  input_urls := url::!input_urls

let url_patterns = [
    (Str.regexp {|https?://\(www\.\)?bilibili\.com/\(video/\|festival/[^/?#]+\?[^#]*&?bvid=\)\([AaBb][Vv][^/?#&]+\)|}, "video", 3);
    (Str.regexp {|https?://\(www\.\)?bilibili\.com/bangumi/play/ep\([0-9]+\)|}, "episode", 2);
    (Str.regexp {|https?://\(www\.\)?bilibili\.com/bangumi/play/ss\([0-9]+\)|}, "season", 2);
    (Str.regexp {|https?://\(www\.\)?bilibili\.com/bangumi/media/md\([0-9]+\)|}, "media", 2);
    (Str.regexp {|https?://\(www\.\)?bilibili\.com/v/\([A-Za-z]+/[A-Za-z]+\)|}, "category", 2);
    (Str.regexp {|https?://\(www\.\)?bilibili\.com/watchlater/?\([?#]\|$\)|}, "later", 0);
    (Str.regexp {|https?://\(www\.\)?bilibili\.com/\(medialist/play\|list\)/\(.+\)|}, "playlist", 3);
    (Str.regexp {|https?://space\.bilibili\.com/\([0-9]+\)\(/video\)?/?\([?#]\|$\)|}, "space", 1);
    (Str.regexp {|https?://space\.bilibili\.com/\([0-9]+\)/audio/?\([?#]\|$\)|}, "audio", 1);
    (Str.regexp {|https?://space\.bilibili\.com/\([0-9]+/channel/collectiondetail/?\?sid=[0-9]+\)|}, "collection", 1);
    (Str.regexp {|https?://space\.bilibili\.com/\([0-9]+/channel/seriesdetail/?\?bsid=[0-9]+\)|}, "series", 1);
    (Str.regexp {|https?://space\.bilibili\.com/[0-9]+/favlist/?\?fid=\(www\.\)?bilibili\.com/medialist/detail/ml\([0-9]+\)|}, "favorites", 2)
  ]

let comp_fnval options =
  let base = 16 in
  let hdr = if options.hdr then 64 else 0 in
  let fourk = if options.fourk then 128 else 0 in
  let eightk = if options.eightk then 1024 else 0 in
  let dolby_vision = if options.dolby then 256 else 0 in
  let dolby_atmos = if options.dolby then 512 else 0 in
  let avone = if options.avone then 2048 else 0 in
  base lor hdr lor fourk lor eightk lor dolby_vision lor dolby_atmos lor avone

let comp_url base params =
  base ^ "?" ^ String.concat "&" params

let video_down url vid options =
  let info = "https://api.bilibili.com/x/web-interface/wbi/view" in
  let stream = "https://api.bilibili.com/x/player/wbi/playurl" in
  let avid = Str.regexp {|^\([Aa][Vv]\)|} in
  let bvid = Str.regexp {|^\([Bb][Vv]\)|} in
  let vid = (if Str.string_match avid vid 0 then
               Str.replace_first avid "aid=" vid
             else
               Str.replace_first bvid "bvid=" vid)
  in Printf.printf "[*] Fetching metadata:\n%!";
     let responce = Json.parse (Curl.get "string" (comp_url info [vid]) url options.cookie) |> Json.get_child "data" in
     Printf.printf "    [+] Video %s has %ld partitions\n%!" (responce |> Json.get_child "title" |> Json.as_string) (responce |> Json.get_child "videos" |> Json.as_int);
     let vid = "bvid=" ^ (responce |> Json.get_child "bvid" |> Json.as_string) in
     let pages = responce |> Json.get_child "pages" in
     Printf.printf "[*] Processing pages:\n%!";
     match pages with
     | `Array pager -> List.iter (fun page ->
                           let title = page |> Json.get_child "part" |> Json.as_string in
                           Printf.printf "    [+] Extracting partition %ld:\n%!" (page |> Json.get_child "page" |> Json.as_int);
                           let responce = Json.parse (Curl.get "string" (comp_url stream ["cid=" ^ (Int64.to_string (page |> Json.get_child "cid" |> Json.as_int));
                                                                                          "fnval=" ^ (Int64.to_string (comp_fnval options)); vid]) url options.cookie) in
                           Printf.printf "        [=] Requesting video and audio stream...\n%!";
                           let dash = responce |> Json.get_child "data" |> Json.get_child "dash" in
                           let video = Curl.get (title ^ ".video.mp4") (dash |> Json.get_child "video" |> Json.get_mem 0 |> Json.get_child "base_url" |> Json.as_string) url options.cookie in
                           let audio = Curl.get (title ^ ".audio.m4a") (dash |> Json.get_child "audio" |> Json.get_mem 0 |> Json.get_child "base_url" |> Json.as_string) url options.cookie in
                           Printf.printf "        [=] Muxing video and audio stream...\n%!";
                           let mux = Av.merge (title ^ ".mp4") video audio in
                           Sys.remove video; Sys.remove audio;
                           Printf.printf "        [=] Saving %s to dist...\n%!" mux
                         ) pager
     | _ -> raise ErroneousTarget

let bangumi_down url cid title options =
  let stream = "https://api.bilibili.com/pgc/player/web/playurl" in
  let responce = Json.parse (Curl.get "string" (comp_url stream ["cid=" ^ cid; "fnval=" ^ (Int64.to_string (comp_fnval options))]) url options.cookie) in
  Printf.printf "        [=] Requesting video and audio stream...\n%!";
  let dash = responce |> Json.get_child "result" |> Json.get_child "dash" in
  let video = Curl.get (title ^ ".video.mp4") (dash |> Json.get_child "video" |> Json.get_mem 0 |> Json.get_child "base_url" |> Json.as_string) url options.cookie in
  let audio = Curl.get (title ^ ".audio.m4a") (dash |> Json.get_child "audio" |> Json.get_mem 0 |> Json.get_child "base_url" |> Json.as_string) url options.cookie in
  Printf.printf "        [=] Muxing video and audio stream...\n%!";
  let mux = Av.merge (title ^ ".mp4") video audio in
  Sys.remove video; Sys.remove audio;
  Printf.printf "        [=] Saving %s to dist...\n%!" mux

let episode_down url epid options =
  let info = "https://api.bilibili.com/pgc/view/web/season" in
  Printf.printf "[*] Fetching metadata:\n%!";
  let responce = Json.parse (Curl.get "string" (comp_url info ["ep_id=" ^ epid]) url options.cookie) |> Json.get_child "result" in
  Printf.printf "    [+] Bangumi %s has %ld episodes\n%!" (responce |> Json.get_child "season_title" |> Json.as_string) (responce |> Json.get_child "total" |> Json.as_int);
  let pages = responce |> Json.get_child "episodes" in
  Printf.printf "[*] Processing pages:\n%!";
  match pages with
  | `Array pager -> List.iter (fun episode ->
                        Printf.printf "    [+] Extracting episode %s:\n%!" (episode |> Json.get_child "title" |> Json.as_string); 
                        bangumi_down url (Int64.to_string (episode |> Json.get_child "cid" |> Json.as_int)) (episode |> Json.get_child "long_title" |> Json.as_string) options
                      ) pager
  | _ -> raise ErroneousTarget

let season_down url ssid options =
  let info = "https://api.bilibili.com/pgc/view/web/season" in
  Printf.printf "[*] Fetching metadata:\n%!";
  let responce = Json.parse (Curl.get "string" (comp_url info ["season_id=" ^ ssid]) url options.cookie) |> Json.get_child "result" in
  Printf.printf "    [+] Bangumi %s has %ld episodes\n%!" (responce |> Json.get_child "season_title" |> Json.as_string) (responce |> Json.get_child "total" |> Json.as_int);
  let pages = responce |> Json.get_child "episodes" in
  Printf.printf "[*] Processing pages:\n%!";
  match pages with
  | `Array pager -> List.iter (fun episode ->
                        Printf.printf "    [+] Extracting episode %s:\n%!" (episode |> Json.get_child "title" |> Json.as_string); 
                        bangumi_down url (Int64.to_string (episode |> Json.get_child "cid" |> Json.as_int)) (episode |> Json.get_child "long_title" |> Json.as_string) options
                      ) pager
  | _ -> raise ErroneousTarget

let media_down url mdid options =
  let info = "https://api.bilibili.com/pgc/review/user" in
  let responce = Json.parse (Curl.get "string" (comp_url info ["media_id=" ^ mdid]) url options.cookie) |> Json.get_child "result" in
  season_down url (Int64.to_string (responce |> Json.get_child "media" |> Json.get_child "season_id" |> Json.as_int)) options
;;

let classify_url url =
  let rec match_patterns = function
    | [] -> None
    | (pattern, label, group) :: rest ->
       if Str.string_match pattern url 0 then
         let extracted =
           Printf.printf "[*] Applying %s recipe...\n%!" label;
           if group > 0 then Some (Str.matched_group group url) else None
         in Some (label, extracted);
       else
         match_patterns rest
  in match_patterns url_patterns

let extract_url url options =
  match classify_url url with
  | None -> raise UnsupportedTarget
  | Some ("video", Some id) -> video_down url id options
  | Some ("episode", Some id) -> episode_down url id options
  | Some ("season", Some id) -> season_down url id options
  | Some ("media", Some id) -> media_down url id options
  | Some (label, Some id) -> raise UnsupportedTarget
  | Some (label, None) -> raise UnsupportedTarget

let target_handle url options =
  let media_down url = extract_url url options in
  match url with
  | [] -> raise EmptyTarget
  | urls -> List.iter media_down urls

let read_cookie file =
  let file = open_in file in
  try
    let cookie = input_line file in
    close_in file; cookie
  with except ->
    close_in_noerr file;
    raise except

let () =
  Arg.parse speclist anon_fun usage_msg;
  target_handle !input_urls { cookie = (read_cookie !cookie_file);
                              hdr = !opt_hdr;
                              fourk = !opt_fourk;
                              eightk = !opt_eightk;
                              dolby = !opt_dolby;
                              avone = !opt_avone }
