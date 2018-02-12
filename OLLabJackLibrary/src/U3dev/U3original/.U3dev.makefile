#
# Makefile for U3Temp
#
U3TEMP_SRC=u3Temp.c u3.c
U3TEMP_OBJ=$(U3TEMP_SRC:.c=.o)

SRCS=$(wildcard *.c)
HDRS=$(wildcard *.h)

CFLAGS +=-Wall -g
LIBS=-lm -llabjackusb

all: u3Temp 

u3Temp: $(U3TEMP_OBJ) $(HDRS)
	$(CC) -o u3Temp $(U3TEMP_OBJ) $(LDFLAGS) $(LIBS)

clean:
	rm -f *.o *~ u3Feedback u3BasicConfigU3 u3allio u3Stream u3EFunctions u3LJTDAC