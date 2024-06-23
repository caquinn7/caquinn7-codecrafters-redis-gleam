/// Converts a bit array containing a textual representation of an integer to an integer.
/// 
/// Returns Error if the bit array is not byte-aligned.
/// 
/// ## Example
///
/// ```gleam
/// binary_to_int(bytes: <<"123":utf8>>)
/// // -> 123
/// ```
///
@external(erlang, "binary_utils_ffi", "safe_binary_to_integer")
pub fn binary_to_int(bytes: BitArray) -> Result(Int, Nil)

pub type Endianness {
  Big
  Little
}

/// Converts the binary digit representation, in big endian or little endian, of a positive integer in bytes to an integer.
/// 
/// Returns Error if the bit array is not byte-aligned.
pub fn decode_unsigned_int(
  bytes: BitArray,
  endianness: Endianness,
) -> Result(Int, Nil) {
  case endianness {
    Big -> decode_unsigned_int_ffi(bytes)
    Little -> decode_unsigned_int_little_ffi(bytes)
  }
}

@external(erlang, "binary_utils_ffi", "safe_decode_unsigned")
fn decode_unsigned_int_ffi(bytes: BitArray) -> Result(Int, Nil)

@external(erlang, "binary_utils_ffi", "safe_decode_unsigned_little")
fn decode_unsigned_int_little_ffi(bytes: BitArray) -> Result(Int, Nil)
