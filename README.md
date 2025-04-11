# misakaii - bang dang

```
rne@ misaka % misakaii "https://www.bilibili.com/bangumi/play/ss2592"
[*] Applying season recipe...
[*] Fetching metadata:
    [+] Bangumi 学园孤岛 has 12 episodes
[*] Processing pages:
    [+] Extracting episode 1:
        [=] Requesting video and audio stream...
[====================================================================================================================130.M]
[====================================================================================================================29.6M]
        [=] Muxing video and audio stream...
        [=] Saving 开始.mp4 to dist...
    [+] Extracting episode 2:
        [=] Requesting video and audio stream...
[============================================129.M                                                                   310.M]
```

## About this Branch

This branch contains patches for `libjson`, `libcurl` and `misakaii` to support i386 devices.

Tested with iSH on iOS 18.4, with packages: `gcc`, `g++`, `ocaml`, `ffmpeg-dev` and `curl-dev`.

## Introduction

Bilibili media crawler written in OCaml with minimal dependencies. Aims to be small,
fast and robust with some TUI eye candies.

This media crawler fetches the DASH stream by default. Video (single or multiple partition)
and Bangumi (or episode) are supported at present. Support for HDR, 4(8)K, Dolby Vision/Atmos
and AV1 encoding is experimental.

This is supposed to work on all UNIXs.

## Build (From Source)

### Dependencies

#### Libraries

- `libcurl` from [cURL](https://curl.se/docs/manpage.html);
- `libavcodec` and `libavformat` from the [FFmpeg](https://ffmpeg.org) Project.

#### Make Tools

- `make`, the build system;
- `pkg-config` from [freedesktop.org](https://www.freedesktop.org/wiki/Software/pkg-config/);
- `install` from coreutils (optional).

#### OCaml Environment

- `ocamlopt` or `ocamlc`, the bytecode or native code compiler.

#### C Environment

- `clang` or `gcc`, or any working C compiler that is available via `cc`.

### Binary

Simply clone this project and run `make` will do. The binary is placed in `prog/misakaii`.
To install to your system path, run `make install` with root privilege. Prefix is by default
`/usr/local`.

The `libcurl` and `libav` libraries are all dynamically linked.

To clean up, use `make clean`.

## Usage

### Cookie

This crawler is supposed to be working with cookies. The specific cookie required is `SESSDATA`,
which can be obtained by logging in to the bilibili web client and search in Storage/Cookies.

Save this string to file `$HOME/.misakaii`, in form:

```
SESSDATA=1a651s92%3***********************************************
```

You can also specify the path for this file using `-cookie` option at runtime.

### Craw

```
misakaii <url1> [<url2>] ... -cookie <file> {options}
  -cookie  Specify the file containing the required cookies
  -hdr  Request HDR video stream
  -4k  Request 4K video stream
  -8k  Request 8K video stream
  -dolby  Request Dolby Vision video and Dolby Atmos audio stream
  -av1  Request AV1 encoding instead of HEVC
  -help  Display this list of options
```

You can specify more than one `<url>`s, and some advanced options can also be set.

## Contribution

You are always welcomed to open issues or pull requests.
