import gleeunit
import gleeunit/should
import resp.{Array, BulkStr, SimpleStr}

pub fn main() {
  gleeunit.main()
}

pub fn to_string_simplestr_test() {
  SimpleStr("OK")
  |> test_ok("+OK\r\n")
}

pub fn to_string_simplestr_empty_test() {
  SimpleStr("")
  |> test_ok("+\r\n")
}

pub fn to_string_bulkstr_test() {
  BulkStr("hello")
  |> test_ok("$5\r\nhello\r\n")
}

pub fn to_string_bulkstr_empty_test() {
  BulkStr("")
  |> test_ok("$0\r\n\r\n")
}

pub fn to_string_array_test() {
  Array([BulkStr("hello"), BulkStr("world")])
  |> test_ok("*2\r\n$5\r\nhello\r\n$5\r\nworld\r\n")
}

pub fn to_string_array_empty_test() {
  Array([])
  |> test_ok("*0\r\n")
}

fn test_ok(input, expected) {
  input
  |> resp.to_string
  |> should.equal(expected)
}
