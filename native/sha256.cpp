// doohickey

#include "sha256.hpp"

#include <array>
#include <bit>
#include <cstddef>
#include <cstdint>
#include <format>
#include <span>
#include <vector>

namespace ionix {
namespace {

constexpr std::size_t block_size = 64;
constexpr std::size_t length_offset = 56;

constexpr std::array<std::uint32_t, 64> round_constants = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
};

using State = std::array<std::uint32_t, 8>;

void compress(State& state, std::span<const std::uint8_t, block_size> block) {
    std::array<std::uint32_t, 64> schedule{};

    for (std::size_t index = 0; index < 16; ++index) {
        const auto offset = index * 4;

        schedule[index] =
            (std::uint32_t{block[offset]} << 24) | (std::uint32_t{block[offset + 1]} << 16) |
            (std::uint32_t{block[offset + 2]} << 8) | std::uint32_t{block[offset + 3]};
    }

    for (std::size_t index = 16; index < schedule.size(); ++index) {
        const auto earlier = schedule[index - 15];
        const auto later = schedule[index - 2];
        const auto sigma0 = std::rotr(earlier, 7) ^ std::rotr(earlier, 18) ^ (earlier >> 3);
        const auto sigma1 = std::rotr(later, 17) ^ std::rotr(later, 19) ^ (later >> 10);

        schedule[index] = schedule[index - 16] + sigma0 + schedule[index - 7] + sigma1;
    }

    auto working = state;
    auto& [a, b, c, d, e, f, g, h] = working;

    for (std::size_t round = 0; round < schedule.size(); ++round) {
        const auto sigma1 = std::rotr(e, 6) ^ std::rotr(e, 11) ^ std::rotr(e, 25);
        const auto choose = (e & f) ^ (~e & g);
        const auto temporary1 = h + sigma1 + choose + round_constants[round] + schedule[round];

        const auto sigma0 = std::rotr(a, 2) ^ std::rotr(a, 13) ^ std::rotr(a, 22);
        const auto majority = (a & b) ^ (a & c) ^ (b & c);
        const auto temporary2 = sigma0 + majority;

        h = g;
        g = f;
        f = e;
        e = d + temporary1;
        d = c;
        c = b;
        b = a;
        a = temporary1 + temporary2;
    }

    for (std::size_t index = 0; index < state.size(); ++index) {
        state[index] += working[index];
    }
}

} // namespace

std::string sha256(std::string_view input) {
    State state = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    };

    std::vector<std::uint8_t> data(input.begin(), input.end());
    const auto bit_length = static_cast<std::uint64_t>(input.size()) * 8;

    data.push_back(0x80);

    while (data.size() % block_size != length_offset) {
        data.push_back(0);
    }

    for (int shift = 56; shift >= 0; shift -= 8) {
        data.push_back(static_cast<std::uint8_t>(bit_length >> shift));
    }

    for (std::size_t offset = 0; offset < data.size(); offset += block_size) {
        const auto block = std::span<const std::uint8_t>{data}.subspan(offset).first<block_size>();
        compress(state, block);
    }

    std::string digest;
    digest.reserve(64);

    for (const auto word : state) {
        digest += std::format("{:08x}", word);
    }

    return digest;
}

} // namespace ionix
