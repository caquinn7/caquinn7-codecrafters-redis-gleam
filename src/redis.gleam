import cmd.{Echo, Get, Ping, Set}
import gleam/bit_array
import gleam/bytes_builder
import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/io
import gleam/option.{None, Some}
import gleam/otp/actor
import glisten.{Packet}
import resp.{BulkStr, SimpleErr, SimpleStr}

pub type Context {
  Context(state: Dict(String, String))
}

// ./spawn_redis_server.sh
// nc -v 127.0.0.1 6379
pub fn main() {
  io.println("Logs from your program will appear here!")

  let assert Ok(_) =
    glisten.handler(
      fn(_conn) { #(Context(dict.new()), None) },
      fn(msg, ctx, conn) {
        let assert Packet(msg_bits) = msg
        let assert Ok(msg_text) = bit_array.to_string(msg_bits)

        io.println("received:\n" <> msg_text)

        let #(response_text, new_ctx) = handle(msg_text, ctx)

        io.println("sending:\n" <> response_text)

        let response = bytes_builder.from_string(response_text)
        let assert Ok(_) = glisten.send(conn, response)
        actor.continue(new_ctx)
      },
    )
    |> glisten.serve(6379)

  process.sleep_forever()
}

fn handle(msg: String, ctx: Context) -> #(String, Context) {
  case cmd.parse(msg) {
    Ok(Echo(s)) -> #(resp.to_string(s), ctx)
    Ok(Get(key)) -> {
      let assert BulkStr(Some(key_str)) = key
      case dict.get(ctx.state, key_str) {
        Ok(val) -> #(resp.to_string(BulkStr(Some(val))), ctx)
        Error(_) -> #(resp.to_string(BulkStr(None)), ctx)
      }
    }
    Ok(Set(key, val)) -> {
      let assert BulkStr(Some(key_str)) = key
      let assert BulkStr(Some(val_str)) = val
      let new_state = dict.update(ctx.state, key_str, fn(_) { val_str })
      #(resp.to_string(SimpleStr("OK")), Context(new_state))
    }
    Ok(Ping) -> #(resp.to_string(SimpleStr("PONG")), ctx)
    Error(err) -> #(resp.to_string(SimpleErr(err)), ctx)
  }
}
