# Makefile to build a shared object and/or a binary executable and/or unit test executable from C code
# Include this file in your own Makefile
# Places object, dependency files and output files in $(BUILDDIR)
# $(BUILDDIR) created if it does not exist
# $(INCLUDE_PATH) to specify header file search path; $(LIB_PATH) to specify library search path
# e.g. INCLUDE_PATH = -I/usr/local/include -I/some/path/include
#      LIB_PATH = -L/usr/local/lib -L/some/path/lib
# Compiles using full warnings and rebuilds when header files are changed
# `make clean` will remove all output from $(BUILDDIR)
# `make tests` will run the unit test binary
# `make install` will install the bin and lib targets in /usr/local

ifeq ($(BUILDDIR),)
	BUILDDIR = build
endif

UNAME = $(shell uname)

LIB1_OUT = $(addprefix $(BUILDDIR)/, $(LIB1))
LIB1_OBJS = $(LIB1_SRCS:%.c=$(addprefix $(BUILDDIR)/, %.o))
LIB1_BLOB_OBJS = $(LIB1_BLOBS:%=$(addprefix $(BUILDDIR)/, %.o))
LIB1_DEPS = $(LIB1_OBJS:%.o=%.d)
LIB_PATH += $(BUILDDIR)

BIN1_OUT = $(addprefix $(BUILDDIR)/, $(BIN1))
BIN1_OBJS = $(BIN1_SRCS:%.c=$(addprefix $(BUILDDIR)/, %.o))
BIN1_BLOB_OBJS = $(BIN1_BLOBS:%=$(addprefix $(BUILDDIR)/, %.o))
BIN1_DEPS = $(BIN1_OBJS:%.o=%.d)

TST1_OUT = $(addprefix $(BUILDDIR)/, $(TST1))
TST1_OBJS = $(TST1_SRCS:%.c=$(addprefix $(BUILDDIR)/, %.o))
TST1_DEPS = $(TST1_OBJS:%.o=%.d)

WASM1_OUT = $(addprefix $(BUILDDIR)/, $(WASM1))
WASM_CORE = $(basename $(WASM1))
WASM1_JS = $(addprefix $(BUILDDIR)/, $(WASM_CORE).js)
WASM1_WASM = $(addprefix $(BUILDDIR)/, $(WASM_CORE).wasm)
WASM1_DATA = $(addprefix $(BUILDDIR)/, $(WASM_CORE).data)
WASM1_HTML = $(addprefix $(BUILDDIR)/, $(WASM_CORE).html)
WASM_CC = emcc
ifeq ($(WASM1_USE_SDL2),Y)
	WASM_EXTRAS = -s USE_SDL=2 -s USE_SDL_IMAGE=2 -s SDL2_IMAGE_FORMATS='["png"]' -s USE_SDL_TTF=2
endif
ifneq ($(WASM1_ASSETS),)
	WASM1_ASSETS_ARGS = --preload-file $(WASM1_ASSETS)
endif

define LOADER_S
    .global _@SYM@_start
_@SYM@_start:
    .incbin "@FILE@"

    .global _@SYM@_end
_@SYM@_end:
    .byte 0

    .global _@SYM@_size
_@SYM@_size:
    .int _@SYM@_end - _@SYM@_start
endef
export LOADER_S

CFLAGS = -g -I. $(INCLUDE_PATH) -Wall -Wextra
#LDFLAGS = -linker_flags

$(BUILDDIR)/%.o : %.c
	$(COMPILE.c) -MMD -fpic -o $@ $<

all : directories $(LIB1_OUT) $(BIN1_OUT) $(TST1_OUT) $(WASM1_OUT)

$(BIN1_BLOB_OBJS) $(LIB1_BLOB_OBJS) : $(BIN1_BLOBS) $(LIB1_BLOBS)
	echo "$$LOADER_S" | sed -e "s/@SYM@/$(subst .,_,$^)/g" -e "s/@FILE@/$^/" | $(CC) -x assembler-with-cpp -o $@ - -c

$(LIB1_OUT) : $(LIB1_OUT).so $(LIB1_OUT).a

$(LIB1_OUT).so : $(LIB1_OBJS) $(LIB1_BLOB_OBJS)
	$(LINK.c) $^ -shared -o $@

$(LIB1_OUT).a : $(LIB1_OBJS) $(LIB1_BLOB_OBJS)
ifeq ($(UNAME),Linux)
	ar rcs $@ $^
else
	libtool $^ -o $@
endif

$(BIN1_OUT) : $(BIN1_OBJS) $(BIN1_BLOB_OBJS)
	$(LINK.c) $^ -L$(LIB_PATH) $(LIBS) -o $@

$(TST1_OUT) : $(TST1_OBJS)
	$(LINK.c) $^ -L$(LIB_PATH) $(LIBS) -o $@

$(WASM1_OUT) : $(WASM1_SRCS)
	$(WASM_CC) $^ $(WASM_EXTRAS) $(WASM1_ASSETS_ARGS) -o $@

-include $(LIB1_DEPS) $(BIN1_DEPS) $(TST1_DEPS)

ifeq ($(PREFIX),)
	PREFIX = /usr/local
endif

.PHONY: directories clean test install
directories :
	@mkdir -p $(BUILDDIR)

clean :
	rm -f $(LIB1_OBJS) $(LIB1_BLOB_OBJS) $(LIB1_DEPS) $(LIB1_OUT).so $(LIB1_OUT).a \
		  $(BIN1_OBJS) $(BIN1_BLOB_OBJS) $(BIN1_DEPS) $(BIN1_OUT) \
		  $(TST1_OBJS) $(TST1_DEPS) $(TST1_OUT) \
		  $(WASM1_HTML) $(WASM1_JS) $(WASM1_DATA) $(WASM1_WASM)

tests :
	@LD_LIBRARY_PATH=$(LIB_PATH) DYLD_LIBRARY_PATH=$(LIB_PATH) $(TST1_OUT)

INSTALL_H = $(HEADERS:%.h=$(addprefix $(DESTDIR)$(PREFIX)/include/, %.h))
INSTALL_L = $(addprefix $(DESTDIR)$(PREFIX)/lib/, $(LIB1))
INSTALL_LA = $(addprefix $(DESTDIR)$(PREFIX)/lib/, $(LIB1).a)
INSTALL_LS = $(addprefix $(DESTDIR)$(PREFIX)/lib/, $(LIB1).so)
INSTALL_B = $(addprefix $(DESTDIR)$(PREFIX)/bin/, $(BIN1))

install : $(INSTALL_H) $(INSTALL_L) $(INSTALL_B)

$(INSTALL_H) : $(HEADERS)
	install -d $(DESTDIR)$(PREFIX)/include
	install -m 644 $^ $(DESTDIR)$(PREFIX)/include

$(INSTALL_L) : $(INSTALL_LA) $(INSTALL_LS)

$(INSTALL_LA) : $(LIB1_OUT).a
	install -d $(DESTDIR)$(PREFIX)/lib
	install -m 644 $(LIB1_OUT).a $(DESTDIR)$(PREFIX)/lib

$(INSTALL_LS) : $(LIB1_OUT).so
	install -d $(DESTDIR)$(PREFIX)/lib
	install -m 644 $(LIB1_OUT).so $(DESTDIR)$(PREFIX)/lib
ifeq ($(UNAME),Linux)
	@echo "*** Library installation complete. You may need to run 'sudo ldconfig' ***"
endif

$(INSTALL_B) : $(BIN1_OUT)
	install -d $(DESTDIR)$(PREFIX)/bin
	install -m 755 $(BIN1_OUT) $(DESTDIR)$(PREFIX)/bin
