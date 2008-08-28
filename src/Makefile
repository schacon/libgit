CFLAGS=-fPIC -g -c -Wall -O3

all:
	gcc $(CFLAGS) git.c
test: all
	gcc -o test test_git.c git.o
	./test
