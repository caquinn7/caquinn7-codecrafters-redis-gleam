import cmd.{Echo, Get, Ping, Set}
import gleam/bit_array
import gleam/bytes_builder
import gleam/erlang/process
import gleam/io
import gleam/option.{None, Some}
import gleam/otp/actor
import glisten.{Packet}
import resp.{BulkStr, SimpleErr, SimpleStr}
import sqlight
import storage

// ./spawn_redis_server.sh
// nc -v 127.0.0.1 6379
pub fn main() {
  io.println("Logs from your program will appear here!")

  use db_conn <- sqlight.with_connection(":memory:")
  let assert Ok(_) = storage.init(db_conn)

  let assert Ok(_) =
    glisten.handler(fn(_conn) { #(Nil, None) }, fn(msg, state, conn) {
      let assert Packet(msg_bits) = msg
      let assert Ok(msg_text) = bit_array.to_string(msg_bits)

      io.println("received:\n" <> msg_text)

      let response_text = case cmd.parse(msg_text) {
        Ok(Echo(s)) -> resp.to_string(s)
        Ok(Get(key)) -> {
          let assert BulkStr(Some(key_str)) = key
          case storage.get(db_conn, key_str) {
            Ok(Some(val)) -> resp.to_string(BulkStr(Some(val)))
            Ok(None) -> resp.to_string(BulkStr(None))
            Error(err) -> {
              io.debug(err)
              resp.to_string(SimpleErr("Error getting key"))
            }
          }
        }
        Ok(Set(key, value)) -> {
          let assert BulkStr(Some(key_str)) = key
          let assert BulkStr(Some(val_str)) = value
          case storage.insert(db_conn, key_str, val_str) {
            Ok(_) -> resp.to_string(SimpleStr("OK"))
            Error(err) -> {
              io.debug(err)
              resp.to_string(SimpleErr("Error setting key"))
            }
          }
        }
        Ok(Ping) -> resp.to_string(SimpleStr("PONG"))
        Error(err) -> resp.to_string(SimpleErr(err))
      }

      io.println("sending:\n" <> response_text)

      let response = bytes_builder.from_string(response_text)
      let assert Ok(_) = glisten.send(conn, response)
      actor.continue(state)
    })
    |> glisten.serve(6379)

  process.sleep_forever()
}
