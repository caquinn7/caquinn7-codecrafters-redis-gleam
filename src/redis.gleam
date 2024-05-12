import commands.{Echo, Get, Ping, Set}
import gleam/bit_array
import gleam/bytes_builder
import gleam/erlang/process
import gleam/option.{None}
import gleam/otp/actor
import glisten.{Packet}
import resp.{SimpleErr}
import state.{type State}
import time

pub fn main() {
  // Start an ETS table, an in-memory key-value store which all the TCP
  // connection handling actors can read and write shares state to and from.
  let state = state.init()
  let on_init = fn(_) { #(state, None) }

  // Start the TCP acceptor pool.
  // Each connection will get its own actor to handle Redis requests.
  let assert Ok(_) =
    glisten.handler(on_init, loop)
    |> glisten.serve(6379)

  // Suspend the main process while the acceptor pool works.
  process.sleep_forever()
}

fn loop(msg, state, conn) {
  let assert Packet(msg_bits) = msg
  let assert Ok(msg_text) = bit_array.to_string(msg_bits)
  let #(response_text, next_state) = process_msg(msg_text, state)
  let response = bytes_builder.from_string(response_text)
  let assert Ok(_) = glisten.send(conn, response)
  actor.continue(next_state)
}

fn process_msg(msg: String, state: State) -> #(String, State) {
  case commands.parse(msg) {
    Ok(Ping) -> commands.do_ping(state)
    Ok(Echo(str)) -> commands.do_echo(str, state)
    Ok(Get(key)) -> commands.do_get(key, state, time.now)
    Ok(Set(key, val, expiry)) ->
      commands.do_set(key, val, expiry, time.now, state)
    Error(err) -> #(resp.to_string(SimpleErr(err)), state)
  }
}
