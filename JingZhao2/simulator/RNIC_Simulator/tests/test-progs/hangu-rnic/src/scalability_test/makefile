VPATH = ./:../
all: server client

client: libhgrnic.c librdma.c client.c
	gcc -g $^ -o ./client -static -I ../

server: libhgrnic.c librdma.c server.c
	gcc -g -D SERVER=1 -o ./server -static $^ -I ../

clean:
	rm ./server ./client
