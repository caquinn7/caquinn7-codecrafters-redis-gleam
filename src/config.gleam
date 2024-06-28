import gleam/dict.{type Dict}
import gleam/list
import gleam/string

pub type Config =
  Dict(String, String)

pub fn init(args: List(String)) -> Config {
  let valid_config_parameters = ["dir", "dbfilename"]
  args
  |> args_to_dict
  |> dict.filter(fn(key, _) { list.contains(valid_config_parameters, key) })
}

fn args_to_dict(args: List(String)) -> Dict(String, String) {
  args
  |> list.sized_chunk(2)
  |> list.filter_map(fn(strs) {
    case strs {
      [s1, s2] -> {
        case string.starts_with(s1, "--") {
          True -> Ok(#(string.drop_left(s1, 2), s2))
          False -> Error(Nil)
        }
      }
      _ -> Error(Nil)
    }
  })
  |> dict.from_list
}
