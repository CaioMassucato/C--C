all: main clean

main:
	bison -d -v src/c-minus-.y
	flex src/c-minus-.l
	gcc -g c-minus-.tab.c lex.yy.c src/vector.c src/vector.h -o g--

clean:
	rm -rf *.o
	rm -rf *.gch
	rm -rf *.tab.c
	rm -rf *.yy.c
	rm -rf *.h
	rm -rf ./src/*.gch
	
fclean: clean
	rm -rf g--
	rm -rf *.out
	rm -rf *.output
