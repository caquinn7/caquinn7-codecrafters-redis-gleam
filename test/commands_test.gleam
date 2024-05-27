import cache.{Item}
import commands/commands.{ConfigGet, ConfigSet, Echo, Get, Ping, Set}
import commands/parse_error.{
  InvalidArgument, InvalidCommand, Null, PostiveIntegerRequired, SyntaxError,
  WrongNumberOfArguments,
}
import gleam/dict
import gleam/int
import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import resp.{Array, BulkString, SimpleString}

pub fn main() {
  gleeunit.main()
}

// parse

pub fn parse_empty_test() {
  Array([])
  |> resp.encode
  |> test_err(SyntaxError)
}

pub fn parse_null_test() {
  Array([BulkString(None)])
  |> resp.encode
  |> test_err(SyntaxError)
}

pub fn parse_invalid_command_test() {
  Array([BulkString(Some(<<"HELLO":utf8>>))])
  |> resp.encode
  |> test_err(InvalidCommand("HELLO"))
}

// parse // echo

pub fn parse_echo_test() {
  let msg = <<"hey":utf8>>
  Array([BulkString(Some(<<"ECHO":utf8>>)), BulkString(Some(msg))])
  |> resp.encode
  |> test_ok(Echo(msg))
}

pub fn parse_echo_lowercase_test() {
  let msg = <<"hey":utf8>>
  Array([BulkString(Some(<<"echo":utf8>>)), BulkString(Some(msg))])
  |> resp.encode
  |> test_ok(Echo(msg))
}

pub fn parse_echo_no_message_test() {
  Array([BulkString(Some(<<"echo":utf8>>))])
  |> resp.encode
  |> test_err(WrongNumberOfArguments)
}

pub fn parse_echo_null_message_test() {
  Array([BulkString(Some(<<"echo":utf8>>)), BulkString(None)])
  |> resp.encode
  |> test_err(InvalidArgument("message", Null))
}

// parse // ping

pub fn parse_ping_test() {
  Array([BulkString(Some(<<"PING":utf8>>))])
  |> resp.encode
  |> test_ok(Ping)
}

pub fn parse_ping_with_arg_test() {
  Array([BulkString(Some(<<"PING":utf8>>)), BulkString(Some(<<>>))])
  |> resp.encode
  |> test_err(WrongNumberOfArguments)
}

// parse // get

pub fn parse_get_test() {
  let key = <<"a_key":utf8>>
  Array([BulkString(Some(<<"GET":utf8>>)), BulkString(Some(key))])
  |> resp.encode
  |> test_ok(Get(key))
}

pub fn parse_get_null_key_test() {
  Array([BulkString(Some(<<"GET":utf8>>)), BulkString(None)])
  |> resp.encode
  |> test_err(InvalidArgument("key", Null))
}

pub fn parse_get_no_arg_test() {
  Array([BulkString(Some(<<"GET":utf8>>))])
  |> resp.encode
  |> test_err(WrongNumberOfArguments)
}

pub fn parse_get_two_args_test() {
  Array([
    BulkString(Some(<<"GET":utf8>>)),
    BulkString(Some(<<"a_key":utf8>>)),
    BulkString(Some(<<>>)),
  ])
  |> resp.encode
  |> test_err(WrongNumberOfArguments)
}

// parse // set

pub fn parse_set_no_expiration_test() {
  let key = <<"a_key":utf8>>
  let val = <<"a_val":utf8>>
  Array([
    BulkString(Some(<<"SET":utf8>>)),
    BulkString(Some(key)),
    BulkString(Some(val)),
  ])
  |> resp.encode
  |> test_ok(Set(key, val, None))
}

pub fn parse_set_with_px_test() {
  let key = <<"a_key":utf8>>
  let val = <<"a_val":utf8>>
  let life_time = 1000
  Array([
    BulkString(Some(<<"SET":utf8>>)),
    BulkString(Some(key)),
    BulkString(Some(val)),
    BulkString(Some(<<"PX":utf8>>)),
    BulkString(Some(<<int.to_string(life_time):utf8>>)),
  ])
  |> resp.encode
  |> test_ok(Set(key, val, Some(life_time)))
}

pub fn parse_set_with_px_lowercase_test() {
  let key = <<"a_key":utf8>>
  let val = <<"a_val":utf8>>
  let life_time = 1000
  Array([
    BulkString(Some(<<"SET":utf8>>)),
    BulkString(Some(key)),
    BulkString(Some(val)),
    BulkString(Some(<<"px":utf8>>)),
    BulkString(Some(<<int.to_string(life_time):utf8>>)),
  ])
  |> resp.encode
  |> test_ok(Set(key, val, Some(life_time)))
}

pub fn parse_set_null_key_test() {
  Array([
    BulkString(Some(<<"SET":utf8>>)),
    BulkString(None),
    BulkString(Some(<<"a_val":utf8>>)),
  ])
  |> resp.encode
  |> test_err(InvalidArgument("key", Null))
}

pub fn parse_set_null_val_test() {
  Array([
    BulkString(Some(<<"SET":utf8>>)),
    BulkString(Some(<<"a_key":utf8>>)),
    BulkString(None),
  ])
  |> resp.encode
  |> test_err(InvalidArgument("value", Null))
}

pub fn parse_set_px_not_an_int_test() {
  Array([
    BulkString(Some(<<"SET":utf8>>)),
    BulkString(Some(<<"a_key":utf8>>)),
    BulkString(Some(<<"a_val":utf8>>)),
    BulkString(Some(<<"PX":utf8>>)),
    BulkString(Some(<<"abc":utf8>>)),
  ])
  |> resp.encode
  |> test_err(InvalidArgument("PX", PostiveIntegerRequired))
}

pub fn parse_set_px_negative_test() {
  Array([
    BulkString(Some(<<"SET":utf8>>)),
    BulkString(Some(<<"a_key":utf8>>)),
    BulkString(Some(<<"a_val":utf8>>)),
    BulkString(Some(<<"PX":utf8>>)),
    BulkString(Some(<<"-1":utf8>>)),
  ])
  |> resp.encode
  |> test_err(InvalidArgument("PX", PostiveIntegerRequired))
}

pub fn parse_set_invalid_arg_name_test() {
  Array([
    BulkString(Some(<<"SET":utf8>>)),
    BulkString(Some(<<"a_key":utf8>>)),
    BulkString(Some(<<"a_val":utf8>>)),
    BulkString(Some(<<"XXX":utf8>>)),
    BulkString(Some(<<"1000":utf8>>)),
  ])
  |> resp.encode
  |> test_err(SyntaxError)
}

pub fn parse_set_extra_arg_test() {
  Array([
    BulkString(Some(<<"SET":utf8>>)),
    BulkString(Some(<<"a_key":utf8>>)),
    BulkString(Some(<<"a_val":utf8>>)),
    BulkString(Some(<<"PX":utf8>>)),
    BulkString(Some(<<"1000":utf8>>)),
    BulkString(Some(<<"XXX":utf8>>)),
  ])
  |> resp.encode
  |> test_err(SyntaxError)
}

pub fn parse_set_px_without_val_test() {
  Array([
    BulkString(Some(<<"SET":utf8>>)),
    BulkString(Some(<<"a_key":utf8>>)),
    BulkString(Some(<<"a_val":utf8>>)),
    BulkString(Some(<<"PX":utf8>>)),
  ])
  |> resp.encode
  |> test_err(SyntaxError)
}

// execute // echo

pub fn execute_echo_test() {
  let input = <<"hello":utf8>>
  input
  |> Echo
  |> commands.execute(cache.init(), fn() { 1 })
  |> should.equal(BulkString(Some(input)))
}

// execute // ping
pub fn execute_ping_test() {
  Ping
  |> commands.execute(cache.init(), fn() { 1 })
  |> should.equal(SimpleString("PONG"))
}

// execute // set

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

// execute // get

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

// execute // config set

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

// execute // config get

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

pub fn test_ok(input, expected) {
  input
  |> commands.parse
  |> should.be_ok
  |> should.equal(expected)
}

pub fn test_err(input, expected) {
  input
  |> commands.parse
  |> should.be_error
  |> should.equal(expected)
}
