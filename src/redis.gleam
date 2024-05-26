import cache.{type Cache}
import commands/commands
import commands/parse_error
import gleam/bytes_builder
import gleam/erlang/process
import gleam/option.{None}
import gleam/otp/actor
import glisten.{Packet}
import resp.{SimpleError}
import time

pub fn main() {
  // Start an ETS table, an in-memory key-value store which all the TCP
  // connection handling actors can read and write shares state to and from.
  let cache = cache.init()
  let on_init = fn(_conn) { #(cache, None) }

  // Start the TCP acceptor pool.
  // Each connection will get its own actor to handle Redis requests.
  let assert Ok(_) =
    glisten.handler(on_init, loop)
    |> glisten.serve(6379)

  // Suspend the main process while the acceptor pool works.
  process.sleep_forever()
}

pub fn loop(msg, cache, conn) {
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
