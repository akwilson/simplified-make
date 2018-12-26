# Simplified Make
A shared makefile to provide a few basic build options for your C projects. Include it in your C project's makefile and it will provide,
```
$ make                      # build the project; targets go to $(BUILDDIR) directory.
$ make clean                # delete all build output
$ make tests                # run unit tests
$ make install              # copy targets to system directories
$ make DESTDIR=/tmp install # copy targets to /tmp as a staging area
```
Simplified make uses the C compiler to generate dependency files (placed in the build output directory) which it uses to rebuild any necessary targets when header files are changed. It is designed for Linux and MacOS.
## How to...
```make
BIN1 = myapp
BIN1_SRCS = my_app.c more_code.c even_more_code.c

include simplified.mk
```
Builds an executable binary called `myapp`. All build targets sent to the `./build` directory which is created if it does not exist. `make clean` will delete all of the targets in `./build`; `make install` will copy `myapp` to `/usr/local/bin`; `make tests` won't do anything in this example.
```make
LIB1 = libmylib.so
LIB1_SRCS = my_app.c more_code.c even_more_code.c
HEADERS = mylib.h

TST1 = mytests
TST1_SRCS = mytests.c

BUILDDIR = ../build
LIB_PATH = ../build
LIBS = -lmylib

include simplified.mk
```
Builds a shared object called `libmylib.so`. All build targets sent to the `../build` directory which is created if it does not exist. `make clean` will delete all of the targets in `../build`; `make install` will copy `libmylib.so` to `/usr/local/lib` and `mylib.h` to `/usr/local/include`.

`mytests` will be created as a binary executable but it will not be installed. It will link to `libmylib.so` and can be executed with `make tests`. The `LD_LIBRARY_PATH` will include the `../build` directory so the dependency will be picked up locally.
## Examples
See https://github.com/akwilson/collections for a library and a unit test program.
