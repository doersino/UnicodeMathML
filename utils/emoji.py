# assemble a list of emoji codepoints and ranges and establish a mapping of
# astral plane emoji to the bmp's private use area

# in this context: emoji are all characters where Emoji_Presentation=Yes

import urllib.request
import sys

#url = 'https://unicode.org/Public/emoji/12.0/emoji-sequences.txt'
url = 'https://unicode.org/Public/emoji/12.0/emoji-data.txt'
response = urllib.request.urlopen(url)
text = response.read().decode('utf-8')

text = text.splitlines();

text = [line for line in text if line.strip()]        # remove empty lines
text = [line for line in text if line[0] != '#']      # remove comments
text = [line for line in text if '; Emoji_Presentation' in line]      # remove non-emoji
text = [line.split(';')[0].strip() for line in text]  # remove metadata

# subdivide into the three categories of lines
# TODO improve emoji support by somehow also supporting sequences
sequences = [sequence for sequence in text if ' ' in sequence]
ranges = [range for range in text if '..' in range]
codepoints = [codepoint for codepoint in text if codepoint not in sequences and codepoint not in ranges]

# union codpepoints with ranges expanded to lists of codepoints
def toNum(cp):
    return int(cp, 16)

def fromNum(n):
    return str(hex(n)).upper()[2:]

def all_between(startend):
    s = toNum(startend[0])
    e = toNum(startend[1])

    r = [fromNum(c) for c in range(s, e + 1)]
    return r

ranges = [all_between(line.split('..')) for line in ranges]
ranges = [codepoint for range in ranges for codepoint in range]

codepoints = codepoints + ranges
codepoints.sort(key=toNum)

finalRanges = []
for cp in codepoints:
    if not finalRanges:
        finalRanges.append([cp, cp])
    elif toNum(finalRanges[-1][1]) == toNum(cp) - 1:
        finalRanges[-1][1] = cp
    else:
        finalRanges.append([cp, cp])

#print(sum([toNum(r[1]) - toNum(r[0]) + 1 for r in finalRanges]))
#print(finalRanges)

#print(sequences)
#print(codepoints)
#sys.exit(0)

# map to private use area
privateUseStart = 'E400'
privateUseNext = privateUseStart
finalRangeSizes = [toNum(r[1]) - toNum(r[0]) + 1 for r in finalRanges]

mapping = []
finalFinalRanges = []
for i, cpRange in enumerate(finalRanges):
    if len(cpRange[0]) == 4:  # in bmp
        if cpRange[0] == cpRange[1]:  # range contains only one codepoint
            finalFinalRanges.append('"\\u{}"'.format(cpRange[0]))
        else:  # multiple codepoints
            finalFinalRanges.append('[\\u{}-\\u{}]'.format(cpRange[0], cpRange[1]))
    else:  # outside bmp => need to create mapping
        astralBegin = cpRange[0]
        astralEnd = cpRange[1]
        privateBegin = privateUseNext
        privateUseNext = fromNum(toNum(privateUseNext) + finalRangeSizes[i])
        privateEnd = fromNum(toNum(privateUseNext) - 1)
        mapping.append("{astral: {begin: 0x"+astralBegin+", end: 0x"+astralEnd+"}, private: {begin: 0x"+privateBegin+", end: 0x"+privateEnd+"}}")

finalFinalRanges.append('[\\u{}-\\u{}]'.format(privateUseStart, fromNum(toNum(privateUseNext) - 1)))

print('\n/ '.join(finalFinalRanges))
print(',\n'.join(mapping))
