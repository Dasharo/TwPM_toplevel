from argparse import ArgumentParser
from itertools import combinations
from statistics import mean
import math


def hamming(s1, s2):
    assert len(s1) == len(s2)
    return sum(pair[0] != pair[1] for pair in list(zip(s1, s2)))


def hex_chars():
    return "0123456789abcdefABCDEF"


parser = ArgumentParser()
parser.add_argument("dataset")
args = parser.parse_args()

with open(args.dataset, "r") as input:
    data = []
    n_bits = None
    for sample_str in input:
        if not sample_str.startswith("0x"):
            continue

        value_str = sample_str[2:-1]
        for x in value_str:
            if x not in hex_chars():
                continue

        if n_bits is None:
            n_bits = len(value_str) * 4
        else:
            assert n_bits == len(value_str) * 4

        sample = bin(int(value_str, 16))[2:].zfill(n_bits)
        assert len(sample) == n_bits
        data.append(sample)


unchanged_n = sum(1 for pair in list(zip(data, data[1:])) if pair[0] == pair[1])
print(f"Unchanged samples: {unchanged_n}")


# https://crypto.stackexchange.com/questions/53479/how-is-the-inter-and-the-intra-distance-of-a-puf-calculated
hamming = [hamming(pair[0], pair[1]) for pair in list(combinations(data, 2))]
hamming_avg = mean(hamming)
hamming_worst = max(hamming)
hamming_best = min(hamming)

print(f"Hamming: best={hamming_best:.4f} average={hamming_avg:.4f} worst={hamming_worst:.4f}")
