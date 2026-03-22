from __future__ import annotations


def bytes_to_words(data: bytes, *, word_bytes: int) -> list[int]:
    if len(data) % word_bytes != 0:
        raise ValueError("Payload length must be an integer number of words")
    return [
        int.from_bytes(data[index : index + word_bytes], "little")
        for index in range(0, len(data), word_bytes)
    ]


def words_to_bytes(words: list[int], *, word_bytes: int) -> bytes:
    return b"".join(word.to_bytes(word_bytes, "little") for word in words)


def pack_words(words: list[int], *, word_bits: int, range_low: int, range_high: int) -> list[int]:
    if not words:
        return []

    pack_size = range_high - range_low + 1
    mask = (1 << pack_size) - 1
    bits: list[int] = []
    packed = [words[0]]

    for word in words[1:]:
        selected = (word >> range_low) & mask
        bits.extend((selected >> bit) & 1 for bit in range(pack_size))
        while len(bits) >= word_bits:
            packed_word = sum(bit << index for index, bit in enumerate(bits[:word_bits]))
            packed.append(packed_word)
            bits = bits[word_bits:]

    if bits:
        packed_word = sum(bit << index for index, bit in enumerate(bits))
        packed.append(packed_word)

    return packed


def unpack_words(words: list[int], *, word_bits: int, range_low: int, range_high: int) -> list[int]:
    if not words:
        return []

    pack_size = range_high - range_low + 1
    bits: list[int] = []
    unpacked = [words[0]]

    for word in words[1:]:
        bits.extend((word >> bit) & 1 for bit in range(word_bits))
        while len(bits) >= pack_size:
            selected = sum(bit << index for index, bit in enumerate(bits[:pack_size]))
            unpacked.append(selected << range_low)
            bits = bits[pack_size:]

    if bits:
        selected = sum(bit << index for index, bit in enumerate(bits))
        unpacked.append(selected << range_low)

    return unpacked
