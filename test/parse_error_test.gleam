import commands/parse_error.{
  InvalidArgument, InvalidCommand, Null, PostiveIntegerRequired, SyntaxError,
  WrongNumberOfArguments,
}
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn to_string_syntax_error_test() {
  SyntaxError
  |> parse_error.to_string
  |> should.equal("Syntax error")
}

pub fn to_string_invalid_command_test() {
  InvalidCommand("foo")
  |> parse_error.to_string
  |> should.equal("Invalid command: \"foo\"")
}

pub fn to_string_invalid_argument_null_test() {
  InvalidArgument("foo", Null)
  |> parse_error.to_string
  |> should.equal("Invalid value for \"foo\": Value cannot be null")
}

pub fn to_string_invalid_argument_positive_integer_required_test() {
  InvalidArgument("foo", PostiveIntegerRequired)
  |> parse_error.to_string
  |> should.equal("Invalid value for \"foo\": Value must be a postive integer")
}

pub fn parse_to_string_wrong_number_of_arguments_test() {
  WrongNumberOfArguments
  |> parse_error.to_string
  |> should.equal("Wrong number of arguments")
}
