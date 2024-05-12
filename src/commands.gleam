import context.{type Context, type Item, Context, Item}
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import resp.{type RespType, Array, BulkStr, SimpleStr}

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

pub fn do_echo(to_echo: String, ctx: Context) {
  #(resp.to_string(BulkStr(Some(to_echo))), ctx)
}

pub fn do_ping(ctx: Context) {
  #(resp.to_string(SimpleStr("PONG")), ctx)
}

pub fn do_set(
  key: String,
  val: String,
  expiry: Option(Int),
  get_time: fn() -> Int,
  ctx: Context,
) {
  let new_state =
    dict.update(ctx.state, key, fn(_) {
      let expires_at = option.map(expiry, fn(t) { get_time() + t })
      Item(val, expires_at)
    })
  #(resp.to_string(SimpleStr("OK")), Context(new_state))
}

pub fn do_get(key: String, ctx: Context, get_time: fn() -> Int) {
  case dict.get(ctx.state, key) {
    Error(_) -> #(resp.to_string(BulkStr(None)), ctx)
    Ok(Item(val, exp)) -> {
      let now = get_time()
      case exp {
        None -> #(resp.to_string(BulkStr(Some(val))), ctx)
        Some(t) if now < t -> #(resp.to_string(BulkStr(Some(val))), ctx)
        _ -> #(
          resp.to_string(BulkStr(None)),
          Context(dict.delete(ctx.state, key)),
        )
      }
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
