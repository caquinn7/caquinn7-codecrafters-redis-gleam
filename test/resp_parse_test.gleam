import gleam/int
import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import resp.{
  Array, BulkString, InvalidUnicode, NotEnoughInput, Parsed, SimpleString,
  UnexpectedInput,
}

pub fn main() {
  gleeunit.main()
}

// Simple Strings

pub fn parse_simple_string_test() {
  let content = "OK"
  <<{ "+" <> content <> "\r\n" }:utf8>>
  |> test_ok(Parsed(SimpleString(content), <<>>))
}

// 1_232_837:size(128) = <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 18, 207, 197>>
// For multi-byte sequences:
// Bytes starting with 110xxxxx or higher indicate the start of a multi-byte sequence. (110xxxxx indicates a two-byte sequence)
// 0xCF (207) (11001111) is the start of a 2-byte sequence, so it must be followed by a continuation byte of the form 10xxxxxx.
// 0xC5 (197) (11000101) also indicates the start of a 2-byte sequence and must be followed by a continuation byte.
// Since both 0xCF and 0xC5 are not followed by the necessary continuation bytes, they do not form valid UTF-8 sequences on their own.
pub fn parse_simple_string_not_utf8_test() {
  <<"+OK":utf8, 1_232_837:size(128), "\r\n":utf8>>
  |> test_err(InvalidUnicode)
}

pub fn parse_simple_string_empty_test() {
  <<"+\r\n":utf8>>
  |> test_ok(Parsed(SimpleString(""), <<>>))
}

pub fn parse_simple_string_not_enough_input_test() {
  <<"+":utf8>>
  |> test_err(NotEnoughInput)
}

pub fn parse_simple_string_no_terminator_test() {
  <<"+OK":utf8>>
  |> test_err(NotEnoughInput)
}

pub fn parse_simple_string_has_newline_test() {
  <<"+O\nK\r\n":utf8>>
  |> test_err(UnexpectedInput(<<"\n":utf8>>))
}

pub fn parse_simple_string_has_newline_at_end_test() {
  <<"+OK\n\r\n":utf8>>
  |> test_err(UnexpectedInput(<<"\n":utf8>>))
}

pub fn parse_simple_string_has_newline_at_start_test() {
  <<"+\nOK\r\n":utf8>>
  |> test_err(UnexpectedInput(<<"\n":utf8>>))
}

pub fn parse_simple_string_has_carriage_return_test() {
  <<"+O\rK\r\n":utf8>>
  |> test_err(UnexpectedInput(<<"\r":utf8>>))
}

// Bulk Strings

pub fn parse_bulk_string_null_test() {
  <<"$-1\r\n":utf8>>
  |> test_ok(Parsed(BulkString(None), <<>>))
}

pub fn parse_bulk_string_test() {
  let content = "hello"
  <<{ "$5\r\n" <> content <> "\r\n" }:utf8>>
  |> test_ok(Parsed(BulkString(Some(<<content:utf8>>)), <<>>))
}

pub fn parse_bulk_string_not_utf8_test() {
  let num = 1_232_837
  let bit_count = 128
  let byte_count = 128 / 8
  <<
    { "$" <> int.to_string(byte_count) <> "\r\n" }:utf8,
    num:size(bit_count),
    "\r\n":utf8,
  >>
  |> test_ok(Parsed(BulkString(Some(<<num:size(128)>>)), <<>>))
}

pub fn parse_bulk_string_only_dollar_sign_test() {
  <<"$":utf8>>
  |> test_err(NotEnoughInput)
}

pub fn parse_bulk_string_some_letter_after_dollar_sign_test() {
  <<"$a":utf8>>
  |> test_err(UnexpectedInput(<<"a":utf8>>))
}

pub fn parse_bulk_string_no_newline_test() {
  <<"$1\r":utf8>>
  |> test_err(NotEnoughInput)
}

pub fn parse_bulk_string_some_character_after_length_test() {
  <<"$1a":utf8>>
  |> test_err(UnexpectedInput(<<"a":utf8>>))
}

pub fn parse_bulk_string_content_shorter_than_expected_test() {
  <<"$1\r\n\r\n":utf8>>
  |> test_err(UnexpectedInput(<<"\n":utf8>>))
}

pub fn parse_bulk_string_content_longer_than_expected_test() {
  <<"$1\r\nab\r\n":utf8>>
  |> test_err(UnexpectedInput(<<"b\r\n":utf8>>))
}

pub fn parse_bulk_string_no_content_test() {
  <<"$1\r\n":utf8>>
  |> test_err(NotEnoughInput)
}

pub fn parse_bulk_string_no_ending_newline_test() {
  <<"$5\r\nhello\r":utf8>>
  |> test_err(NotEnoughInput)
}

// Arrays

pub fn parse_array_empty_test() {
  <<"*0\r\n":utf8>>
  |> test_ok(Parsed(Array([]), <<>>))
}

pub fn parse_array_bulk_strings_test() {
  <<"*2\r\n$4\r\nECHO\r\n$3\r\nHEY\r\n":utf8>>
  |> test_ok(
    Parsed(
      Array([
        BulkString(Some(<<"ECHO":utf8>>)),
        BulkString(Some(<<"HEY":utf8>>)),
      ]),
      <<>>,
    ),
  )
}

pub fn parse_array_simple_strings_test() {
  <<"*2\r\n+hello\r\n+world\r\n":utf8>>
  |> test_ok(
    Parsed(Array([SimpleString("hello"), SimpleString("world")]), <<>>),
  )
}

pub fn parse_array_mixed_types_test() {
  <<"*2\r\n$5\r\nhello\r\n+world\r\n":utf8>>
  |> test_ok(
    Parsed(
      Array([BulkString(Some(<<"hello":utf8>>)), SimpleString("world")]),
      <<>>,
    ),
  )
}

pub fn parse_array_content_shorter_than_expected_test() {
  <<"*2\r\n$4\r\nECHO\r\n":utf8>>
  |> test_err(NotEnoughInput)
}

pub fn parse_array_content_longer_than_expected_test() {
  <<"*1\r\n$4\r\nECHO\r\n$3\r\nHEY\r\n":utf8>>
  |> test_ok(
    Parsed(Array([BulkString(Some(<<"ECHO":utf8>>))]), <<"$3\r\nHEY\r\n":utf8>>),
  )
}

fn test_ok(input, expected) {
  input
  |> resp.parse
  |> should.be_ok
  |> should.equal(expected)
}

fn test_err(input, expected) {
  input
  |> resp.parse
  |> should.be_error
  |> should.equal(expected)
}
