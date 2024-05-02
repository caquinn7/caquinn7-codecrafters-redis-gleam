import gleam/list
import gleam/result
import gleam/string
import resp.{type RespType, Array, BulkStr}

pub type Command {
  Echo(RespType)
}

pub type ParseErr {
  ParseErr(input: String, err: String)
}

pub fn parse(input: String) -> Result(Command, ParseErr) {
  let chars = string.to_graphemes(input)
  use resp_value <- result.try(
    result.map_error(resp.parse_type(chars), fn(err) { ParseErr(input, err) }),
  )
  use array <- result.try(case resp_value {
    Array(elements) ->
      case resp.is_bulkstr_array(Array(elements)) {
        True -> Ok(Array(elements))
        False ->
          Error(ParseErr(input, "Input should be an array of bulk strings"))
      }
    _ -> Error(ParseErr(input, "Input should be an array of bulk strings"))
  })

  let assert Array(bulkstrs) = array
  // let strs =
  //   list.map(bulkstrs, fn(b) {
  //     let assert BulkStr(s) = b
  //     s
  //   })

  let assert Ok(BulkStr(cmd_str)) = list.first(bulkstrs)

  case string.lowercase(cmd_str) {
    "echo" ->
      case list.rest(bulkstrs) {
        Ok([s]) | Ok([s, ..]) -> Ok(Echo(s))
        _ -> Ok(Echo(BulkStr("")))
      }
    _ -> Error(ParseErr(input, "Did not find a valid command"))
  }
  // todo
}
