#include <caml/alloc.h>
#include <caml/mlvalues.h>
#include <curl/curl.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#define FF "CURL_FETCH_FAIL"
#define UA                                                                     \
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "                           \
  "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"

typedef struct {
  char *data;
  size_t size;
} memory;

static size_t write_string(void *cnts, size_t size, size_t nmemb, void *userp) {
  size_t rsize = size * nmemb;
  memory *mem = (memory *)userp;
  char *ptr = realloc(mem->data, mem->size + rsize + 1);
  if (!ptr)
    goto fb;
  mem->data = ptr;
  memcpy(&(mem->data[mem->size]), cnts, rsize);
  mem->size += rsize;
  mem->data[mem->size] = 0;
  return rsize;
fb:
  fprintf(stderr, "libcurl: realloc failed\n");
  return 0;
}

static size_t write_file(void *cnts, size_t size, size_t nmemb, FILE *stream) {
  size_t wsize = fwrite(cnts, size, nmemb, stream);
  return wsize;
}

static size_t fetch_prog(void *clientp, curl_off_t dltotal, curl_off_t dlnow,
                         curl_off_t ultotal, curl_off_t ulnow) {
  if (dltotal <= 0)
    return 0;
  return CURLE_OK;
}

CAMLprim value caml_fetch(value dest, value url, value referer, value cookie) {
  FILE *file;
  CURL *flag;
  memory chunk;
  struct winsize term;
  int exec, fbcode, twidth;
  exec = fbcode = 0;

  if (!strcmp(String_val(dest), "string"))
    exec = 1;
  flag = curl_easy_init();
  if (!flag)
    goto nf;
  if (exec) {
    chunk.data = malloc(1);
    if (!chunk.data)
      goto mf;
    chunk.size = 0;
  } else
    file = fopen(String_val(dest), "wb");

  curl_easy_setopt(flag, CURLOPT_URL, String_val(url));
  curl_easy_setopt(flag, CURLOPT_USERAGENT, UA);
  curl_easy_setopt(flag, CURLOPT_COOKIE, String_val(cookie));
  curl_easy_setopt(flag, CURLOPT_REFERER, String_val(referer));
  curl_easy_setopt(flag, CURLOPT_WRITEFUNCTION,
                   exec ? write_string : write_file);
  curl_easy_setopt(flag, CURLOPT_WRITEDATA, exec ? (void *)&chunk : file);

  CURLcode res = curl_easy_perform(flag);
  if (res != CURLE_OK)
    goto cf;

  curl_easy_cleanup(flag);

  if (exec) {
    char string[chunk.size];
    strcpy(string, chunk.data);
    free(chunk.data);
    return caml_copy_string(string);
  } else {
    printf("\n");
    fclose(file);
    return caml_copy_string(String_val(dest));
  }

nf:
  fbcode = fbcode != 0 ? fbcode : 1;
mf:
  fbcode = fbcode != 0 ? fbcode : 2;
cf:
  fbcode = fbcode != 0 ? fbcode : 3;
fb:
  switch (fbcode) {
  case 1:
    fprintf(stderr, "libcurl: init failed\n");
    break;
  case 2:
    fprintf(stderr, "libcurl: malloc failed\n");
    break;
  case 3:
    fprintf(stderr, "libcurl: %s\n", curl_easy_strerror(res));
    break;
  }
  return caml_copy_string(FF);
}
