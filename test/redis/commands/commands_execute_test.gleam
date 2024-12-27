import gleam/dict
import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import redis/cache.{Item}
import redis/commands/commands.{ConfigGet, Echo, Get, Keys, Ping, Set}
import redis/resp.{Array, BulkString, SimpleString}
import redis/state.{State}

pub fn main() {
  gleeunit.main()
}

// echo

pub fn execute_echo_test() {
  let input = <<"hello":utf8>>
  input
  |> Echo
  |> commands.execute(state.empty(), fn() { 1 })
  |> should.equal(BulkString(Some(input)))
}

// ping

pub fn execute_ping_test() {
  Ping
  |> commands.execute(state.empty(), fn() { 1 })
  |> should.equal(SimpleString("PONG"))
}

// set

pub fn execute_set_test() {
  let cmd = Set(<<"foo":utf8>>, <<"bar":utf8>>, None)
  // works locally w/out the assert but needed for codecrafters to compile
  let assert Set(key, val, _) = cmd
  let state = state.empty()

  commands.execute(cmd, state, fn() { 1 })
  |> should.equal(SimpleString("OK"))

  cache.get(state.cache, key)
  |> should.be_ok
  |> should.equal(Item(val, None))
}

pub fn execute_set_px_test() {
  let cmd = Set(<<"foo":utf8>>, <<"bar":utf8>>, Some(1000))
  let assert Set(key, val, Some(life_time)) = cmd
  let now = 1
  let state = state.empty()

  commands.execute(cmd, state, fn() { now })
  |> should.equal(SimpleString("OK"))

  cache.get(state.cache, key)
  |> should.be_ok
  |> should.equal(Item(val, Some(life_time + now)))
}

pub fn execute_set_key_exists_test() {
  let key = <<"foo":utf8>>
  let get_time = fn() { 1 }
  let state = state.empty()

  Set(key, <<"bar":utf8>>, Some(1000))
  |> commands.execute(state, get_time)
  |> should.equal(SimpleString("OK"))

  let val = <<"bat":utf8>>

  Set(key, val, None)
  |> commands.execute(state, get_time)
  |> should.equal(SimpleString("OK"))

  cache.get(state.cache, key)
  |> should.be_ok
  |> should.equal(Item(val, None))
}

// get

pub fn execute_get_key_exists_test() {
  let key = <<"foo":utf8>>
  let val = <<"bar":utf8>>

  let state = state.empty()
  cache.set(state.cache, key, Item(val, None))

  commands.execute(Get(key), state, fn() { 1 })
  |> should.equal(BulkString(Some(val)))

  cache.get(state.cache, key)
  |> should.be_ok
  |> should.equal(Item(val, None))
}

pub fn execute_get_key_does_not_exist_test() {
  commands.execute(Get(<<"foo":utf8>>), state.empty(), fn() { 1 })
  |> should.equal(BulkString(None))
}

pub fn execute_get_key_expired_test() {
  let key = <<"foo":utf8>>
  let state = state.empty()
  cache.set(state.cache, key, Item(<<"foo":utf8>>, Some(1)))

  commands.execute(Get(key), state, fn() { 2 })
  |> should.equal(BulkString(None))

  cache.get(state.cache, key)
  |> should.be_error
  |> should.equal(Nil)
}

// get keys

pub fn execute_keys_test() {
  let state = state.empty()
  cache.set(state.cache, <<"key1":utf8>>, Item(<<"val1":utf8>>, None))

  Keys("*")
  |> commands.execute(state, fn() { 1 })
  |> should.equal(Array([BulkString(Some(<<"key1":utf8>>))]))
}

// config get

pub fn execute_config_get_test() {
  let config = dict.from_list([#("key1", "val1"), #("key2", "val2")])
  let state = State(config, cache.new())

  ConfigGet(["key1", "key2", "key3"])
  |> commands.execute(state, fn() { 1 })
  |> should.equal(
    Array([
      BulkString(Some(<<"key1":utf8>>)),
      BulkString(Some(<<"val1":utf8>>)),
      BulkString(Some(<<"key2":utf8>>)),
      BulkString(Some(<<"val2":utf8>>)),
    ]),
  )
}
