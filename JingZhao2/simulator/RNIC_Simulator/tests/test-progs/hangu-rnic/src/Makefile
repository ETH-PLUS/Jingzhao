

all: server client test

test: libhgrnic.c test.c
	gcc $^ -o ../bin/test -static

client: libhgrnic.c librdma.c client.c
	gcc $^ -o ../bin/client -static

server: libhgrnic.c librdma.c server.c
	gcc -D SERVER=1 -o ../bin/server -static $^


clean:
	rm ../bin/test ../bin/server ../bin/client
