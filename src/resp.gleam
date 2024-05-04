import gleam/int
import gleam/list
import gleam/result
import gleam/string

const crlf = "\r\n"

const dollar_sign = "$"

const asterisk = "*"

const plus = "+"

const minus = "-"

pub type RespType {
  // +<string>\r\n
  SimpleStr(String)
  // $<length>\r\n<string>\r\n 
  BulkStr(String)
  // -Error message\r\n
  SimpleErr(String)
  // *<number-of-elements>\r\n<element-1>...<element-n>
  Array(List(RespType))
}

pub fn to_string(t: RespType) {
  case t {
    SimpleStr(str) -> plus <> str <> crlf
    BulkStr(str) ->
      dollar_sign <> int.to_string(string.length(str)) <> crlf <> str <> crlf
    SimpleErr(str) -> minus <> str <> crlf
    Array(elements) -> {
      asterisk
      <> int.to_string(list.length(elements))
      <> crlf
      <> string.join(list.map(elements, to_string), "")
    }
  }
}

pub fn parse_type(chars: List(String)) -> Result(RespType, String) {
  use type_symbol <- result.try(result.replace_error(
    list.first(chars),
    "Input was empty",
  ))
  let rest = list.drop(chars, 1)
  case type_symbol {
    s if s == asterisk -> parse_array(rest)
    s if s == plus -> parse_simplestr(rest)
    s if s == dollar_sign -> parse_bulkstr(rest)
    _ -> Error("Could not parse type symbol")
  }
}

fn parse_array(chars: List(String)) -> Result(RespType, String) {
  let digits = list.take_while(chars, fn(c) { c != crlf })
  use len <- result.try(result.replace_error(
    int.parse(string.join(digits, "")),
    "Could not parse length of array",
  ))
  let rest = list.drop(chars, list.length(digits) + 1)
  use elements <- result.map(parse_array_elements(rest, len, []))
  Array(list.reverse(elements))
}

fn parse_array_elements(
  chars: List(String),
  expected_len: Int,
  elements: List(RespType),
) -> Result(List(RespType), String) {
  case expected_len == 0 {
    True -> Ok(elements)
    False -> {
      use element <- result.try(parse_type(chars))
      let consumed_chars_count =
        element
        |> to_string
        |> string.length
      let rest = list.drop(chars, consumed_chars_count)
      parse_array_elements(rest, expected_len - 1, [element, ..elements])
    }
  }
}

fn parse_bulkstr(chars: List(String)) -> Result(RespType, String) {
  let digits = list.take_while(chars, fn(c) { c != crlf })
  use len <- result.try(result.replace_error(
    int.parse(string.join(digits, "")),
    "Could not parse length of bulk string",
  ))

  let remaining_chars = list.drop(chars, list.length(digits) + 1)
  let content_chars = list.take(remaining_chars, len)

  use content <- result.try(case list.length(content_chars) == len {
    True -> Ok(string.join(content_chars, ""))
    False ->
      Error("Could not parse bulk string of length " <> int.to_string(len))
  })

  let terminator =
    remaining_chars
    |> list.drop(len)
    |> list.first

  case terminator {
    Ok(s) if s == crlf -> Ok(BulkStr(content))
    _ -> Error("Unterminated bulk string")
  }
}

fn parse_simplestr(chars: List(String)) -> Result(RespType, String) {
  let content_chars = list.take_while(chars, fn(c) { c != crlf })

  let is_invalid_char = fn(c) { c == "\r" || c == "\n" }
  let has_invalid_chars = case list.any(content_chars, is_invalid_char) {
    False -> Ok(Nil)
    True ->
      Error(
        "Simple strings cannot contain carriage return or line feed characters",
      )
  }
  use _ <- result.try(has_invalid_chars)

  let terminator =
    chars
    |> list.drop(list.length(content_chars))
    |> list.first

  case terminator {
    Ok(s) if s == crlf -> Ok(SimpleStr(string.join(content_chars, "")))
    _ -> Error("Unterminated simple string")
  }
}
