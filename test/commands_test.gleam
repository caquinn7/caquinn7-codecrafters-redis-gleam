import carpenter/table
import commands.{Echo, Get, Ping, Set}
import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import resp.{BulkStr, SimpleStr}
import state.{type Item, Item}

pub fn main() {
  gleeunit.main()
}

pub fn execute_echo_test() {
  let input = "echo this"
  input
  |> Echo
  |> commands.execute(state.init(), fn() { 1 })
  |> should.equal(BulkStr(Some(input)))
}

pub fn execute_ping_test() {
  Ping
  |> commands.execute(state.init(), fn() { 1 })
  |> should.equal(SimpleStr("PONG"))
}

pub fn execute_set_test() {
  let cmd = Set("foo", "bar", None)
  let assert Set(key, val, _) = cmd
  let state = state.init()

  commands.execute(cmd, state, fn() { 1 })
  |> should.equal(SimpleStr("OK"))

  table.lookup(state, key)
  |> should.equal([#(key, Item(val, None))])
}

pub fn execute_set_px_test() {
  let cmd = Set("foo", "bar", Some(1000))
  let assert Set(key, val, Some(life_time)) = cmd
  let now = 1
  let state = state.init()

  commands.execute(cmd, state, fn() { now })
  |> should.equal(SimpleStr("OK"))

  table.lookup(state, key)
  |> should.equal([#(key, Item(val, Some(life_time + now)))])
}

pub fn execute_get_key_exists_test() {
  let key = "foo"
  let val = "bar"

  let state = state.init()
  table.insert(state, [#(key, Item(val, None))])

  commands.execute(Get(key), state, fn() { 1 })
  |> should.equal(BulkStr(Some(val)))

  table.lookup(state, key)
  |> should.equal([#(key, Item(val, None))])
}

pub fn execute_get_key_does_not_exist_test() {
  commands.execute(Get("foo"), state.init(), fn() { 1 })
  |> should.equal(BulkStr(None))
}

pub fn execute_get_key_expired_test() {
  let key = "foo"
  let state = state.init()
  table.insert(state, [#(key, Item("bar", Some(1)))])

  commands.execute(Get(key), state, fn() { 2 })
  |> should.equal(BulkStr(None))

  table.lookup(state, key)
  |> should.equal([])
}
