import carpenter/table
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import resp.{type RespType, Array, BulkStr, SimpleStr}
import state.{type Item, type State, Item}

pub type Command {
  Echo(String)
  Get(String)
  Ping
  Set(String, String, Option(Int))
}

pub fn parse(input: String) -> Result(Command, String) {
  let chars = string.to_graphemes(input)
  use resp_value <- result.try(resp.parse_type(chars))
  use str_options <- result.try(unwrap_bulkstrs(resp_value))

  let assert Ok(cmd_str_option) = list.first(str_options)
  let assert Some(cmd_str) = option.or(cmd_str_option, Some(""))
  let rest = list.rest(str_options)

  case string.uppercase(cmd_str) {
    "ECHO" ->
      case rest {
        Ok([Some(s)]) -> Ok(Echo(s))
        Ok([None]) -> Error("invalid argument")
        _ -> Error("wrong number of arguments for command")
      }
    "GET" ->
      case rest {
        Ok([None]) -> Error("key cannot be null")
        Ok([Some(s)]) -> Ok(Get(s))
        _ -> Error("wrong number of arguments for command")
      }
    "PING" -> Ok(Ping)
    "SET" ->
      case rest {
        Ok([None, _, ..]) -> Error("key cannot be null")
        Ok([_, None, ..]) -> Error("value cannot be null")
        Ok([Some(k), Some(v)]) -> Ok(Set(k, v, None))
        Ok([Some(k), Some(v), Some(arg), Some(arg_val)]) ->
          case string.uppercase(arg) {
            "PX" -> {
              use millisecs <- result.try(result.replace_error(
                int.parse(arg_val),
                "value is not an integer or out of range",
              ))
              Ok(Set(k, v, Some(millisecs)))
            }
            _ -> Error("syntax error")
          }
        _ -> Error("syntax error")
      }
    _ -> Error("unknown command '" <> cmd_str <> "'")
  }
}

pub fn do_echo(to_echo: String, state: State) {
  #(resp.to_string(BulkStr(Some(to_echo))), state)
}

pub fn do_ping(state: State) {
  #(resp.to_string(SimpleStr("PONG")), state)
}

pub fn do_set(
  key: String,
  val: String,
  expiry: Option(Int),
  get_time: fn() -> Int,
  state: State,
) {
  let expires_at = option.map(expiry, fn(t) { get_time() + t })
  table.insert(state, [#(key, Item(val, expires_at))])
  #(resp.to_string(SimpleStr("OK")), state)
}

pub fn do_get(key: String, state: State, get_time: fn() -> Int) {
  case table.lookup(state, key) {
    [#(_, Item(val, exp))] -> {
      let now = get_time()
      case exp {
        None -> #(resp.to_string(BulkStr(Some(val))), state)
        Some(t) if now < t -> #(resp.to_string(BulkStr(Some(val))), state)
        _ -> {
          table.delete(state, key)
          #(resp.to_string(BulkStr(None)), state)
        }
      }
    }
    _ -> #(resp.to_string(BulkStr(None)), state)
  }
}

fn unwrap_bulkstrs(resp_value: RespType) {
  let err_msg = "input should be an array of bulk strings"

  use resp_values <- result.try(case resp_value {
    Array([v, ..vs]) -> Ok([v, ..vs])
    _ -> Error(err_msg)
  })

  let is_bulkstr = fn(v) {
    case v {
      BulkStr(_) -> True
      _ -> False
    }
  }
  let to_list = fn(arr) {
    arr
    |> list.map(fn(v) {
      let assert BulkStr(opt) = v
      opt
    })
  }
  case list.all(resp_values, is_bulkstr) {
    True ->
      resp_values
      |> to_list
      |> Ok
    False -> Error(err_msg)
  }
}
