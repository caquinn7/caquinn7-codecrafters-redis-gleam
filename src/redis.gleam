import commands.{Echo, Get, Ping, Set}
import context.{type Context, Context}
import gleam/bit_array
import gleam/bytes_builder
import gleam/erlang/process
import gleam/io
import gleam/option.{None}
import gleam/otp/actor
import glisten.{Packet}
import resp.{SimpleErr}
import time

pub fn main() {
  let on_init = fn(_) { #(context.empty(), None) }

  let assert Ok(_) =
    glisten.handler(on_init, loop)
    |> glisten.serve(6379)

  process.sleep_forever()
}

fn loop(msg, ctx, conn) {
  let assert Packet(msg_bits) = msg
  let assert Ok(msg_text) = bit_array.to_string(msg_bits)

  io.println("received:\n" <> msg_text)
  let #(response_text, new_ctx) = process_msg(msg_text, ctx)
  io.println("sending:\n" <> response_text)

  let response = bytes_builder.from_string(response_text)
  let assert Ok(_) = glisten.send(conn, response)
  actor.continue(new_ctx)
}

fn process_msg(msg: String, ctx: Context) {
  case commands.parse(msg) {
    Ok(Ping) -> commands.do_ping(ctx)
    Ok(Echo(str)) -> commands.do_echo(str, ctx)
    Ok(Get(key)) -> commands.do_get(key, ctx, time.now)
    Ok(Set(key, val, expiry)) ->
      commands.do_set(key, val, expiry, time.now, ctx)
    Error(err) -> #(resp.to_string(SimpleErr(err)), ctx)
  }
}
