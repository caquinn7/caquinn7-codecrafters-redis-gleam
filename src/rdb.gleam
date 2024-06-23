import binary_utils.{Big, Little}
import file_streams/file_stream
import file_streams/file_stream_error.{type FileStreamError}
import gleam/bit_array
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

pub type RdbError {
  ReadFileError(FileStreamError)

  NotEnoughBytes
  UnexpectedInput

  NoMagicString
  InvalidVersionBytes

  NotImplemented(String)

  LengthEncodedIntExpected
  StringEncodedIntExpected

  EncodedStringExpected
  InvalidStringTypeBits

  EofByteExpected
  InvalidChecksumBytes
}

pub type AuxiliaryField {
  AuxiliaryField(key: BitArray, value: BitArray)
}

pub type Record {
  Record(key: BitArray, value: BitArray, expiry: Option(Expiry))
}

pub type Expiry {
  Expiry(Int, ExpiryUnit)
}

pub type ExpiryUnit {
  Milliseconds
  Seconds
}

pub type Database {
  Database(selector: Int, records: List(Record))
}

pub type Rdb {
  Rdb(
    version: Int,
    auxiliary_fields: List(AuxiliaryField),
    databases: List(Database),
    checksum: BitArray,
  )
}

pub fn parse(path: String) -> Result(Rdb, RdbError) {
  use #(version, rest) <- result.try(open_rdb(path))
  use #(aux_fields, rest) <- result.try(parse_auxiliary_fields(rest, []))
  use #(databases, rest) <- result.try(parse_databases(rest, []))
  use #(checksum, _) <- result.try(parse_checksum(rest))
  Ok(Rdb(version, aux_fields, databases, checksum))
}

/// Length encoding is used to store the length of the next object in the stream.
/// Length encoding is a variable byte encoding designed to use as few bytes as possible.
///
/// This is how length encoding works : Read one byte from the stream, compare the two most significant bits:
/// 
/// 00	The next 6 bits represent the length
/// 
/// 01	Read one additional byte. The combined 14 bits represent the length
/// 
/// 10	Discard the remaining 6 bits. The next 4 bytes from the stream represent the length
/// 
/// 11	The next object is encoded in a special format. The remaining 6 bits indicate the format. May be used to store numbers or Strings, see String Encoding
pub fn parse_length_encoded_int(
  input: BitArray,
) -> Result(#(Int, BitArray), RdbError) {
  let parse_encoded_int = fn(int_bits, endianness, rest) {
    // should only be error if arg was not byte-aligned
    let assert Ok(len) = binary_utils.decode_unsigned_int(int_bits, endianness)
    Ok(#(len, rest))
  }

  let parse_string_encoded_int = fn(byte_size_of_int, rest) {
    use int_bytes <- result.try(
      rest
      |> bit_array.slice(at: 0, take: byte_size_of_int)
      |> result.replace_error(NotEnoughBytes),
    )
    let assert Ok(decoded_int) =
      binary_utils.decode_unsigned_int(int_bytes, Little)
    let assert Ok(bytes_after_int) =
      bit_array.slice(
        rest,
        at: byte_size_of_int,
        take: bit_array.byte_size(rest) - byte_size_of_int,
      )
    Ok(#(decoded_int, bytes_after_int))
  }

  case input {
    <<0:size(2), int_bits:bits-size(6), rest:bits>> ->
      parse_encoded_int(<<0:2, int_bits:bits>>, Big, rest)

    <<1:size(2), int_bits:bits-size(14), rest:bits>> ->
      parse_encoded_int(<<0:2, int_bits:bits>>, Big, rest)

    <<2:size(2), _:bits-size(6), int_bits:bits-size(32), rest:bits>> ->
      parse_encoded_int(int_bits, Big, rest)

    <<3:size(2), i:size(6), rest:bits>> -> {
      case i {
        0 -> parse_string_encoded_int(1, rest)
        1 -> parse_string_encoded_int(2, rest)
        2 -> parse_string_encoded_int(4, rest)
        _ -> Error(StringEncodedIntExpected)
      }
    }
    _ -> Error(LengthEncodedIntExpected)
  }
}

/// Redis Strings are binary safe - which means you can store anything in them.
/// They do not have any special end-of-string token. It is best to think of Redis Strings as a byte array.
/// 
/// There are three types of Strings in Redis:
/// 
/// * Length prefixed strings
/// 
/// * An 8, 16 or 32 bit integer
/// 
/// * A LZF compressed string
/// 
/// Length Prefixed String
/// 
/// The length of the string in bytes is first encoded using Length Encoding.
/// After this, the raw bytes of the string are stored.
/// 
/// Integers as String
/// 
/// First read the section Length Encoding, specifically the part when the first two bits are 11. In this case, the remaining 6 bits are read.
/// 
/// If the value of those 6 bits is:
/// 
/// 0 indicates that an 8 bit integer follows
/// 
/// 1 indicates that a 16 bit integer follows
/// 
/// 2 indicates that a 32 bit integer follows
pub fn parse_encoded_string(
  input: BitArray,
) -> Result(#(BitArray, BitArray), RdbError) {
  let parse_len_prefixed_str = fn(len_bits, endianness, rest) {
    // should only be error if arg was not byte-aligned
    let assert Ok(len) = binary_utils.decode_unsigned_int(len_bits, endianness)
    use str_bytes <- result.try(
      rest
      |> bit_array.slice(at: 0, take: len)
      |> result.replace_error(NotEnoughBytes),
    )
    let assert Ok(bytes_after_str) =
      bit_array.slice(rest, at: len, take: bit_array.byte_size(rest) - len)

    Ok(#(str_bytes, bytes_after_str))
  }

  let parse_string_encoded_int = fn(byte_size_of_int, rest) {
    use int_bytes <- result.try(
      rest
      |> bit_array.slice(at: 0, take: byte_size_of_int)
      |> result.replace_error(NotEnoughBytes),
    )
    let assert Ok(bytes_after_int) =
      bit_array.slice(
        rest,
        at: byte_size_of_int,
        take: bit_array.byte_size(rest) - byte_size_of_int,
      )
    Ok(#(int_bytes, bytes_after_int))
  }

  case input {
    <<0:size(2), len_bits:bits-size(6), rest:bits>> ->
      parse_len_prefixed_str(<<0:2, len_bits:bits>>, Big, rest)

    <<1:size(2), len_bits:bits-size(14), rest:bits>> ->
      parse_len_prefixed_str(<<0:2, len_bits:bits>>, Big, rest)

    <<2:size(2), _:bits-size(6), len_bits:bits-size(32), rest:bits>> ->
      parse_len_prefixed_str(len_bits, Big, rest)

    <<3:size(2), i:size(6), rest:bits>> ->
      case i {
        0 -> parse_string_encoded_int(1, rest)
        1 -> parse_string_encoded_int(2, rest)
        2 -> parse_string_encoded_int(4, rest)
        3 -> Error(NotImplemented("Compressed Strings"))
        _ -> Error(InvalidStringTypeBits)
      }
    _ -> Error(EncodedStringExpected)
  }
}

fn open_rdb(path: String) -> Result(#(Int, BitArray), RdbError) {
  use stream <- result.try(
    path
    |> file_stream.open_read
    |> result.map_error(ReadFileError),
  )
  use bits <- result.try(
    stream
    |> file_stream.read_remaining_bytes
    |> result.map_error(ReadFileError),
  )
  use next_bits <- result.try(case bits {
    <<"REDIS":utf8, rest:bits>> -> Ok(rest)
    _ -> Error(NoMagicString)
  })
  use version_bits <- result.try(
    next_bits
    |> bit_array.slice(0, 4)
    |> result.replace_error(InvalidVersionBytes),
  )
  use version_str <- result.try(
    version_bits
    |> bit_array.to_string
    |> result.replace_error(InvalidVersionBytes),
  )
  use version <- result.try(
    version_str
    |> int.parse
    |> result.replace_error(InvalidVersionBytes),
  )

  let total_bytes = bit_array.byte_size(bits)
  let assert Ok(rest) = bit_array.slice(bits, at: 9, take: total_bytes - 9)
  Ok(#(version, rest))
}

fn parse_auxiliary_fields(
  input: BitArray,
  auxiliary_fields: List(AuxiliaryField),
) -> Result(#(List(AuxiliaryField), BitArray), RdbError) {
  case input {
    // FE
    <<254:int, rest:bits>> ->
      Ok(#(list.reverse(auxiliary_fields), <<254:int, rest:bits>>))

    // FA
    <<250:int, rest:bits>> -> {
      use #(key, rest) <- result.try(parse_encoded_string(rest))
      use #(val, rest) <- result.try(parse_encoded_string(rest))
      parse_auxiliary_fields(rest, [
        AuxiliaryField(key, val),
        ..auxiliary_fields
      ])
    }

    _ -> Error(UnexpectedInput)
  }
}

fn parse_databases(
  input: BitArray,
  databases: List(Database),
) -> Result(#(List(Database), BitArray), RdbError) {
  case input {
    // FF
    <<255:int, rest:bits>> ->
      Ok(#(list.reverse(databases), <<255:int, rest:bits>>))

    // FE
    <<254:int, rest:bits>> -> {
      use #(selector, rest) <- result.try(parse_length_encoded_int(rest))
      case rest {
        // FB
        <<251:int, rest:bits>> -> {
          use #(_hash_table_size, rest) <- result.try(parse_length_encoded_int(
            rest,
          ))
          use #(_expire_hash_table_size, rest) <- result.try(
            parse_length_encoded_int(rest),
          )
          use #(records, rest) <- result.try(parse_records(rest, []))
          parse_databases(rest, [Database(selector, records), ..databases])
        }

        _ -> Error(UnexpectedInput)
      }
    }

    _ -> Error(UnexpectedInput)
  }
}

fn parse_records(
  input: BitArray,
  records: List(Record),
) -> Result(#(List(Record), BitArray), RdbError) {
  let parse_key_val_pair = fn(input) {
    use #(key, rest) <- result.try(parse_encoded_string(input))
    use #(val, rest) <- result.try(parse_encoded_string(rest))
    Ok(#(key, val, rest))
  }

  case input {
    // FF
    <<255:int, rest:bits>> ->
      Ok(#(list.reverse(records), <<255:int, rest:bits>>))

    // FE
    <<254:int, rest:bits>> ->
      Ok(#(list.reverse(records), <<254:int, rest:bits>>))

    // FD (expiry time in seconds)
    <<253:int, i:size(32)-little, 0, rest:bits>> -> {
      use #(key, val, rest) <- result.try(parse_key_val_pair(rest))
      let record = Record(key, val, Some(Expiry(i, Seconds)))
      parse_records(rest, [record, ..records])
    }

    // FC (expiry time in ms)
    <<252:int, i:size(64)-little, 0, rest:bits>> -> {
      use #(key, val, rest) <- result.try(parse_key_val_pair(rest))
      let record = Record(key, val, Some(Expiry(i, Milliseconds)))
      parse_records(rest, [record, ..records])
    }

    // No expiry
    <<0, rest:bits>> -> {
      use #(key, val, rest) <- result.try(parse_key_val_pair(rest))
      let record = Record(key, val, None)
      parse_records(rest, [record, ..records])
    }

    <<_:int, _:bits>> ->
      Error(NotImplemented("Only the 'String' value type has been implemented"))

    _ -> Error(UnexpectedInput)
  }
}

fn parse_checksum(input: BitArray) -> Result(#(BitArray, BitArray), RdbError) {
  use eof_byte <- result.try(
    input
    |> bit_array.slice(at: 0, take: 1)
    |> result.replace_error(EofByteExpected),
  )
  use _ <- result.try(case eof_byte {
    <<255>> -> Ok(Nil)
    _ -> Error(EofByteExpected)
  })
  use checksum <- result.try(
    input
    |> bit_array.slice(at: 1, take: 8)
    |> result.replace_error(InvalidChecksumBytes),
  )
  let total_bytes = bit_array.byte_size(input)
  let assert Ok(rest) = bit_array.slice(input, at: 9, take: total_bytes - 9)
  Ok(#(checksum, rest))
}
