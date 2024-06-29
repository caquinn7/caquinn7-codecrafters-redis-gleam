import file_streams/file_stream_error.{Enoent}
import gleam/option.{None, Some}
import gleam/string
import gleeunit
import gleeunit/should
import rdb.{
  type Rdb, AuxiliaryField, Database, EncodedStringExpected, Expiry,
  InvalidStringTypeBits, LengthEncodedIntExpected, Milliseconds, Rdb,
  ReadFileError, Record, StringEncodedIntExpected,
}

pub fn main() {
  gleeunit.main()
}

pub fn rdb_parse_file_not_found_test() {
  "test/rdb/dumps.rdb"
  |> rdb.parse
  |> should.be_error
  |> should.equal(ReadFileError(Enoent))
}

pub fn rdb_parse_happy_path_test() {
  // hexdump -C test/rdb/dump2.rdb
  // 00000000  52 45 44 49 53 30 30 31  31 fa 09 72 65 64 69 73  |REDIS0011..redis|
  // 00000010  2d 76 65 72 05 37 2e 32  2e 35 fa 0a 72 65 64 69  |-ver.7.2.5..redi|
  // 00000020  73 2d 62 69 74 73 c0 40  fa 05 63 74 69 6d 65 c2  |s-bits.@..ctime.|
  // 00000030  fa 12 73 66 fa 08 75 73  65 64 2d 6d 65 6d c2 e0  |..sf..used-mem..|
  // 00000040  46 12 00 fa 08 61 6f 66  2d 62 61 73 65 c0 00 fe  |F....aof-base...|
  // 00000050  00 fb 02 01 fc d9 c9 90  31 90 01 00 00 00 04 6b  |........1......k|
  // 00000060  65 79 32 c0 7b 00 04 6b  65 79 31 03 61 62 63 ff  |ey2.{..key1.abc.|
  // 00000070  c1 04 5e 55 a1 fa fb 75                           |..^U...u|
  // 00000078

  // io.debug(
  "test/rdb/dump.rdb"
  |> rdb.parse
  |> should.be_ok
  // )
  |> should.equal(
    Rdb(
      11,
      [
        AuxiliaryField(<<"redis-ver":utf8>>, <<"7.2.5":utf8>>),
        AuxiliaryField(<<"redis-bits":utf8>>, <<64>>),
        AuxiliaryField(<<"ctime":utf8>>, <<1_718_817_530:size(32)-little>>),
        AuxiliaryField(<<"used-mem":utf8>>, <<1_197_792:size(32)-little>>),
        AuxiliaryField(<<"aof-base":utf8>>, <<0>>),
      ],
      [
        Database(0, [
          Record(
            <<"key2":utf8>>,
            <<123>>,
            Some(Expiry(1_718_818_490_841, Milliseconds)),
          ),
          Record(<<"key1":utf8>>, <<"abc":utf8>>, None),
        ]),
      ],
      <<193, 4, 94, 85, 161, 250, 251, 117>>,
    ),
  )
}

// parse_encoded_string

pub fn rdb_parse_encoded_string_empty_test() {
  <<"":utf8>>
  |> rdb.parse_encoded_string
  |> should.be_error
  |> should.equal(EncodedStringExpected)
}

pub fn rdb_parse_encoded_string_zero_length_string_test() {
  <<0:size(2), 0:size(6)>>
  |> rdb.parse_encoded_string
  |> should.be_ok
  |> should.equal(#(<<>>, <<>>))
}

pub fn rdb_parse_encoded_string_length_prefixed_with_six_bit_int_test() {
  <<0:size(2), 1:size(6), "a":utf8, "b":utf8>>
  |> rdb.parse_encoded_string
  |> should.be_ok
  |> should.equal(#(<<"a":utf8>>, <<"b":utf8>>))
}

pub fn rdb_parse_encoded_string_length_prefixed_with_fourteen_bit_int_test() {
  let len = 16_383
  let content = string.repeat("a", len)

  <<1:size(2), len:size(14), content:utf8>>
  |> rdb.parse_encoded_string
  |> should.be_ok
  |> should.equal(#(<<content:utf8>>, <<>>))
}

pub fn rdb_parse_encoded_string_one_byte_int_test() {
  <<3:size(2), 0:size(6), 255:size(8)>>
  |> rdb.parse_encoded_string
  |> should.be_ok
  |> should.equal(#(<<255:size(8)>>, <<>>))
}

pub fn rdb_parse_encoded_string_two_byte_int_test() {
  <<3:size(2), 1:size(6), 255:size(16)-little>>
  |> rdb.parse_encoded_string
  |> should.be_ok
  |> should.equal(#(<<255:size(16)-little>>, <<>>))
}

pub fn rdb_parse_encoded_string_four_byte_int_test() {
  <<3:size(2), 2:size(6), 16_777_215:size(32)-little>>
  |> rdb.parse_encoded_string
  |> should.be_ok
  |> should.equal(#(<<16_777_215:size(32)-little>>, <<>>))
}

pub fn rdb_parse_encoded_string_invalid_type_bits_test() {
  <<3:size(2), 4:size(6)>>
  |> rdb.parse_encoded_string
  |> should.be_error
  |> should.equal(InvalidStringTypeBits)
}

// parse_length_encoded_int

pub fn rdb_parse_length_encoded_int_six_bit_int_test() {
  <<0:size(2), 63:size(6)>>
  |> rdb.parse_length_encoded_int
  |> should.be_ok
  |> should.equal(#(63, <<>>))
}

pub fn rdb_parse_length_encoded_int_fourteen_bit_int_test() {
  <<1:size(2), 16_383:size(14)>>
  |> rdb.parse_length_encoded_int
  |> should.be_ok
  |> should.equal(#(16_383, <<>>))
}

pub fn rdb_parse_length_encoded_int_one_byte_int_test() {
  <<3:size(2), 0:size(6), 255:size(8)>>
  |> rdb.parse_length_encoded_int
  |> should.be_ok
  |> should.equal(#(255, <<>>))
}

pub fn rdb_parse_length_encoded_int_two_byte_int_test() {
  // using 00FF b/c FFFF would give the same result regardless of endianness
  <<3:size(2), 1:size(6), 255:size(16)-little>>
  |> rdb.parse_length_encoded_int
  |> should.be_ok
  |> should.equal(#(255, <<>>))
}

pub fn rdb_parse_length_encoded_int_four_byte_int_test() {
  // using 00FFFFFF b/c FFFF would give the same result regardless of endianness
  <<3:size(2), 2:size(6), 16_777_215:size(32)-little>>
  |> rdb.parse_length_encoded_int
  |> should.be_ok
  |> should.equal(#(16_777_215, <<>>))
}

pub fn rdb_parse_length_encoded_int_string_encoded_int_expected_test() {
  <<3:size(2), 4:size(6)>>
  |> rdb.parse_length_encoded_int
  |> should.be_error
  |> should.equal(StringEncodedIntExpected)
}

pub fn rdb_parse_length_encoded_int_significant_bits_out_of_range_test() {
  <<4:size(3)>>
  |> rdb.parse_length_encoded_int
  |> should.be_error
  |> should.equal(LengthEncodedIntExpected)
}
