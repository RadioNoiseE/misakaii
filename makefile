ifndef ECHO
TOTAL := $(shell ${MAKE} ${MAKECMDGOALS} --dry-run ECHO="ECHO" | grep -c "ECHO")
COUNT  = $(eval STEP := $(shell expr 0${STEP} + 1)) $(STEP)
ECHO   = printf "[%3d%%] " `expr ${COUNT} '*' 100 / ${TOTAL}`; echo
endif

RELEASE   := compile
WORKSPACE := $(shell pwd)

PREFIX := /usr/local

OCAML := ocamlopt

CFLAGS :=                                                   \
	-Wno-pointer-type-mismatch                          \
	$(shell pkg-config --cflags libavformat libavcodec) \
	$(shell curl-config --cflags)
CLIBS  :=                                                 \
	$(shell pkg-config --libs libavformat libavcodec) \
	$(shell curl-config --libs)

default: misakaii

.SILENT:
.PHONY: libjson libcurl libav extractor misakaii clean install

$(RELEASE):
	mkdir -p $(RELEASE)

libjson: libjson/datatype.ml libjson/json.ml libjson/lexer.mll libjson/parser.mly
	$(ECHO) compiling libjson
	cp libjson/datatype.ml $(RELEASE)
	cp libjson/json.ml $(RELEASE)
	cp libjson/lexer.mll $(RELEASE)
	cp libjson/parser.mly $(RELEASE)
	cd $(RELEASE)            && \
	ocamllex lexer.mll       && \
	ocamlyacc parser.mly     && \
	$(OCAML) -c datatype.ml  && \
	$(OCAML) -c parser.mli   && \
	$(OCAML) -c lexer.ml     && \
	$(OCAML) -c parser.ml    && \
	$(OCAML) -c json.ml      && \
	cd $(WORKSPACE)

libcurl: libcurl/curl.ml libcurl/libcurl.c
	$(ECHO) compiling libcurl
	cp libcurl/curl.ml $(RELEASE)
	cp libcurl/libcurl.c $(RELEASE)
	cd $(RELEASE)                                && \
	cc -c -I`ocamlc -where` $(CFLAGS) libcurl.c  && \
	$(OCAML) -c curl.ml                          && \
	cd $(WORKSPACE)

libav: libav/av.ml libav/libav.c
	$(ECHO) compiling libav
	cp libav/av.ml $(RELEASE)
	cp libav/libav.c $(RELEASE)
	cd $(RELEASE)                              && \
	cc -c -I`ocamlc -where` $(CFLAGS) libav.c  && \
	$(OCAML) -c av.ml                          && \
	cd $(WORKSPACE)

extractor: misaka/misaka.ml
	$(ECHO) compiling extractor
	cp misaka/misaka.ml $(RELEASE)
	cd $(RELEASE)                  && \
	$(OCAML) -c misaka.ml -I +str  && \
	cd $(WORKSPACE)

misakaii: $(RELEASE) libjson libcurl libav extractor
	$(ECHO) linking executable
	cd $(RELEASE)                       && \
	ocamlopt -o misakaii str.cmxa -I +str  \
		lexer.cmx parser.cmx json.cmx  \
		curl.cmx libcurl.o             \
		av.cmx libav.o                 \
		misaka.cmx                     \
		-ccopt "$(CFLAGS)"             \
		-cclib "$(CLIBS)"           && \
	cd $(WORKSPACE)

clean: $(RELEASE)
	rm -r $(RELEASE)

install: $(RELEASE)/misakaii
	install -s -m 755 $(RELEASE)/misakaii $(PREFIX)/bin/misakaii
