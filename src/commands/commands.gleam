import binary_utils
import cache.{type Cache, type Item, Item}
import commands/parse_error.{
  type ParseError, InvalidArgument, InvalidCommand, NotImplemented, Null,
  PostiveIntegerRequired, SyntaxError, WrongNumberOfArguments,
}
import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import resp.{type RespType, Array, BulkString, Parsed, SimpleString}
import state.{type State}

pub type Command {
  Ping
  Echo(BitArray)
  Set(BitArray, BitArray, Option(Int))
  Get(BitArray)
  ConfigGet(List(String))
  Keys(String)
}

pub fn parse(input: BitArray) -> Result(Command, ParseError) {
  use bit_arrays <- result.try(validate_input(input))
  let assert [Some(first), ..rest] = bit_arrays
  use cmd <- result.try(parse_utf8(first))
  case string.uppercase(cmd) {
    "PING" -> parse_ping(rest)
    "ECHO" -> parse_echo(rest)
    "SET" -> parse_set(rest)
    "GET" -> parse_get(rest)
    "CONFIG" -> parse_config(rest)
    "KEYS" -> parse_keys(rest)
    _ -> Error(InvalidCommand(cmd))
  }
}

pub fn execute(cmd: Command, state: State, get_time: fn() -> Int) -> RespType {
  case cmd {
    Ping -> SimpleString("PONG")
    Echo(msg) -> BulkString(Some(msg))
    Set(key, val, life_time) -> set(key, val, life_time, state.cache, get_time)
    Get(key) -> get(key, state.cache, get_time)
    ConfigGet(keys) -> config_get(keys, state.config)
    Keys(pattern) -> keys(pattern, state.cache)
  }
}

fn parse_ping(bit_array_options) {
  case bit_array_options {
    [] -> Ok(Ping)
    _ -> Error(WrongNumberOfArguments)
  }
}

fn parse_echo(bit_array_options) {
  case bit_array_options {
    [Some(bits)] -> Ok(Echo(bits))
    [None] -> Error(InvalidArgument("message", Null))
    _ -> Error(WrongNumberOfArguments)
  }
}

fn parse_get(bit_array_options) {
  case bit_array_options {
    [Some(bits)] -> Ok(Get(bits))
    [None] -> Error(InvalidArgument("key", Null))
    _ -> Error(WrongNumberOfArguments)
  }
}

fn parse_set(bit_array_options) {
  case bit_array_options {
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
}

fn parse_config(bit_array_options) {
  use bit_arrays <- result.try(
    bit_array_options
    |> option.all
    |> option.to_result(SyntaxError),
  )
  use args <- result.try(
    bit_arrays
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

fn parse_keys(bit_array_options: List(Option(BitArray))) {
  case bit_array_options {
    [] | [_, _, ..] -> Error(WrongNumberOfArguments)
    [None] -> Error(InvalidArgument("pattern", Null))
    [Some(pattern)] -> {
      use pattern_str <- result.try(
        pattern
        |> bit_array.to_string
        |> result.replace_error(SyntaxError),
      )
      case pattern_str {
        "*" -> Ok(Keys(pattern_str))
        _ -> Error(NotImplemented("Only wildcard (\"*\") pattern is supported"))
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

fn get(key: BitArray, cache: Cache, get_time: fn() -> Int) {
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

fn config_get(keys: List(String), config: Dict(String, String)) {
  keys
  |> list.filter_map(fn(key) {
    result.map(dict.get(config, key), fn(val) { [key, val] })
  })
  |> list.flatten
  |> list.map(fn(str) {
    str
    |> bit_array.from_string
    |> Some
    |> BulkString
  })
  |> Array
}

fn keys(_pattern: String, cache: Cache) {
  cache
  |> cache.get_keys
  |> list.map(fn(key) { BulkString(Some(key)) })
  |> Array
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
