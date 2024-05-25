pub type InvalidArgumentReason {
  Null
  PostiveIntegerRequired
}

pub type ParseError {
  SyntaxError
  InvalidCommand(command: String)
  InvalidArgument(name: String, reason: InvalidArgumentReason)
  WrongNumberOfArguments
}

pub fn to_string(parse_err: ParseError) {
  case parse_err {
    SyntaxError -> "Syntax error"
    InvalidCommand(cmd) -> "Invalid command: \"" <> cmd <> "\""
    InvalidArgument(name, reason) -> {
      let reason_str = case reason {
        Null -> "Value cannot be null"
        PostiveIntegerRequired -> "Value must be a postive integer"
      }
      "Invalid value for \"" <> name <> "\": " <> reason_str
    }
    WrongNumberOfArguments -> "Wrong number of arguments"
  }
}
