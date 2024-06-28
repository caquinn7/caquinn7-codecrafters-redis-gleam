import argv
import commands/commands
import commands/parse_error
import gleam/bytes_builder
import gleam/erlang/process
import gleam/option.{None}
import gleam/otp/actor
import glisten.{Packet}
import resp.{SimpleError}
import state.{type State}
import time

pub fn main() {
  let args = argv.load().arguments
  let state = state.init(args)

  let on_init = fn(_conn) { #(state, None) }

  // Start the TCP acceptor pool.
  // Each connection will get its own actor to handle Redis requests.
  let assert Ok(_) =
    glisten.handler(on_init, loop)
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
