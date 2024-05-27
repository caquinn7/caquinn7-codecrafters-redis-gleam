import gleam/int
import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import resp.{Array, BulkString, SimpleError, SimpleString}

pub fn main() {
  gleeunit.main()
}

// Simple String

pub fn encode_simple_string_test() {
  SimpleString("OK")
  |> resp.encode
  |> should.equal(<<"+OK\r\n":utf8>>)
}

pub fn encode_simple_string_empty_test() {
  SimpleString("")
  |> resp.encode
  |> should.equal(<<"+\r\n":utf8>>)
}

// Bulk String

pub fn encode_bulk_string_test() {
  BulkString(Some(<<"PING":utf8>>))
  |> resp.encode
  |> should.equal(<<"$4\r\nPING\r\n":utf8>>)
}

pub fn encode_bulk_string_null_test() {
  BulkString(None)
  |> resp.encode
  |> should.equal(<<"$-1\r\n":utf8>>)
}

pub fn encode_bulk_string_not_utf8_test() {
  let num = 1_232_837
  let bit_count = 128
  let byte_count = 128 / 8

  let expected = <<
    { "$" <> int.to_string(byte_count) <> "\r\n" }:utf8,
    num:size(bit_count),
    "\r\n":utf8,
  >>

  BulkString(Some(<<num:size(128)>>))
  |> resp.encode
  |> should.equal(expected)
}

// Simple Error

pub fn encode_simple_error_test() {
  SimpleError("Error")
  |> resp.encode
  |> should.equal(<<"-Error\r\n":utf8>>)
}

// Array

pub fn encode_array_test() {
  Array([BulkString(Some(<<"hello":utf8>>)), BulkString(Some(<<"world":utf8>>))])
  |> resp.encode
  |> should.equal(<<"*2\r\n$5\r\nhello\r\n$5\r\nworld\r\n":utf8>>)
}

pub fn encode_array_empty_test() {
  Array([])
  |> resp.encode
  |> should.equal(<<"*0\r\n":utf8>>)
}
