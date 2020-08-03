all: ayfx.drv
.PHONY: ayfx.drv

CC=sjasmplus --nologo
DEPS=build build/ayfx.bin

ayfx.drv: $(DEPS)
	@$(CC) src/ayfx_drv.asm --raw=ayfx.drv --sym=ayfx.labels
	cp ayfx.* example/

build/ayfx.bin:
	@$(CC) src/ayfx.asm --zxnext=cspect --sym=build/ayfx.labels --raw=build/ayfx.bin

build: clean
	@mkdir -p build
clean:
	rm -rf build/
