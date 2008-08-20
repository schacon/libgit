all: build
	./test
	
build: test*.c
	gcc -o test test*.c -lm

clean:
	rm test