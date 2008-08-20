all: build
	./test
	
build: test*.c
	gcc -o test test*.c ../src/git.o 

clean:
	rm test
