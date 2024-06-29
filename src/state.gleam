import cache.{type Cache}
import gleam/dict.{type Dict}

pub type State {
  State(config: Dict(String, String), cache: Cache)
}

pub fn empty() {
  State(dict.new(), cache.new())
}
