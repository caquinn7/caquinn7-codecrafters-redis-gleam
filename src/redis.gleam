import birl.{to_unix, utc_now}
import cmd.{Echo, Get, Ping, Set}
import gleam/bit_array
import gleam/bytes_builder
import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import glisten.{Packet}
import resp.{BulkStr, SimpleErr, SimpleStr}

pub type Item {
  Item(String, Option(Int))
}

pub type Context {
  Context(state: Dict(String, Item))
}

pub fn main() {
  io.println("Logs from your program will appear here!")

  let on_init = fn(_) { #(Context(dict.new()), None) }

  let loop = fn(msg, ctx, conn) {
    let assert Packet(msg_bits) = msg
    let assert Ok(msg_text) = bit_array.to_string(msg_bits)

    io.println("received:\n" <> msg_text)
    let #(response_text, new_ctx) = process_msg(msg_text, ctx)
    io.println("sending:\n" <> response_text)

    io.debug(ctx)

    let response = bytes_builder.from_string(response_text)
    let assert Ok(_) = glisten.send(conn, response)
    actor.continue(new_ctx)
  }

  let assert Ok(_) =
    glisten.handler(on_init, loop)
    |> glisten.serve(6379)

  process.sleep_forever()
}

fn process_msg(msg: String, ctx: Context) -> #(String, Context) {
  case cmd.parse(msg) {
    Ok(Echo(s)) -> #(resp.to_string(BulkStr(Some(s))), ctx)
    Ok(Get(key)) -> {
      case dict.get(ctx.state, key) {
        Ok(Item(val, exp)) -> {
          let assert Some(expires_at) = option.or(exp, Some(0))
          case now() <= expires_at {
            False -> #(resp.to_string(BulkStr(None)), ctx)
            True -> #(resp.to_string(BulkStr(Some(val))), ctx)
          }
        }
        Error(_) -> #(resp.to_string(BulkStr(None)), ctx)
      }
    }
    Ok(Set(key, val, exp)) -> {
      let new_state =
        dict.update(ctx.state, key, fn(_) {
          let expires_at = case exp {
            Some(milliseconds) -> Some(now() + milliseconds)
            None -> None
          }
          Item(val, expires_at)
        })
      #(resp.to_string(SimpleStr("OK")), Context(new_state))
    }
    Ok(Ping) -> #(resp.to_string(SimpleStr("PONG")), ctx)
    Error(err) -> #(resp.to_string(SimpleErr(err)), ctx)
  }
}

fn now() {
  utc_now()
  |> to_unix
}
