import gleam/bool
import gleam/list
import gleam/result
import gleam/string
import resp.{type RespType, Array, BulkStr}

pub type Command {
  Echo(RespType)
  Ping
}

pub type ParseErr {
  ParseErr(err: String)
}

pub fn parse(input: String) -> Result(Command, ParseErr) {
  let chars = string.to_graphemes(input)
  use resp_value <- result.try(
    result.map_error(resp.parse_type(chars), fn(err) { ParseErr(err) }),
  )

  let is_array = case resp_value {
    Array(_) -> False
    _ -> True
  }
  use <- bool.guard(
    is_array,
    Error(ParseErr("Input should be an array of bulk strings")),
  )

  let assert Array(resp_values) = resp_value
  let all_bulkstrs =
    list.all(resp_values, fn(v) {
      case v {
        BulkStr(_) -> True
        _ -> False
      }
    })

  use <- bool.guard(
    !all_bulkstrs,
    Error(ParseErr("Input should be an array of bulk strings")),
  )

  let assert Ok(BulkStr(cmd_str)) = list.first(resp_values)
  case string.uppercase(cmd_str) {
    "ECHO" ->
      case list.rest(resp_values) {
        Ok([s]) | Ok([s, ..]) -> Ok(Echo(s))
        _ -> Ok(Echo(BulkStr("")))
      }
    "PING" -> Ok(Ping)
    _ -> Error(ParseErr("Did not find a valid command"))
  }
}
