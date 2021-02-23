OS := $(shell uname)

JULIA := julia
JULIA_DIR := $(shell $(JULIA) -e 'print(dirname(Sys.BINDIR))')
DLEXT := $(shell $(JULIA) -e 'using Libdl; print(Libdl.dlext)')
MAIN := main

ifeq ($(OS), WINNT)
  MAIN := $(MAIN).exe
endif

ifeq ($(OS), Darwin)
  WLARGS := -Wl,-rpath,"$(JULIA_DIR)/lib" -Wl,-rpath,"@executable_path"
else
  WLARGS := -Wl,-rpath,"$(JULIA_DIR)/lib:$$ORIGIN"
endif

CFLAGS+=-O2 -fPIE -I$(JULIA_DIR)/include/julia
LDFLAGS+=-L$(JULIA_DIR)/lib -L. -ljulia -lm $(WLARGS)

.DEFAULT_GOAL := main

libcg.$(DLEXT): build/build.jl src/CG.jl build/generate_precompile.jl build/additional_precompile.jl
	$(JULIA) --startup-file=no --project=. -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) --startup-file=no --project=build -e 'using Pkg; Pkg.instantiate()'
	# Remove the following line when `create_library()` is merged upstream
	$(JULIA) --startup-file=no --project=build -e 'import Pkg; Pkg.add(url="https://github.com/kmsquire/PackageCompiler.jl.git", rev="kms/create_library")'
	JULIA_DEBUG=PackageCompiler OUTDIR=$(OUTDIR) $(JULIA) --startup-file=no --project=build $<

main.o: main.c
	$(CC) $^ -c -o $@ $(CFLAGS) -DJULIAC_PROGRAM_LIBNAME=\"libcg.$(DLEXT)\"

$(MAIN): main.o libcg.$(DLEXT)
	$(CC) -o $@ $< $(LDFLAGS) -lcg

.PHONY: clean
clean:
	$(RM) *~ *.o *.$(DLEXT) main
