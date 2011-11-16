SOURCE = $(wildcard *.coffee)
OUTPUT = $(patsubst %.coffee,%.js,$(SOURCE))

all : $(OUTPUT)

%.js : %.coffee
	coffee -cb -o . $^

.PHONY : clean
clean :
	-rm $(OUTPUT)
