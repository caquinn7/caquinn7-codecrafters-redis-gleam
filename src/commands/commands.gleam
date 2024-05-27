import binary_utils
import cache.{type Cache, type Item, Item}
import commands/parse_error.{
  type ParseError, InvalidArgument, InvalidCommand, Null, PostiveIntegerRequired,
  SyntaxError, WrongNumberOfArguments,
}
import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import resp.{type RespType, Array, BulkString, Parsed, SimpleString}

pub type Command {
  Ping
  Echo(BitArray)
  Set(BitArray, BitArray, Option(Int))
  Get(BitArray)
  ConfigSet(Dict(String, String))
  ConfigGet(List(String))
}

pub fn parse(input: BitArray) -> Result(Command, ParseError) {
  use bit_arrays <- result.try(validate_input(input))
  let assert [Some(first), ..rest] = bit_arrays
  use cmd <- result.try(parse_utf8(first))
  case string.uppercase(cmd) {
    "PING" ->
      case rest {
        [] -> Ok(Ping)
        _ -> Error(WrongNumberOfArguments)
      }
    "ECHO" ->
      case rest {
        [Some(bits)] -> Ok(Echo(bits))
        [None] -> Error(InvalidArgument("message", Null))
        _ -> Error(WrongNumberOfArguments)
      }
    "SET" ->
      case rest {
        [None, _, ..] -> Error(InvalidArgument("key", Null))
        [_, None, ..] -> Error(InvalidArgument("value", Null))
        [Some(key), Some(val)] -> Ok(Set(key, val, None))
        [Some(key), Some(val), Some(arg), Some(arg_val)] -> {
          case arg {
            <<"PX":utf8>> | <<"px":utf8>> -> {
              use millisecs <- result.try(parse_positive_int(arg_val, "PX"))
              Ok(Set(key, val, Some(millisecs)))
            }
            _ -> Error(SyntaxError)
          }
        }
        _ -> Error(SyntaxError)
      }
    "GET" ->
      case rest {
        [Some(bits)] -> Ok(Get(bits))
        [None] -> Error(InvalidArgument("key", Null))
        _ -> Error(WrongNumberOfArguments)
      }
    "CONFIG" -> parse_config_command(rest)
    _ -> Error(InvalidCommand(cmd))
  }
}

pub fn execute(cmd: Command, cache: Cache, get_time: fn() -> Int) -> RespType {
  case cmd {
    Ping -> SimpleString("PONG")
    Echo(msg) -> BulkString(Some(msg))
    Get(key) -> get(key, cache, get_time)
    Set(key, val, life_time) -> set(key, val, life_time, cache, get_time)
    ConfigSet(pairs) -> config_set(pairs, cache, get_time)
    ConfigGet(keys) -> config_get(keys, cache, get_time)
  }
}

fn parse_config_command(bit_arrays: List(Option(BitArray))) {
  use args <- result.try(
    bit_arrays
    |> option.all
    |> option.unwrap([])
    |> list.map(parse_utf8)
    |> result.all,
  )
  case args {
    [] -> Error(WrongNumberOfArguments)
    [subcommand, ..rest] -> {
      case string.uppercase(subcommand) {
        "GET" ->
          case rest {
            [] -> Error(WrongNumberOfArguments)
            [_, ..] -> Ok(ConfigGet(rest))
          }
        _ -> Error(SyntaxError)
      }
    }
  }
}

fn set(
  key: BitArray,
  val: BitArray,
  life_time: Option(Int),
  cache: Cache,
  get_time: fn() -> Int,
) {
  let expires_at = option.map(life_time, fn(time) { get_time() + time })
  cache.set(cache, key, Item(val, expires_at))
  SimpleString("OK")
}

fn get(key: BitArray, cache: Cache, get_time: fn() -> Int) -> RespType {
  case cache.get(cache, key) {
    Error(_) -> BulkString(None)
    Ok(Item(val, expires_at)) -> {
      let now = get_time()
      case expires_at {
        None -> BulkString(Some(val))
        Some(time) if now < time -> BulkString(Some(val))
        _ -> {
          cache.remove(cache, key)
          BulkString(None)
        }
      }
    }
  }
}

fn config_set(pairs: Dict(String, String), cache: Cache, get_time: fn() -> Int) {
  let to_set_cmd = fn(pair: #(String, String)) {
    let key = <<{ "config:" <> pair.0 }:utf8>>
    Set(key, <<{ pair.1 }:utf8>>, None)
  }
  pairs
  |> dict.to_list
  |> list.map(to_set_cmd)
  |> list.map(execute(_, cache, get_time))
  SimpleString("OK")
}

fn config_get(keys: List(String), cache: Cache, get_time: fn() -> Int) {
  keys
  |> list.flat_map(fn(key) {
    let cmd = Get(<<{ "config:" <> key }:utf8>>)
    let resp_val = execute(cmd, cache, get_time)
    [BulkString(Some(<<key:utf8>>)), resp_val]
  })
  |> fn(resp_vals) { Array(resp_vals) }
}

fn validate_input(input: BitArray) {
  let validate_resp =
    input
    |> resp.parse
    |> result.replace_error(SyntaxError)

  use Parsed(resp_value, _) <- result.try(validate_resp)

  let validate_not_empty = fn(elements) {
    case list.is_empty(elements) {
      True -> Error(SyntaxError)
      False -> Ok(elements)
    }
  }

  let validate_first_is_not_none = fn(elements) {
    case elements {
      [Some(_), ..] -> Ok(elements)
      _ -> Error(SyntaxError)
    }
  }

  resp_value
  |> unwrap_bulk_strings
  |> result.try(validate_not_empty)
  |> result.try(validate_first_is_not_none)
}

fn unwrap_bulk_strings(resp_value: RespType) {
  use resp_values <- result.try(case resp_value {
    Array([v, ..vs]) -> Ok([v, ..vs])
    _ -> Error(SyntaxError)
  })

  let is_bulk_string = fn(v) {
    case v {
      BulkString(_) -> True
      _ -> False
    }
  }
  let to_bulk_string_list = fn(arr) {
    arr
    |> list.map(fn(v) {
      let assert BulkString(opt) = v
      opt
    })
  }
  case list.all(resp_values, is_bulk_string) {
    True ->
      resp_values
      |> to_bulk_string_list
      |> Ok
    False -> Error(SyntaxError)
  }
}

fn parse_utf8(bits: BitArray) {
  bits
  |> bit_array.to_string
  |> result.replace_error(SyntaxError)
}

fn parse_positive_int(bits: BitArray, arg_name: String) {
  bits
  |> binary_utils.binary_to_int
  |> result.unwrap(0)
  |> fn(i) {
    case i > 1 {
      True -> Ok(i)
      False -> Error(InvalidArgument(arg_name, PostiveIntegerRequired))
    }
  }
}
