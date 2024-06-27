import cache.{type Cache}
import gleam/dict.{type Dict}

pub type Config =
  Dict(String, String)

pub type State {
  State(cache: Cache, config: Config)
}
