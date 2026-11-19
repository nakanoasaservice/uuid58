//! Dependency-free micro-benchmarks. Run with `cargo bench`.
//!
//! Every benchmark runs over the same 1024 random 128-bit values and prints
//! the fastest and the median sample, in nanoseconds per call.

use std::hint::black_box;
use std::time::Instant;

const INPUTS: usize = 1024;
const SAMPLES: usize = 60;
const ROUNDS: usize = 200;

/// splitmix64, so the inputs are reproducible.
struct Rng(u64);

impl Rng {
    fn next_u64(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9e37_79b9_7f4a_7c15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xbf58_476d_1ce4_e5b9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94d0_49bb_1331_11eb);
        z ^ (z >> 31)
    }
}

fn bench<T, R>(name: &str, inputs: &[T], mut f: impl FnMut(&T) -> R) {
    let mut samples = Vec::with_capacity(SAMPLES);
    for _ in 0..SAMPLES {
        let start = Instant::now();
        for _ in 0..ROUNDS {
            for input in inputs {
                black_box(f(black_box(input)));
            }
        }
        let calls = (ROUNDS * inputs.len()) as f64;
        samples.push(start.elapsed().as_nanos() as f64 / calls);
    }
    samples.sort_by(f64::total_cmp);
    println!(
        "{name:<24} {:>7.2} ns  (median {:>7.2} ns)",
        samples[0],
        samples[SAMPLES / 2]
    );
}

fn main() {
    let mut rng = Rng(0x5eed);
    let values: Vec<u128> = (0..INPUTS)
        .map(|_| (u128::from(rng.next_u64()) << 64) | u128::from(rng.next_u64()))
        .collect();
    let bytes: Vec<[u8; 16]> = values.iter().map(|v| v.to_be_bytes()).collect();
    let encoded: Vec<String> = values.iter().map(|&v| uuid58::encode(v)).collect();
    let uuids: Vec<String> = encoded
        .iter()
        .map(|s| uuid58::decode_to_uuid_string(s).unwrap())
        .collect();
    let plain: Vec<String> = uuids.iter().map(|s| s.replace('-', "")).collect();

    bench("encode_to_buf", &values, |&v| {
        let mut buf = [0u8; uuid58::ENCODED_LEN];
        uuid58::encode_to_buf(v, &mut buf).len()
    });
    bench("encode_bytes_to_buf", &bytes, |b| {
        let mut buf = [0u8; uuid58::ENCODED_LEN];
        uuid58::encode_bytes_to_buf(b, &mut buf).len()
    });
    bench("encode", &values, |&v| uuid58::encode(v));
    bench("encode_uuid_str", &uuids, |s| uuid58::encode_uuid_str(s));
    bench("encode_uuid_str (plain)", &plain, |s| {
        uuid58::encode_uuid_str(s)
    });
    bench("parse_uuid_str", &uuids, |s| uuid58::parse_uuid_str(s));
    bench("parse_uuid_str (plain)", &plain, |s| {
        uuid58::parse_uuid_str(s)
    });

    bench("decode", &encoded, |s| uuid58::decode(s));
    bench("decode_to_bytes", &encoded, |s| uuid58::decode_to_bytes(s));
    bench("is_valid", &encoded, |s| uuid58::is_valid(s));
    bench("decode_to_uuid_buf", &encoded, |s| {
        let mut buf = [0u8; uuid58::UUID_STR_LEN];
        uuid58::decode_to_uuid_buf(s, &mut buf).map(str::len)
    });
    bench("decode_to_uuid_string", &encoded, |s| {
        uuid58::decode_to_uuid_string(s)
    });
}
