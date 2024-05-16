import carpenter/table
import gleam/bool
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

pub fn execute(cmd: Command, state: State, get_time: fn() -> Int) -> RespType {
  case cmd {
    Ping -> SimpleStr("PONG")
    Echo(str) -> BulkStr(Some(str))
    Get(key) -> get(key, state, get_time)
    Set(key, val, life_time) -> set(key, val, life_time, state, get_time)
  }
}

fn set(
  key: String,
  val: String,
  life_time: Option(Int),
  state: State,
  get_time: fn() -> Int,
) {
  let expires_at = option.map(life_time, fn(t) { get_time() + t })
  table.insert(state, [#(key, Item(val, expires_at))])
  SimpleStr("OK")
}

fn get(key: String, state: State, get_time: fn() -> Int) {
  let vals = table.lookup(state, key)
  use <- bool.guard(when: list.is_empty(vals), return: BulkStr(None))

  let assert [#(_, Item(val, expires_at))] = vals
  let now = get_time()
  case expires_at {
    None -> BulkStr(Some(val))
    Some(t) if now < t -> BulkStr(Some(val))
    _ -> {
      table.delete(state, key)
      BulkStr(None)
    }
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
