import commands
import context.{type Context, type Item, Context, Item}
import gleam/dict
import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import resp.{BulkStr, SimpleStr}

pub fn main() {
  gleeunit.main()
}

pub fn do_echo_test() {
  let input = "hello"
  let expected = #(resp.to_string(BulkStr(Some(input))), context.empty())
  input
  |> commands.do_echo(context.empty())
  |> should.equal(expected)
}

pub fn do_ping_test() {
  context.empty()
  |> commands.do_ping
  |> should.equal(#(resp.to_string(SimpleStr("PONG")), context.empty()))
}

pub fn do_set_test() {
  let key = "foo"
  let val = "bar"
  let now = 1
  let expected_item = Item(val, None)
  let expected_ctx = Context(dict.from_list([#(key, expected_item)]))
  commands.do_set(key, val, None, fn() { now }, context.empty())
  |> should.equal(#(resp.to_string(SimpleStr("OK")), expected_ctx))
}

pub fn do_set_px_test() {
  let key = "foo"
  let val = "bar"
  let expiry = 1000
  let now = 1
  let expected_item = Item(val, Some(expiry + now))
  let expected_ctx = Context(dict.from_list([#(key, expected_item)]))
  commands.do_set(key, val, Some(expiry), fn() { now }, context.empty())
  |> should.equal(#(resp.to_string(SimpleStr("OK")), expected_ctx))
}

pub fn do_get_key_exists_test() {
  let key = "foo"
  let val = "bar"
  let ctx = Context(dict.from_list([#(key, Item(val, None))]))
  commands.do_get("foo", ctx, fn() { 1 })
  |> should.equal(#(resp.to_string(BulkStr(Some(val))), ctx))
}

pub fn do_get_key_does_not_exist_test() {
  commands.do_get("foo", context.empty(), fn() { 1 })
  |> should.equal(#(resp.to_string(BulkStr(None)), context.empty()))
}

pub fn do_get_key_expired_test() {
  let key = "foo"
  let ctx = Context(dict.from_list([#(key, Item("bar", Some(1)))]))
  commands.do_get(key, ctx, fn() { 2 })
  |> should.equal(#(resp.to_string(BulkStr(None)), context.empty()))
}
