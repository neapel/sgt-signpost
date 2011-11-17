SOURCE = $(wildcard *.coffee)
OUTPUT = $(patsubst %.coffee,%.js,$(SOURCE))

all : $(OUTPUT)

%.js : %.coffee
	coffee -cb -o . $^

depend :
	wget -nc 'http://davidbau.com/encode/seedrandom.js'

.PHONY : clean
clean :
	-rm $(OUTPUT)
