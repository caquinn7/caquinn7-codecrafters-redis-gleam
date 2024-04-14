import gleam/bytes_builder
import gleam/io
import gleam/erlang/process
import gleam/option.{None}
import gleam/otp/actor
import glisten

pub fn main() {
  io.println("Logs from your program will appear here!")

  let assert Ok(_) =
    glisten.handler(fn(_conn) { #(Nil, None) }, fn(msg, state, conn) {
      io.debug(msg)
      let assert Ok(_) =
        glisten.send(conn, bytes_builder.from_string("+PONG\r\n"))
      actor.continue(state)
    })
    |> glisten.serve(6379)

  process.sleep_forever()
}
