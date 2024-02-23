from argparse import ArgumentParser
from itertools import combinations, pairwise, repeat
from statistics import mean
import math
import numpy as np
import multiprocessing as mp
from time import time


def hamming(s1, s2):
    assert len(s1) == len(s2)
    return sum(pair[0] != pair[1] for pair in list(zip(s1, s2)))


def binary_hamming32(s1: np.array, s2: np.array):
    assert len(s1) == len(s2)
    assert len(s1) % 32 == 0

    s1_packed = np.packbits(s1).view(">u4")
    s2_packed = np.packbits(s2).view(">u4")
    diff_packed = np.fromiter(
        [x.__xor__(y) for x, y in zip(s1_packed, s2_packed)], dtype=np.uint32
    ).view(np.uint8)
    return np.count_nonzero(np.unpackbits(diff_packed))


def hex_chars():
    return "0123456789abcdefABCDEF"


def do_hamming(pair):
    return binary_hamming32(pair[0], pair[1])


def main():
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

            sample = bytes.fromhex(value_str)
            assert len(sample) * 8 == n_bits

            sample = np.unpackbits(np.frombuffer(sample, dtype=np.uint8))
            data.append(sample)

    data = np.array(data, dtype=bool)

    set_bits_cnt = np.zeros(len(data[0]), dtype=int)
    for sample in data:
        set_bits_cnt += sample

    average_id_bits = np.fromiter(
        [x >= len(data) / 2 for x in set_bits_cnt], dtype=bool
    )
    average_id = int.from_bytes(np.packbits(average_id_bits))
    print(f"average_id = {average_id:#x}")

    noisy_bits = np.zeros(len(data[0]), dtype=bool)
    for s0, s1 in zip(data, data[1:]):
        noisy_bits |= data[0].__xor__(s0)
        noisy_bits |= data[0].__xor__(s1)

    print(f"Noisy bits: {noisy_bits}")

    # Relative hamming from average
    hamming = [binary_hamming32(x, y) for x, y in zip(data, repeat(average_id_bits))]
    print(
        f"Relative Hamming: best={min(hamming):.4f} average={mean(hamming):.4f} worst={max(hamming):.4f}"
    )

    # for i, n in enumerate(set_bits_cnt):
    #     print(f"bit[{i}] set {n} times")

    # start = time()
    # pool = mp.Pool(processes=16)
    # hamming = pool.map(do_hamming, combinations(data, 2))
    # end = time()

    # print(f"Hamming took {end - start} seconds")
    # hamming_avg = mean(hamming)
    # hamming_worst = max(hamming)
    # hamming_best = min(hamming)
    # print(
    #    f"Hamming: best={hamming_best:.4f} average={hamming_avg:.4f} worst={hamming_worst:.4f}"
    # )


if __name__ == "__main__":
    main()

# print(type(data[0]), type(data[0].dtype))
# print(data[0])

# unchanged_n = sum(1 for pair in list(zip(data, data[1:])) if pair[0] == pair[1])
# print(f"Unchanged samples: {unchanged_n}")

# for pair in list(combinations(data, 2)):

# https://crypto.stackexchange.com/questions/53479/how-is-the-inter-and-the-intra-distance-of-a-puf-calculated
# pool = mp.Pool(processes=4)

# start = time()
# def task(arg):
# print(arg)
#    print()

# pool.map(task, [1,2,3,4])

# hamming = [binary_hamming32(pair[0], pair[1]) for pair in list(combinations(data[:1024], 2))]
# hamming = np.empty(math.comb(1024, 2), dtype=int)
# for i, (v0, v1) in enumerate(combinations(data[:1024], 2)):
#    hamming[i] = binary_hamming32(v0, v1)

# end = time()
# print(f'hamming time: {end - start}')
# hamming_avg = mean(hamming)
# hamming_worst = max(hamming)
# hamming_best = min(hamming)

# print(f"Hamming: best={hamming_best:.4f} average={hamming_avg:.4f} worst={hamming_worst:.4f}")

# noisy_bits = 0
# for pair in list(zip(repeat(data[0]), data[1:])):
#    for i, bit in enumerate(zip(pair[0], pair[1])):
#        if bit[0] != bit[1]:
#            noisy_bits |= 1 << i

# n_changes = [0] * len(data[0])
# n_comb = math.comb(len(data), 2)
# for pair in combinations(data, 2):
#     for i, bit in enumerate(zip(pair[0], pair[1])):
#         n_changes[i] += 1 if bit[0] != bit[1] else 0

# print(f'noise = {noisy_bits:#x}')
