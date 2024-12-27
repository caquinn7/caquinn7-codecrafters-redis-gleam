import gleam/dict.{type Dict}
import redis/cache.{type Cache}

pub type State {
  State(config: Dict(String, String), cache: Cache)
}

pub fn empty() {
  State(dict.new(), cache.new())
}
