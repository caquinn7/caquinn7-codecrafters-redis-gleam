@external(erlang, "binary_utils_ffi", "safe_binary_to_integer")
pub fn binary_to_int(bits: BitArray) -> Result(Int, Nil)

pub type Endianness {
  Big
  Little
}

pub fn decode_unsigned_int(
  bits: BitArray,
  endianness: Endianness,
) -> Result(Int, Nil) {
  case endianness {
    Big -> decode_unsigned_int_ffi(bits)
    Little -> decode_unsigned_int_little_ffi(bits)
  }
}

@external(erlang, "binary_utils_ffi", "safe_decode_unsigned")
fn decode_unsigned_int_ffi(bits: BitArray) -> Result(Int, Nil)

@external(erlang, "binary_utils_ffi", "safe_decode_unsigned_little")
fn decode_unsigned_int_little_ffi(bits: BitArray) -> Result(Int, Nil)
