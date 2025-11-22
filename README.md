## Introduction

This is a standalone bilibili media crawler written in OCaml with a
minimal footprint, implemented with robustness and correctness in
mind.

By default, the crawler fetches DASH streams. It currently supports
standard videos (including multi-part ones) and Bangumi episodes, with
full support for HDR, 4K/8K, Dolby Vision/Atoms, and AV1 encoding.

It is intended to work on all UNIXs. It may also work on Windows,
while this is untested and thus not guaranteed.

> [!NOTE]
> Branch `i386-patch` contains patches for `libjson`, `libcurl` and
> `misakaii` to support i386 devices. Tested with iSH on iOS, with
> packages: `gcc`, `g++`, `ocaml`, `ffmpeg-dev` and `curl-dev`.

## Install

To compile, build and install misakaii from source, you will need the
following build-time dependencies:

- `make`, the build system;
- `pkg-config`, either from [freedesktop.org](https://www.freedesktop.org/wiki/Software/pkg-config/) or [pkgconf](https://github.com/pkgconf/pkgconf);
- `install`, provided by coreutils (optional);
- `ocamlopt`, OCaml native code compiler;
- `cc`, any working C compiler.

Several libraries are required at runtime:

- `libcurl`, from [cURL](https://curl.se/docs/manpage.html);
- `libavcodec` and `libavformat`, from the [FFmpeg](https://ffmpeg.org) Project.

Run `make install` with root privilege will install the executable in
`/usr/local/bin`. To clean up, use `make clean`.

## Usage

This crawler is supposed to be working with cookies. The specific
cookie required is `SESSDATA`, which can be obtained by logging in to
the bilibili web client and search in Storage/Cookies.

Save this string to file `$HOME/.misakaii`, in form `name=value` (as
described in cURL's [documentation](https://curl.se/docs/http-cookies.html) about HTTP cookies).

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

## Contribution

You are always welcomed to open issues or pull requests.
