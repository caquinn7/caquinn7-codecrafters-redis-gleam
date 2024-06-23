import argv
import cache.{type Cache}
import commands/commands
import commands/parse_error
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
import rdb
import resp.{SimpleError}
import time

pub fn main() {
  let args = args_to_dict(argv.load().arguments)

  // Start an ETS table, an in-memory key-value store which all the TCP
  // connection handling actors can read and write shares state to and from.
  let cache = init_cache(args)

  // Store config settings passed as cli args on startup
  args
  |> commands.ConfigSet
  |> commands.execute(cache, time.now)

  let on_init = fn(_conn) { #(cache, None) }

  // Start the TCP acceptor pool.
  // Each connection will get its own actor to handle Redis requests.
  let assert Ok(_) =
    glisten.handler(on_init, loop)
    |> glisten.serve(6379)

  // Suspend the main process while the acceptor pool works.
  process.sleep_forever()
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

fn init_cache(args: Dict(String, String)) {
  let rdb_path_result = fn(args) {
    use dir <- result.try(dict.get(args, "dir"))
    use filename <- result.try(dict.get(args, "dbfilename"))
    Ok(dir <> "/" <> filename)
  }

  case rdb_path_result(args) {
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
    Error(Nil) -> cache.init()
  }
}

fn loop(msg, cache, conn) {
  let assert Packet(msg_bits) = msg
  let response = process_msg(msg_bits, cache)
  let assert Ok(_) = glisten.send(conn, bytes_builder.from_bit_array(response))
  actor.continue(cache)
}

fn process_msg(msg: BitArray, cache: Cache) {
  let response = case commands.parse(msg) {
    Ok(cmd) -> commands.execute(cmd, cache, time.now)
    Error(err) -> {
      let msg = parse_error.to_string(err)
      SimpleError("ERR " <> msg)
    }
  }
  resp.encode(response)
}
