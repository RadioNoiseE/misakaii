#include <caml/alloc.h>
#include <caml/mlvalues.h>
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>

#define FF "AV_MUX_FAIL"

CAMLprim value caml_mux(value dest, value video, value audio) {
  AVFormatContext *ivctx = NULL, *iactx = NULL, *omctx = NULL;
  AVStream *vstm = NULL, *astm = NULL;
  AVPacket pkt;
  int ret, fbcode, venc, aenc, ividx, iaidx, ovidx, oaidx;
  ret = fbcode = 0;
  venc = aenc = 1;
  ividx = iaidx = -1;

  ret = avformat_open_input(&ivctx, String_val(video), NULL, NULL);
  if (ret < 0)
    goto of;
  ret = avformat_find_stream_info(ivctx, NULL);
  if (ret < 0)
    goto ff;

  ret = avformat_open_input(&iactx, String_val(audio), NULL, NULL);
  if (ret < 0)
    goto of;
  ret = avformat_find_stream_info(iactx, NULL);
  if (ret < 0)
    goto ff;

  avformat_alloc_output_context2(&omctx, NULL, NULL, String_val(dest));
  if (!omctx)
    goto af;

  for (int i = 0; i < ivctx->nb_streams; i++)
    if (ivctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
      ividx = i;
      vstm = avformat_new_stream(omctx, NULL);
      if (!vstm)
        goto nf;
      ovidx = vstm->index;
      avcodec_parameters_copy(vstm->codecpar, ivctx->streams[i]->codecpar);
    };

  for (int i = 0; i < iactx->nb_streams; i++)
    if (iactx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
      iaidx = i;
      astm = avformat_new_stream(omctx, NULL);
      if (!astm)
        goto nf;
      oaidx = astm->index;
      avcodec_parameters_copy(astm->codecpar, iactx->streams[i]->codecpar);
    };

  if (!(omctx->oformat->flags & AVFMT_NOFILE)) {
    ret = avio_open(&omctx->pb, String_val(dest), AVIO_FLAG_WRITE);
    if (ret < 0)
      goto wf;
  }

  ret = avformat_write_header(omctx, NULL);

  if (ret < 0)
    goto hf;
  while (av_read_frame(ivctx, &pkt) >= 0) {
    if (pkt.stream_index == ividx) {
      pkt.stream_index = ovidx;
      av_packet_rescale_ts(&pkt, ivctx->streams[ividx]->time_base,
                           omctx->streams[ovidx]->time_base);
      ret = av_interleaved_write_frame(omctx, &pkt);
      if (ret < 0)
        goto rf;
    }
    av_packet_unref(&pkt);
  }

  while (av_read_frame(iactx, &pkt) >= 0) {
    if (pkt.stream_index == iaidx) {
      pkt.stream_index = oaidx;
      av_packet_rescale_ts(&pkt, iactx->streams[iaidx]->time_base,
                           omctx->streams[oaidx]->time_base);
      ret = av_interleaved_write_frame(omctx, &pkt);
      if (ret < 0)
        goto rf;
    }
    av_packet_unref(&pkt);
  }

  av_write_trailer(omctx);

  avformat_close_input(&ivctx);
  avformat_close_input(&iactx);
  avformat_free_context(omctx);

  return caml_copy_string(String_val(dest));

of:
  fbcode = fbcode != 0 ? fbcode : 1;
ff:
  fbcode = fbcode != 0 ? fbcode : 2;
af:
  fbcode = fbcode != 0 ? fbcode : 3;
nf:
  fbcode = fbcode != 0 ? fbcode : 4;
wf:
  fbcode = fbcode != 0 ? fbcode : 5;
hf:
  fbcode = fbcode != 0 ? fbcode : 6;
rf:
  fbcode = fbcode != 0 ? fbcode : 7;
fb:
  switch (fbcode) {
  case 1:
    fprintf(stderr, "libav: input stream open failed\n");
    break;
  case 2:
    fprintf(stderr, "libav: input stream get info failed\n");
    break;
  case 3:
    fprintf(stderr, "libav: output stream open failed\n");
    break;
  case 4:
    fprintf(stderr, "libav: output stream new failed\n");
    break;
  case 5:
    fprintf(stderr, "libav: output file open failed\n");
    break;
  case 6:
    fprintf(stderr, "libav: output file header write failed\n");
    break;
  case 7:
    fprintf(stderr, "libav: output package write failed\n");
    break;
  }
  return caml_copy_string(FF);
}
