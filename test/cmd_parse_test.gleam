import cmd.{Echo, Get, Ping, Set}
import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import resp.{Array, BulkStr, SimpleStr}

pub fn main() {
  gleeunit.main()
}

pub fn parse_empty_input_test() {
  ""
  |> test_err("Input was empty")
}

pub fn parse_not_array_test() {
  BulkStr(Some("PING"))
  |> resp.to_string
  |> test_err("input should be an array of bulk strings")
}

pub fn parse_element_not_bulkstr_test() {
  Array([BulkStr(Some("PING")), SimpleStr("hi")])
  |> resp.to_string
  |> test_err("input should be an array of bulk strings")
}

//

pub fn parse_echo_test() {
  Array([BulkStr(Some("ECHO")), BulkStr(Some("hey"))])
  |> resp.to_string
  |> test_ok(Echo("hey"))
}

pub fn parse_echo_lowercase_test() {
  Array([BulkStr(Some("echo")), BulkStr(Some("hey"))])
  |> resp.to_string
  |> test_ok(Echo("hey"))
}

pub fn parse_echo_multiple_args_test() {
  Array([
    BulkStr(Some("ECHO")),
    BulkStr(Some("hey")),
    BulkStr(Some("shouldn't be here")),
  ])
  |> resp.to_string
  |> test_err("wrong number of arguments for command")
}

pub fn parse_echo_no_args_test() {
  Array([BulkStr(Some("ECHO"))])
  |> resp.to_string
  |> test_err("wrong number of arguments for command")
}

pub fn parse_echo_null_bulkstr_test() {
  Array([BulkStr(Some("ECHO")), BulkStr(None)])
  |> resp.to_string
  |> test_err("invalid argument")
}

//

pub fn parse_get_test() {
  Array([BulkStr(Some("GET")), BulkStr(Some("key"))])
  |> resp.to_string
  |> test_ok(Get("key"))
}

pub fn parse_get_null_key_test() {
  Array([BulkStr(Some("GET")), BulkStr(None)])
  |> resp.to_string
  |> test_err("key cannot be null")
}

pub fn parse_get_no_arg_test() {
  Array([BulkStr(Some("GET"))])
  |> resp.to_string
  |> test_err("wrong number of arguments for command")
}

pub fn parse_get_two_args_test() {
  Array([BulkStr(Some("GET")), BulkStr(Some("foo")), BulkStr(Some("bar"))])
  |> resp.to_string
  |> test_err("wrong number of arguments for command")
}

//

pub fn parse_ping_test() {
  Array([BulkStr(Some("PING"))])
  |> resp.to_string
  |> test_ok(Ping)
}

//

pub fn parse_set_test() {
  Array([BulkStr(Some("SET")), BulkStr(Some("foo")), BulkStr(Some("bar"))])
  |> resp.to_string
  |> test_ok(Set("foo", "bar", None))
}

pub fn parse_set_null_key_test() {
  Array([BulkStr(Some("SET")), BulkStr(None), BulkStr(Some("bar"))])
  |> resp.to_string
  |> test_err("key cannot be null")
}

pub fn parse_set_null_value_test() {
  Array([BulkStr(Some("SET")), BulkStr(Some("foo")), BulkStr(None)])
  |> resp.to_string
  |> test_err("value cannot be null")
}

pub fn parse_set_no_args_test() {
  Array([BulkStr(Some("SET"))])
  |> resp.to_string
  |> test_err("syntax error")
}

pub fn parse_set_invalid_arg_test() {
  Array([
    BulkStr(Some("SET")),
    BulkStr(Some("foo")),
    BulkStr(Some("bar")),
    BulkStr(Some("BAD")),
    BulkStr(Some("100")),
  ])
  |> resp.to_string
  |> test_err("syntax error")
}

pub fn parse_set_px_with_no_val_test() {
  Array([
    BulkStr(Some("SET")),
    BulkStr(Some("foo")),
    BulkStr(Some("bar")),
    BulkStr(Some("PX")),
  ])
  |> resp.to_string
  |> test_err("syntax error")
}

pub fn parse_set_px_with_null_val_test() {
  Array([
    BulkStr(Some("SET")),
    BulkStr(Some("foo")),
    BulkStr(Some("bar")),
    BulkStr(Some("PX")),
    BulkStr(None),
  ])
  |> resp.to_string
  |> test_err("syntax error")
}

pub fn parse_set_arg_none_with_val_test() {
  Array([
    BulkStr(Some("SET")),
    BulkStr(Some("foo")),
    BulkStr(Some("bar")),
    BulkStr(None),
    BulkStr(Some("100")),
  ])
  |> resp.to_string
  |> test_err("syntax error")
}

pub fn parse_set_px_with_non_integer_test() {
  Array([
    BulkStr(Some("SET")),
    BulkStr(Some("foo")),
    BulkStr(Some("bar")),
    BulkStr(Some("PX")),
    BulkStr(Some("not a number")),
  ])
  |> resp.to_string
  |> test_err("value is not an integer or out of range")
}

pub fn parse_set_px_test() {
  Array([
    BulkStr(Some("SET")),
    BulkStr(Some("foo")),
    BulkStr(Some("bar")),
    BulkStr(Some("PX")),
    BulkStr(Some("100")),
  ])
  |> resp.to_string
  |> test_ok(Set("foo", "bar", Some(100)))
}

//

pub fn parse_invalid_cmd_test() {
  let cmd = "blah"
  Array([BulkStr(Some("blah"))])
  |> resp.to_string()
  |> test_err("unknown command '" <> cmd <> "'")
}

pub fn parse_invalid_cmd_null_bulkstr_test() {
  Array([BulkStr(None)])
  |> resp.to_string()
  |> test_err("unknown command ''")
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
