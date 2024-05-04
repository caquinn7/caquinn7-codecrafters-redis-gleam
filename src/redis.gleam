import cmd.{Echo, ParseErr, Ping}
import gleam/bit_array
import gleam/bytes_builder
import gleam/erlang/process
import gleam/io
import gleam/option.{None}
import gleam/otp/actor
import glisten.{Packet}
import resp.{SimpleStr}

pub fn main() {
  io.println("Logs from your program will appear here!")

  let assert Ok(_) =
    glisten.handler(fn(_conn) { #(Nil, None) }, fn(msg, state, conn) {
      let assert Packet(msg_bits) = msg
      let assert Ok(msg_str) = bit_array.to_string(msg_bits)
      io.println(msg_str)

      let response_text = case cmd.parse(msg_str) {
        Ok(Ping) -> resp.to_string(SimpleStr("PONG"))
        Ok(Echo(bulkstr)) -> resp.to_string(bulkstr)
        Error(ParseErr(_, err)) -> {
          io.println(err)
          ""
        }
      }

      let response = bytes_builder.from_string(response_text)
      let assert Ok(_) = glisten.send(conn, response)
      actor.continue(state)
    })
    |> glisten.serve(6379)

  process.sleep_forever()
}
