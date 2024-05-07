import gleam/bool
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import resp.{type RespType, Array, BulkStr}

pub type Command {
  Echo(RespType)
  Get(RespType)
  Ping
  Set(RespType, RespType)
}

pub fn parse(input: String) -> Result(Command, String) {
  let chars = string.to_graphemes(input)
  use resp_value <- result.try(resp.parse_type(chars))

  let is_array = case resp_value {
    Array(_) -> True
    _ -> False
  }
  use <- bool.guard(
    when: !is_array,
    return: Error("input should be an array of bulk strings"),
  )

  let assert Array(resp_values) = resp_value
  let is_all_bulkstrs =
    list.all(resp_values, fn(v) {
      case v {
        BulkStr(_) -> True
        _ -> False
      }
    })

  use <- bool.guard(
    !is_all_bulkstrs,
    Error("input should be an array of bulk strings"),
  )

  let assert Ok(BulkStr(cmd_str_option)) = list.first(resp_values)
  let assert Some(cmd_str) = option.or(cmd_str_option, Some(""))
  case string.uppercase(cmd_str) {
    "ECHO" ->
      case list.rest(resp_values) {
        Ok([s]) -> Ok(Echo(s))
        _ -> Error("wrong number of arguments for command")
      }
    "GET" ->
      case list.rest(resp_values) {
        Ok([BulkStr(None)]) -> Error("key cannot be null")
        Ok([s]) -> Ok(Get(s))
        _ -> Error("wrong number of arguments for command")
      }
    "PING" -> Ok(Ping)
    "SET" ->
      case list.rest(resp_values) {
        Ok([BulkStr(None), _]) -> Error("key cannot be null")
        Ok([_, BulkStr(None)]) -> Error("value cannot be null")
        Ok([BulkStr(k), BulkStr(v)]) -> Ok(Set(BulkStr(k), BulkStr(v)))
        _ -> Error("wrong number of arguments for command")
      }
    _ -> Error("unknown command '" <> cmd_str <> "'")
  }
}
