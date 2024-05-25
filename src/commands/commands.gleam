import binary_utils
import carpenter/table
import commands/parse_error.{
  type ParseError, InvalidArgument, InvalidCommand, Null, PostiveIntegerRequired,
  SyntaxError, WrongNumberOfArguments,
}
import gleam/bit_array
import gleam/bool
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import resp.{type RespType, Array, BulkString, Parsed, SimpleString}
import state.{type Item, type State, Item}

pub type Command {
  Echo(BitArray)
  Get(BitArray)
  Ping
  Set(BitArray, BitArray, Option(Int))
}

pub fn parse(input: BitArray) -> Result(Command, ParseError) {
  use #(cmd, rest) <- result.try(validate_input(input))
  case string.uppercase(cmd) {
    "ECHO" ->
      case rest {
        [Some(bits)] -> Ok(Echo(bits))
        [None] -> Error(InvalidArgument("message", Null))
        _ -> Error(WrongNumberOfArguments)
      }
    "PING" ->
      case rest {
        [] -> Ok(Ping)
        _ -> Error(WrongNumberOfArguments)
      }
    "GET" ->
      case rest {
        [Some(bits)] -> Ok(Get(bits))
        [None] -> Error(InvalidArgument("key", Null))
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
              use millisecs <- result.try(result.replace_error(
                parse_positive_int(arg_val),
                InvalidArgument("PX", PostiveIntegerRequired),
              ))
              Ok(Set(key, val, Some(millisecs)))
            }
            _ -> Error(SyntaxError)
          }
        }
        _ -> Error(SyntaxError)
      }
    _ -> Error(InvalidCommand(cmd))
  }
}

pub fn execute(cmd: Command, state: State, get_time: fn() -> Int) -> RespType {
  case cmd {
    Ping -> SimpleString("PONG")
    Echo(msg) -> BulkString(Some(msg))
    Get(key) -> get(key, state, get_time)
    Set(key, val, life_time) -> set(key, val, life_time, state, get_time)
  }
}

fn set(
  key: BitArray,
  val: BitArray,
  life_time: Option(Int),
  state: State,
  get_time: fn() -> Int,
) {
  let expires_at = option.map(life_time, fn(t) { get_time() + t })
  table.insert(state, [#(key, Item(val, expires_at))])
  SimpleString("OK")
}

fn get(key: BitArray, state: State, get_time: fn() -> Int) {
  let vals = table.lookup(state, key)
  use <- bool.guard(when: list.is_empty(vals), return: BulkString(None))

  let assert [#(_, Item(val, expires_at))] = vals
  let now = get_time()
  case expires_at {
    None -> BulkString(Some(val))
    Some(t) if now < t -> BulkString(Some(val))
    _ -> {
      table.delete(state, key)
      BulkString(None)
    }
  }
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

  let validate_first_element_is_utf8 = fn(elements) {
    case elements {
      [Some(element), ..rest] ->
        case bit_array.to_string(element) {
          Ok(s) -> Ok(#(s, rest))
          Error(_) -> Error(SyntaxError)
        }
      _ -> Error(SyntaxError)
    }
  }

  resp_value
  |> unwrap_bulk_strings
  |> result.replace_error(SyntaxError)
  |> result.try(validate_not_empty)
  |> result.try(validate_first_element_is_utf8)
}

fn unwrap_bulk_strings(resp_value: RespType) {
  use resp_values <- result.try(case resp_value {
    Array([v, ..vs]) -> Ok([v, ..vs])
    _ -> Error(Nil)
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
    False -> Error(Nil)
  }
}

fn parse_positive_int(bits: BitArray) {
  use i <- result.try(binary_utils.binary_to_int(bits))
  case i > 1 {
    True -> Ok(i)
    False -> Error(Nil)
  }
}
