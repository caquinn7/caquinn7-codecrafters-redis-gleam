import cache.{Item}
import commands/commands.{ConfigGet, ConfigSet, Echo, Get, Ping, Set}
import gleam/dict
import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import resp.{Array, BulkString, SimpleString}

pub fn main() {
  gleeunit.main()
}

// echo

pub fn execute_echo_test() {
  let input = <<"hello":utf8>>
  input
  |> Echo
  |> commands.execute(cache.init(), fn() { 1 })
  |> should.equal(BulkString(Some(input)))
}

// ping

pub fn execute_ping_test() {
  Ping
  |> commands.execute(cache.init(), fn() { 1 })
  |> should.equal(SimpleString("PONG"))
}

// set

pub fn execute_set_test() {
  let cmd = Set(<<"foo":utf8>>, <<"bar":utf8>>, None)
  let assert Set(key, val, _) = cmd
  let cache = cache.init()

  commands.execute(cmd, cache, fn() { 1 })
  |> should.equal(SimpleString("OK"))

  cache.get(cache, key)
  |> should.be_ok
  |> should.equal(Item(val, None))
}

pub fn execute_set_px_test() {
  let cmd = Set(<<"foo":utf8>>, <<"bar":utf8>>, Some(1000))
  let assert Set(key, val, Some(life_time)) = cmd
  let now = 1
  let cache = cache.init()

  commands.execute(cmd, cache, fn() { now })
  |> should.equal(SimpleString("OK"))

  cache.get(cache, key)
  |> should.be_ok
  |> should.equal(Item(val, Some(life_time + now)))
}

pub fn execute_set_key_exists_test() {
  let key = <<"foo":utf8>>
  let get_time = fn() { 1 }
  let cache = cache.init()

  Set(key, <<"bar":utf8>>, Some(1000))
  |> commands.execute(cache, get_time)
  |> should.equal(SimpleString("OK"))

  let val = <<"bat":utf8>>

  Set(key, val, None)
  |> commands.execute(cache, get_time)
  |> should.equal(SimpleString("OK"))

  cache.get(cache, key)
  |> should.be_ok
  |> should.equal(Item(val, None))
}

// get

pub fn execute_get_key_exists_test() {
  let key = <<"foo":utf8>>
  let val = <<"bar":utf8>>

  let cache = cache.init()
  cache.set(cache, key, Item(val, None))

  commands.execute(Get(key), cache, fn() { 1 })
  |> should.equal(BulkString(Some(val)))

  cache.get(cache, key)
  |> should.be_ok
  |> should.equal(Item(val, None))
}

pub fn execute_get_key_does_not_exist_test() {
  commands.execute(Get(<<"foo":utf8>>), cache.init(), fn() { 1 })
  |> should.equal(BulkString(None))
}

pub fn execute_get_key_expired_test() {
  let key = <<"foo":utf8>>
  let cache = cache.init()
  cache.set(cache, key, Item(<<"foo":utf8>>, Some(1)))

  commands.execute(Get(key), cache, fn() { 2 })
  |> should.equal(BulkString(None))

  cache.get(cache, key)
  |> should.be_error
  |> should.equal(Nil)
}

// config set

pub fn execute_config_set_test() {
  let cache = cache.init()

  let pairs =
    [#("key1", "val1"), #("key2", "val2")]
    |> dict.from_list()

  commands.execute(ConfigSet(pairs), cache, fn() { 1 })
  |> should.equal(SimpleString("OK"))

  cache.get(cache, <<"config:key1":utf8>>)
  |> should.be_ok
  |> should.equal(Item(<<"val1":utf8>>, None))

  cache.get(cache, <<"config:key2":utf8>>)
  |> should.be_ok
  |> should.equal(Item(<<"val2":utf8>>, None))
}

// config get

pub fn execute_config_get_test() {
  let cache = cache.init()

  let pairs =
    [#("key1", "val1"), #("key2", "val2")]
    |> dict.from_list()

  commands.execute(ConfigSet(pairs), cache, fn() { 1 })
  |> should.equal(SimpleString("OK"))

  commands.execute(ConfigGet(dict.keys(pairs)), cache, fn() { 1 })
  |> should.equal(
    Array([
      BulkString(Some(<<"key1":utf8>>)),
      BulkString(Some(<<"val1":utf8>>)),
      BulkString(Some(<<"key2":utf8>>)),
      BulkString(Some(<<"val2":utf8>>)),
    ]),
  )
}
