import gleam/string
import gleeunit
import gleeunit/should
import resp.{Array, BulkStr}

pub fn main() {
  gleeunit.main()
}

pub fn parse_type_empty_str_test() {
  ""
  |> test_err("Input was empty")
}

pub fn parse_type_invalid_type_symbol_test() {
  "x\r\nhello\r\n"
  |> test_err("Could not parse type symbol")
}

pub fn parse_type_no_type_symbol_test() {
  "\r\nhello\r\n"
  |> test_err("Could not parse type symbol")
}

//

pub fn parse_type_bulkstr_test() {
  "$5\r\nhello\r\n"
  |> test_ok(BulkStr("hello"))
}

pub fn parse_type_bulkstr_empty_test() {
  "$0\r\n\r\n"
  |> test_ok(BulkStr(""))
}

pub fn parse_type_bulkstr_with_double_digit_len_test() {
  "$10\r\nhelloworld\r\n"
  |> test_ok(BulkStr("helloworld"))
}

pub fn parse_type_bulkstr_with_newline_test() {
  "$11\r\nhello\nworld\r\n"
  |> test_ok(BulkStr("hello\nworld"))
}

pub fn parse_type_bulkstr_with_crlf_test() {
  "$11\r\nhello\r\nworld\r\n"
  |> test_ok(BulkStr("hello\r\nworld"))
}

pub fn parse_type_bulkstr_starting_with_crlf_test() {
  "$11\r\n\r\nhelloworld\r\n"
  |> test_ok(BulkStr("\r\nhelloworld"))
}

pub fn parse_type_bulkstr_ending_with_crlf_test() {
  "$11\r\nhelloworld\r\n\r\n"
  |> test_ok(BulkStr("helloworld\r\n"))
}

pub fn parse_type_bulkstr_with_some_numbers_test() {
  "$6\r\n0h3ll0\r\n"
  |> test_ok(BulkStr("0h3ll0"))
}

pub fn parse_type_bulkstr_with_all_numbers_test() {
  "$3\r\n123\r\n"
  |> test_ok(BulkStr("123"))
}

pub fn parse_type_bulkstr_no_length_test() {
  "$"
  |> test_err("Could not parse length of bulk string")
}

pub fn parse_type_bulkstr_no_text_test() {
  "$5\r\n\r\n"
  |> test_err("Could not parse bulk string of length " <> "5")
}

pub fn parse_type_bulkstr_content_less_than_len() {
  "$6\r\nhello\r\n"
  |> test_err("Could not parse bulk string of length " <> "6")
}

pub fn parse_type_bulkstr_content_greater_than_len() {
  "$4\r\nhello\r\n"
  |> test_err("Could not parse bulk string of length " <> "4")
}

//

pub fn parse_type_array_test() {
  "*2\r\n$5\r\nhello\r\n$5\r\nworld\r\n"
  |> test_ok(Array([BulkStr("hello"), BulkStr("world")]))
}

pub fn parse_type_array_empty_test() {
  "*0\r\n\r\n"
  |> test_ok(Array([]))
}

pub fn parse_type_array_nested_test() {
  "*2\r\n*1\r\n$5\r\nhello\r\n*1\r\n$5\r\nworld\r\n"
  |> test_ok(Array([Array([BulkStr("hello")]), Array([BulkStr("world")])]))
}

pub fn parse_type_array_no_length_test() {
  "*"
  |> test_err("Could not parse length of array")
}

fn test_ok(input, expected) {
  input
  |> string.to_graphemes
  |> resp.parse_type
  |> should.be_ok
  |> should.equal(expected)
}

fn test_err(input, expected) {
  input
  |> string.to_graphemes
  |> resp.parse_type
  |> should.be_error
  |> should.equal(expected)
}
