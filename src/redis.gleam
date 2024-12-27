import argv
import gleam/bytes_builder
import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/io
import gleam/list
import gleam/option.{None}
import gleam/otp/actor
import gleam/result
import gleam/string
import glisten.{Packet}
import redis/cache.{type Cache}
import redis/commands/commands
import redis/commands/parse_error
import redis/rdb
import redis/resp.{SimpleError}
import redis/state.{type State, State}
import redis/time

pub fn main() {
  let config = args_to_dict(argv.load().arguments)
  // Start an ETS table, an in-memory key-value store which all the TCP
  // connection handling actors can read and write shares state to and from.
  let cache = init_cache(config)
  let state = State(config, cache)

  // Start the TCP acceptor pool.
  // Each connection will get its own actor to handle Redis requests.
  let assert Ok(_) =
    glisten.handler(fn(_conn) { #(state, None) }, loop)
    |> glisten.serve(6379)

  // Suspend the main process while the acceptor pool works.
  process.sleep_forever()
}

fn loop(msg, state: State, conn) {
  let assert Packet(msg_bits) = msg
  let response = process_msg(msg_bits, state)
  let assert Ok(_) = glisten.send(conn, bytes_builder.from_bit_array(response))
  actor.continue(state)
}

fn process_msg(msg: BitArray, state: State) {
  let response = case commands.parse(msg) {
    Ok(cmd) -> commands.execute(cmd, state, time.now)
    Error(err) -> {
      let msg = parse_error.to_string(err)
      SimpleError("ERR " <> msg)
    }
  }
  resp.encode(response)
}

fn args_to_dict(args: List(String)) {
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

fn init_cache(config: Dict(String, String)) -> Cache {
  let rdb_path = fn() {
    use dir <- result.try(dict.get(config, "dir"))
    use filename <- result.try(dict.get(config, "dbfilename"))
    Ok(dir <> "/" <> filename)
  }
  case rdb_path() {
    Error(_) -> cache.new()
    Ok(path) -> {
      let rdb_result = rdb.parse(path)
      case rdb_result {
        Ok(rdb) -> cache.from_rdb(rdb)
        Error(err) -> {
          io.debug("Error parsing rdb file at '" <> path <> "':")
          io.debug(err)
          cache.new()
        }
      }
    }
  }
}
