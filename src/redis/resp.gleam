import gleam/bit_array
import gleam/bytes_builder
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

pub type RespType {
  SimpleString(String)
  BulkString(Option(BitArray))
  SimpleError(String)
  Array(List(RespType))
}

pub type Parsed {
  Parsed(parsed: RespType, remaining: BitArray)
}

pub type ParseError {
  UnexpectedInput(BitArray)
  NotEnoughInput
  InvalidUnicode
}

pub fn encode(resp_value: RespType) {
  case resp_value {
    SimpleString(str) -> <<{ "+" <> str <> "\r\n" }:utf8>>
    BulkString(None) -> <<{ "$-1\r\n" }:utf8>>
    BulkString(Some(bits)) -> {
      let size = int.to_string(bit_array.byte_size(bits))
      <<"$":utf8, size:utf8, "\r\n":utf8, bits:bits, "\r\n":utf8>>
    }
    SimpleError(str) -> <<{ "-" <> str <> "\r\n" }:utf8>>
    Array(elements) -> {
      let encoded_elements =
        elements
        |> list.map(encode)
        |> bytes_builder.concat_bit_arrays

      let len = int.to_string(list.length(elements))
      let beginning = <<"*":utf8, len:utf8, "\r\n":utf8>>

      encoded_elements
      |> bytes_builder.prepend(beginning)
      |> bytes_builder.to_bit_array
    }
  }
}

pub fn parse(input: BitArray) -> Result(Parsed, ParseError) {
  case input {
    <<"+":utf8, rest:bits>> -> parse_simple_string(rest, <<>>)
    <<"$-1\r\n":utf8, rest:bits>> -> Ok(Parsed(BulkString(None), rest))
    <<"$":utf8, rest:bits>> -> parse_bulk_string(rest)
    <<"*":utf8, rest:bits>> -> parse_array(rest)
    input -> Error(UnexpectedInput(input))
  }
}

fn parse_array(input: BitArray) -> Result(Parsed, ParseError) {
  use #(len, input_after_len) <- result.try(parse_raw_int(input, 0))
  use #(elements, remaining) <- result.try(parse_array_elements(
    input_after_len,
    [],
    len,
  ))
  case list.length(elements) < len {
    False -> Ok(Parsed(Array(elements), remaining))
    True -> Error(NotEnoughInput)
  }
}

fn parse_array_elements(
  input: BitArray,
  elements: List(RespType),
  expected_len: Int,
) -> Result(#(List(RespType), BitArray), ParseError) {
  case expected_len == 0 {
    True -> Ok(#(list.reverse(elements), input))
    False -> {
      parse(input)
      |> result.map_error(fn(err) {
        case err {
          // expected more elements but nothing else to parse
          UnexpectedInput(<<>>) -> NotEnoughInput
          err -> err
        }
      })
      |> result.try(fn(parsed) {
        let Parsed(element, remaining) = parsed
        parse_array_elements(remaining, [element, ..elements], expected_len - 1)
      })
    }
  }
}

fn parse_simple_string(input: BitArray, consumed: BitArray) {
  case input {
    <<>> -> Error(NotEnoughInput)

    <<"\r\n":utf8, rest:bits>> ->
      case bit_array.to_string(consumed) {
        Ok(str) -> Ok(Parsed(SimpleString(str), rest))
        Error(_) -> Error(InvalidUnicode)
      }

    <<c, rest:bits>> ->
      case c {
        // LF and CR not allowed in simple string
        10 | 13 -> Error(UnexpectedInput(<<c>>))
        _ -> parse_simple_string(rest, <<consumed:bits, c>>)
      }

    input -> Error(UnexpectedInput(input))
  }
}

fn parse_bulk_string(input: BitArray) {
  // input after $<len>\r\n
  use #(content_len, input_after_len) <- result.try(parse_raw_int(input, 0))

  let total_len = bit_array.byte_size(input_after_len)
  let content = bit_array.slice(from: input_after_len, at: 0, take: content_len)
  let rest =
    bit_array.slice(input_after_len, content_len, total_len - content_len)

  case content, rest {
    _, Ok(<<>>) -> Error(NotEnoughInput)
    _, Ok(<<"\r":utf8>>) -> Error(NotEnoughInput)

    Ok(content), Ok(<<"\r\n":utf8, rest:bits>>) ->
      Ok(Parsed(BulkString(Some(content)), rest))

    _, Ok(rest) -> Error(UnexpectedInput(rest))
    Error(_), Error(_) -> Error(NotEnoughInput)
    _, _ -> Error(UnexpectedInput(input_after_len))
  }
}

fn parse_raw_int(input: BitArray, n: Int) {
  case input {
    <<"0":utf8, rest:bits>> -> parse_raw_int(rest, 0 + n * 10)
    <<"1":utf8, rest:bits>> -> parse_raw_int(rest, 1 + n * 10)
    <<"2":utf8, rest:bits>> -> parse_raw_int(rest, 2 + n * 10)
    <<"3":utf8, rest:bits>> -> parse_raw_int(rest, 3 + n * 10)
    <<"4":utf8, rest:bits>> -> parse_raw_int(rest, 4 + n * 10)
    <<"5":utf8, rest:bits>> -> parse_raw_int(rest, 5 + n * 10)
    <<"6":utf8, rest:bits>> -> parse_raw_int(rest, 6 + n * 10)
    <<"7":utf8, rest:bits>> -> parse_raw_int(rest, 7 + n * 10)
    <<"8":utf8, rest:bits>> -> parse_raw_int(rest, 8 + n * 10)
    <<"9":utf8, rest:bits>> -> parse_raw_int(rest, 9 + n * 10)
    <<"\r\n":utf8, rest:bits>> -> Ok(#(n, rest))
    <<"\r":utf8>> | <<>> -> Error(NotEnoughInput)
    _ -> Error(UnexpectedInput(input))
  }
}
