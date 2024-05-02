import cmd.{type ParseErr, Echo, ParseErr}
import gleeunit
import gleeunit/should
import resp.{Array, BulkStr}

pub fn main() {
  gleeunit.main()
}

pub fn parse_empty_input_test() {
  ""
  |> test_err(ParseErr("", "Input was empty"))
}

pub fn parse_not_array_test() {
  let input =
    BulkStr("hi")
    |> resp.to_string
  input
  |> test_err(ParseErr(input, "Input should be an array of bulk strings"))
}

// pub fn parse_element_not_bulkstr() {

// }

pub fn parse_echo_test() {
  let input =
    Array([BulkStr("echo"), BulkStr("hey")])
    |> resp.to_string
  input
  |> test_ok(Echo("hey"))
}

pub fn parse_echo_uppercase_test() {
  let input =
    Array([BulkStr("ECHO"), BulkStr("hey")])
    |> resp.to_string
  input
  |> test_ok(Echo("hey"))
}

pub fn parse_echo_multiple_args_test() {
  let input =
    Array([BulkStr("echo"), BulkStr("hey"), BulkStr("ignore this")])
    |> resp.to_string
  input
  |> test_ok(Echo("hey"))
}

pub fn parse_echo_no_args_test() {
  let input =
    Array([BulkStr("echo")])
    |> resp.to_string
  input
  |> test_ok(Echo(""))
}

pub fn parse_invalid_cmd_test() {
  let input =
    Array([BulkStr("blah")])
    |> resp.to_string()
  input
  |> test_err(ParseErr(input, "Did not find a valid command"))
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
