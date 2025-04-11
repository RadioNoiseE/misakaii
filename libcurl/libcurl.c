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

static char *opt_size(curl_off_t bytes, char *size) {
#define KILOBYTE 1024L
#define MEGABYTE (1024L * KILOBYTE)
#define GIGABYTE (1024L * MEGABYTE)
#define TERABYTE (1024L * GIGABYTE)
#define PETABYTE (1024L * TERABYTE)
  if (bytes < 100000L)
    snprintf(size, 6, "%5lld", bytes);
  else if (bytes < 1000L * KILOBYTE)
    snprintf(size, 6, "%3lld.k", bytes / KILOBYTE);
  else if (bytes < 10000L * KILOBYTE)
    snprintf(size, 6, "%4lldk", bytes / KILOBYTE);
  else if (bytes < 100L * MEGABYTE)
    snprintf(size, 6, "%2lld.%0lldM", bytes / MEGABYTE,
             (bytes % MEGABYTE) / (MEGABYTE / 10L));
  else if (bytes < 1000L * MEGABYTE)
    snprintf(size, 6, "%3lld.M", bytes / MEGABYTE);
  else if (bytes < 10000L * MEGABYTE)
    snprintf(size, 6, "%4lldM", bytes / MEGABYTE);
  else if (bytes < 100L * GIGABYTE)
    snprintf(size, 6, "%2lld.%0lldG", bytes / GIGABYTE,
             (bytes % GIGABYTE) / (GIGABYTE / 10L));
  else if (bytes < 1000L * GIGABYTE)
    snprintf(size, 6, "%3lld.G", bytes / GIGABYTE);
  else if (bytes < 10000L * GIGABYTE)
    snprintf(size, 6, "%4lldG", bytes / GIGABYTE);
  else if (bytes < 10000L * TERABYTE)
    snprintf(size, 6, "%4lldT", bytes / TERABYTE);
  else
    snprintf(size, 6, "%4lldP", bytes / PETABYTE);
  return size;
}

static size_t fetch_prog(void *clientp, curl_off_t dltotal, curl_off_t dlnow,
                         curl_off_t ultotal, curl_off_t ulnow) {
  if (dltotal <= 0)
    return 0;
  int *wtotal = clientp;
  double dlfrac = (double)dlnow / (double)dltotal;
  int witer;
  printf("\r[");
  witer += 1;
  int wnow = round(dlfrac * *wtotal) - 5;
  while (witer++ < wnow)
    printf("=");
  char snow[6], stotal[6];
  if (witer + 8 < *wtotal) {
    printf("%s", opt_size(dlnow, snow));
    witer += 5;
  }
  int wspc = *wtotal - 4;
  while (witer++ < wspc)
    printf(" ");
  printf("%s]", opt_size(dltotal, stotal));
  fflush(stdout);
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

  ioctl(STDOUT_FILENO, TIOCGWINSZ, &term);
  twidth = term.ws_col;

  curl_easy_setopt(flag, CURLOPT_URL, String_val(url));
  curl_easy_setopt(flag, CURLOPT_USERAGENT, UA);
  curl_easy_setopt(flag, CURLOPT_COOKIE, String_val(cookie));
  curl_easy_setopt(flag, CURLOPT_REFERER, String_val(referer));
  if (!exec) {
    curl_easy_setopt(flag, CURLOPT_NOPROGRESS, 0L);
    curl_easy_setopt(flag, CURLOPT_XFERINFODATA, &twidth);
    curl_easy_setopt(flag, CURLOPT_XFERINFOFUNCTION, fetch_prog);
  }
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
