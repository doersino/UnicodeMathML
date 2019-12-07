# given a file composed of unicode characters, outputs the corresponding codepoints. lines starting with "#" are ignored

import fileinput

input = fileinput.input()
input = [line.strip() for line in input]            # remove line breaks
input = [line for line in input if line[0] != "#"]  # discard comments

for line in input:
    print("U+" + str(line.encode("unicode_escape"))[5:-1].lstrip("0").upper())
