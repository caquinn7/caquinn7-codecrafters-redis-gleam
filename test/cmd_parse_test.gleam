import cmd.{type ParseErr, Echo, ParseErr, Ping}
import gleam/option.{Some}
import gleeunit
import gleeunit/should
import resp.{Array, BulkStr, SimpleStr}

pub fn main() {
  gleeunit.main()
}

pub fn parse_empty_input_test() {
  ""
  |> test_err(ParseErr("Input was empty"))
}

pub fn parse_not_array_test() {
  BulkStr(Some("hi"))
  |> resp.to_string
  |> test_err(ParseErr("Input should be an array of bulk strings"))
}

pub fn parse_element_not_bulkstr_test() {
  Array([BulkStr(Some("hi")), SimpleStr("hi")])
  |> resp.to_string
  |> test_err(ParseErr("Input should be an array of bulk strings"))
}

pub fn parse_ping_test() {
  Array([BulkStr(Some("ping"))])
  |> resp.to_string
  |> test_ok(Ping)
}

pub fn parse_echo_test() {
  Array([BulkStr(Some("ECHO")), BulkStr(Some("hey"))])
  |> resp.to_string
  |> test_ok(Echo(BulkStr(Some("hey"))))
}

pub fn parse_echo_lowercase_test() {
  Array([BulkStr(Some("echo")), BulkStr(Some("hey"))])
  |> resp.to_string
  |> test_ok(Echo(BulkStr(Some("hey"))))
}

pub fn parse_echo_multiple_args_test() {
  Array([
    BulkStr(Some("echo")),
    BulkStr(Some("hey")),
    BulkStr(Some("ignore this")),
  ])
  |> resp.to_string
  |> test_ok(Echo(BulkStr(Some("hey"))))
}

pub fn parse_echo_no_args_test() {
  Array([BulkStr(Some("echo"))])
  |> resp.to_string
  |> test_ok(Echo(BulkStr(Some(""))))
}

pub fn parse_invalid_cmd_test() {
  Array([BulkStr(Some("blah"))])
  |> resp.to_string()
  |> test_err(ParseErr("Did not find a valid command"))
}

fn test_ok(input, expected) {
  input
  |> cmd.parse
  |> should.be_ok
  |> should.equal(expected)
}

fn test_err(input, expected) {
  input
  |> cmd.parse
  |> should.be_error
  |> should.equal(expected)
}
