INSTALLDIR=/usr/local/bin

all: sigil

sigil: sigil.lisp
	./build.sh

install: all
	sudo cp sigil $(INSTALLDIR)

clean:
	rm -rf sigil *~ quicklisp.lisp quicklisp
