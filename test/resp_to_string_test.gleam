import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import resp.{Array, BulkStr, SimpleErr, SimpleStr}

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

//

pub fn to_string_bulkstr_test() {
  BulkStr(Some("hello"))
  |> test_ok("$5\r\nhello\r\n")
}

pub fn to_string_bulkstr_empty_test() {
  BulkStr(Some(""))
  |> test_ok("$0\r\n\r\n")
}

pub fn to_string_bulkstr_null_test() {
  BulkStr(None)
  |> test_ok("$-1\r\n")
}

//

pub fn to_string_simpleerr_test() {
  SimpleErr("error")
  |> test_ok("-error\r\n")
}

//

pub fn to_string_array_test() {
  Array([BulkStr(Some("hello")), BulkStr(Some("world"))])
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
