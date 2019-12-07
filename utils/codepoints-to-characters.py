# given a file containing a newline-separated list of unicode codepoints in the format U+NNNN, outputs the corresponding characters. lines starting with "#" are ignored

import fileinput

input = fileinput.input()
input = [line.strip() for line in input]            # remove line breaks
input = [line for line in input if line[0] != "#"]  # discard comments

for line in input:
    print(chr(int(line[2:], 16)))
