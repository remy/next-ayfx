all: ayfx.drv
.PHONY: ayfx.drv

CC=sjasmplus --nologo
DEPS=build build/ayfx.bin

ayfx.drv: $(DEPS)
	@$(CC) src/ayfx_drv.asm --raw=ayfx.drv

build/ayfx.bin:
	@$(CC) src/ayfx.asm --sym=build/ayfx.labels --raw=build/ayfx.bin

build:
	@mkdir -p build
clean:
	rm -rf build/

# build/ayfx.bin:
#   sjasmplus --nologo src/ayfx.asm --sym=build/ayfx.labels --raw=build/ayfx.bin

# ayfx.drv: build/ayfx.bin
#   sjasmplus --nologo src/ayfx_drv.asm --raw=ayfx.drv

# build:
# 	mkdir -p build

# build: build/ayfx.bin

