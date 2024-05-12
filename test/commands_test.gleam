import carpenter/table
import commands
import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import resp.{BulkStr, SimpleStr}
import state.{type Item, Item}

pub fn main() {
  gleeunit.main()
}

pub fn do_echo_test() {
  let input = "hello"
  let state = state.init()
  let expected = #(resp.to_string(BulkStr(Some(input))), state)
  input
  |> commands.do_echo(state)
  |> should.equal(expected)
}

pub fn do_ping_test() {
  let state = state.init()
  state
  |> commands.do_ping
  |> should.equal(#(resp.to_string(SimpleStr("PONG")), state))
}

pub fn do_set_test() {
  let key = "foo"
  let val = "bar"
  let now = 1
  let state = state.init()

  commands.do_set(key, val, None, fn() { now }, state)
  |> should.equal(#(resp.to_string(SimpleStr("OK")), state))

  table.lookup(state, key)
  |> should.equal([#(key, Item(val, None))])
}

pub fn do_set_px_test() {
  let key = "foo"
  let val = "bar"
  let expiry = 1000
  let now = 1
  let state = state.init()

  commands.do_set(key, val, Some(expiry), fn() { now }, state)
  |> should.equal(#(resp.to_string(SimpleStr("OK")), state))

  table.lookup(state, key)
  |> should.equal([#(key, Item(val, Some(expiry + now)))])
}

pub fn do_get_key_exists_test() {
  let key = "foo"
  let val = "bar"

  let state = state.init()
  table.insert(state, [#(key, Item(val, None))])

  commands.do_get(key, state, fn() { 1 })
  |> should.equal(#(resp.to_string(BulkStr(Some(val))), state))

  table.lookup(state, key)
  |> should.equal([#(key, Item(val, None))])
}

pub fn do_get_key_does_not_exist_test() {
  let state = state.init()
  commands.do_get("foo", state, fn() { 1 })
  |> should.equal(#(resp.to_string(BulkStr(None)), state))
}

pub fn do_get_key_expired_test() {
  let key = "foo"

  let state = state.init()
  table.insert(state, [#(key, Item("bar", Some(1)))])

  commands.do_get(key, state, fn() { 2 })
  |> should.equal(#(resp.to_string(BulkStr(None)), state))

  table.lookup(state, key)
  |> should.equal([])
}
