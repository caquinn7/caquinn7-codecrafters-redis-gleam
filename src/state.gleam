import cache.{type Cache}
import config.{type Config}
import gleam/dict
import gleam/io
import gleam/result
import rdb

pub opaque type State {
  State(cache: Cache, config: Config)
}

pub fn init(args: List(String)) {
  let config = config.init(args)
  // Start an ETS table, an in-memory key-value store which all the TCP
  // connection handling actors can read and write shares state to and from.
  let cache = init_cache(config)
  State(cache, config)
}

pub fn cache(state: State) -> Cache {
  state.cache
}

pub fn config(state: State) -> Config {
  state.config
}

fn init_cache(config: Config) -> Cache {
  let rdb_path = fn() {
    use dir <- result.try(dict.get(config, "dir"))
    use filename <- result.try(dict.get(config, "dbfilename"))
    Ok(dir <> "/" <> filename)
  }
  case rdb_path() {
    Error(_) -> cache.init()
    Ok(path) -> {
      let rdb_result = rdb.parse(path)
      case rdb_result {
        Ok(rdb) -> cache.from_rdb(rdb)
        Error(err) -> {
          io.debug("Error parsing rdb file at '" <> path <> "':")
          io.debug(err)
          cache.init()
        }
      }
    }
  }
}
