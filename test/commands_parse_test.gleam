// import commands/commands.{ConfigGet, Echo, Get, Keys, Ping, Set}
// import commands/parse_error.{
//   InvalidArgument, InvalidCommand, Null, PostiveIntegerRequired, SyntaxError,
//   WrongNumberOfArguments,
// }
// import gleam/int
// import gleam/option.{None, Some}
// import gleeunit
// import gleeunit/should
// import resp.{Array, BulkString}

// pub fn main() {
//   gleeunit.main()
// }

// pub fn parse_empty_test() {
//   Array([])
//   |> resp.encode
//   |> test_err(SyntaxError)
// }

// pub fn parse_null_test() {
//   Array([BulkString(None)])
//   |> resp.encode
//   |> test_err(SyntaxError)
// }

// pub fn parse_invalid_command_test() {
//   Array([BulkString(Some(<<"HELLO":utf8>>))])
//   |> resp.encode
//   |> test_err(InvalidCommand("HELLO"))
// }

// // ping

// pub fn parse_ping_test() {
//   Array([BulkString(Some(<<"PING":utf8>>))])
//   |> resp.encode
//   |> test_ok(Ping)
// }

// pub fn parse_ping_with_arg_test() {
//   Array([BulkString(Some(<<"PING":utf8>>)), BulkString(Some(<<>>))])
//   |> resp.encode
//   |> test_err(WrongNumberOfArguments)
// }

// // echo

// pub fn parse_echo_test() {
//   let msg = <<"hey":utf8>>
//   Array([BulkString(Some(<<"ECHO":utf8>>)), BulkString(Some(msg))])
//   |> resp.encode
//   |> test_ok(Echo(msg))
// }

// pub fn parse_echo_lowercase_test() {
//   let msg = <<"hey":utf8>>
//   Array([BulkString(Some(<<"echo":utf8>>)), BulkString(Some(msg))])
//   |> resp.encode
//   |> test_ok(Echo(msg))
// }

// pub fn parse_echo_no_message_test() {
//   Array([BulkString(Some(<<"echo":utf8>>))])
//   |> resp.encode
//   |> test_err(WrongNumberOfArguments)
// }

// pub fn parse_echo_null_message_test() {
//   Array([BulkString(Some(<<"echo":utf8>>)), BulkString(None)])
//   |> resp.encode
//   |> test_err(InvalidArgument("message", Null))
// }

// // set

// pub fn parse_set_no_expiration_test() {
//   let key = <<"a_key":utf8>>
//   let val = <<"a_val":utf8>>
//   Array([
//     BulkString(Some(<<"SET":utf8>>)),
//     BulkString(Some(key)),
//     BulkString(Some(val)),
//   ])
//   |> resp.encode
//   |> test_ok(Set(key, val, None))
// }

// pub fn parse_set_with_px_test() {
//   let key = <<"a_key":utf8>>
//   let val = <<"a_val":utf8>>
//   let life_time = 1000
//   Array([
//     BulkString(Some(<<"SET":utf8>>)),
//     BulkString(Some(key)),
//     BulkString(Some(val)),
//     BulkString(Some(<<"PX":utf8>>)),
//     BulkString(Some(<<int.to_string(life_time):utf8>>)),
//   ])
//   |> resp.encode
//   |> test_ok(Set(key, val, Some(life_time)))
// }

// pub fn parse_set_with_px_lowercase_test() {
//   let key = <<"a_key":utf8>>
//   let val = <<"a_val":utf8>>
//   let life_time = 1000
//   Array([
//     BulkString(Some(<<"SET":utf8>>)),
//     BulkString(Some(key)),
//     BulkString(Some(val)),
//     BulkString(Some(<<"px":utf8>>)),
//     BulkString(Some(<<int.to_string(life_time):utf8>>)),
//   ])
//   |> resp.encode
//   |> test_ok(Set(key, val, Some(life_time)))
// }

// pub fn parse_set_null_key_test() {
//   Array([
//     BulkString(Some(<<"SET":utf8>>)),
//     BulkString(None),
//     BulkString(Some(<<"a_val":utf8>>)),
//   ])
//   |> resp.encode
//   |> test_err(InvalidArgument("key", Null))
// }

// pub fn parse_set_null_val_test() {
//   Array([
//     BulkString(Some(<<"SET":utf8>>)),
//     BulkString(Some(<<"a_key":utf8>>)),
//     BulkString(None),
//   ])
//   |> resp.encode
//   |> test_err(InvalidArgument("value", Null))
// }

// pub fn parse_set_px_not_an_int_test() {
//   Array([
//     BulkString(Some(<<"SET":utf8>>)),
//     BulkString(Some(<<"a_key":utf8>>)),
//     BulkString(Some(<<"a_val":utf8>>)),
//     BulkString(Some(<<"PX":utf8>>)),
//     BulkString(Some(<<"abc":utf8>>)),
//   ])
//   |> resp.encode
//   |> test_err(InvalidArgument("PX", PostiveIntegerRequired))
// }

// pub fn parse_set_px_negative_test() {
//   Array([
//     BulkString(Some(<<"SET":utf8>>)),
//     BulkString(Some(<<"a_key":utf8>>)),
//     BulkString(Some(<<"a_val":utf8>>)),
//     BulkString(Some(<<"PX":utf8>>)),
//     BulkString(Some(<<"-1":utf8>>)),
//   ])
//   |> resp.encode
//   |> test_err(InvalidArgument("PX", PostiveIntegerRequired))
// }

// pub fn parse_set_invalid_arg_name_test() {
//   Array([
//     BulkString(Some(<<"SET":utf8>>)),
//     BulkString(Some(<<"a_key":utf8>>)),
//     BulkString(Some(<<"a_val":utf8>>)),
//     BulkString(Some(<<"XXX":utf8>>)),
//     BulkString(Some(<<"1000":utf8>>)),
//   ])
//   |> resp.encode
//   |> test_err(SyntaxError)
// }

// pub fn parse_set_extra_arg_test() {
//   Array([
//     BulkString(Some(<<"SET":utf8>>)),
//     BulkString(Some(<<"a_key":utf8>>)),
//     BulkString(Some(<<"a_val":utf8>>)),
//     BulkString(Some(<<"PX":utf8>>)),
//     BulkString(Some(<<"1000":utf8>>)),
//     BulkString(Some(<<"XXX":utf8>>)),
//   ])
//   |> resp.encode
//   |> test_err(SyntaxError)
// }

// pub fn parse_set_px_without_val_test() {
//   Array([
//     BulkString(Some(<<"SET":utf8>>)),
//     BulkString(Some(<<"a_key":utf8>>)),
//     BulkString(Some(<<"a_val":utf8>>)),
//     BulkString(Some(<<"PX":utf8>>)),
//   ])
//   |> resp.encode
//   |> test_err(SyntaxError)
// }

// // get

// pub fn parse_get_test() {
//   let key = <<"a_key":utf8>>
//   Array([BulkString(Some(<<"GET":utf8>>)), BulkString(Some(key))])
//   |> resp.encode
//   |> test_ok(Get(key))
// }

// pub fn parse_get_null_key_test() {
//   Array([BulkString(Some(<<"GET":utf8>>)), BulkString(None)])
//   |> resp.encode
//   |> test_err(InvalidArgument("key", Null))
// }

// pub fn parse_get_no_arg_test() {
//   Array([BulkString(Some(<<"GET":utf8>>))])
//   |> resp.encode
//   |> test_err(WrongNumberOfArguments)
// }

// pub fn parse_get_two_args_test() {
//   Array([
//     BulkString(Some(<<"GET":utf8>>)),
//     BulkString(Some(<<"a_key":utf8>>)),
//     BulkString(Some(<<>>)),
//   ])
//   |> resp.encode
//   |> test_err(WrongNumberOfArguments)
// }

// // config

// pub fn parse_config_no_subcommand_test() {
//   Array([BulkString(Some(<<"CONFIG":utf8>>))])
//   |> resp.encode
//   |> test_err(WrongNumberOfArguments)
// }

// pub fn parse_config_invalid_subcommand_test() {
//   Array([BulkString(Some(<<"CONFIG":utf8>>)), BulkString(Some(<<"XXX":utf8>>))])
//   |> resp.encode
//   |> test_err(SyntaxError)
// }

// pub fn parse_config_null_test() {
//   Array([BulkString(Some(<<"CONFIG":utf8>>)), BulkString(None)])
//   |> resp.encode
//   |> test_err(SyntaxError)
// }

// pub fn parse_config_not_utf8_test() {
//   Array([BulkString(Some(<<"CONFIG":utf8>>)), BulkString(Some(<<192, 128>>))])
//   |> resp.encode
//   |> test_err(SyntaxError)
// }

// // config get

// pub fn parse_config_get_test() {
//   Array([
//     BulkString(Some(<<"CONFIG":utf8>>)),
//     BulkString(Some(<<"GET":utf8>>)),
//     BulkString(Some(<<"key":utf8>>)),
//   ])
//   |> resp.encode
//   |> test_ok(ConfigGet(["key"]))
// }

// pub fn parse_config_get_multiple_args_test() {
//   Array([
//     BulkString(Some(<<"CONFIG":utf8>>)),
//     BulkString(Some(<<"GET":utf8>>)),
//     BulkString(Some(<<"key1":utf8>>)),
//     BulkString(Some(<<"key2":utf8>>)),
//   ])
//   |> resp.encode
//   |> test_ok(ConfigGet(["key1", "key2"]))
// }

// pub fn parse_config_get_no_args_test() {
//   Array([BulkString(Some(<<"CONFIG":utf8>>)), BulkString(Some(<<"GET":utf8>>))])
//   |> resp.encode
//   |> test_err(WrongNumberOfArguments)
// }

// // keys

// pub fn parse_keys_no_arg_test() {
//   Array([BulkString(Some(<<"KEYS":utf8>>))])
//   |> resp.encode
//   |> test_err(WrongNumberOfArguments)
// }

// pub fn parse_keys_two_args_test() {
//   Array([
//     BulkString(Some(<<"KEYS":utf8>>)),
//     BulkString(Some(<<"\"x\"":utf8>>)),
//     BulkString(Some(<<"\"y\"":utf8>>)),
//   ])
//   |> resp.encode
//   |> test_err(WrongNumberOfArguments)
// }

// pub fn parse_keys_null_arg_test() {
//   Array([BulkString(Some(<<"KEYS":utf8>>)), BulkString(None)])
//   |> resp.encode
//   |> test_err(InvalidArgument("pattern", Null))
// }

// pub fn parse_keys_arg_is_not_utf8_test() {
//   // overlong encoding of the null character (U+0000), which is invalid in UTF-8
//   Array([
//     BulkString(Some(<<"KEYS":utf8>>)),
//     BulkString(Some(<<"\"":utf8, 192, 128, "\"":utf8>>)),
//   ])
//   |> resp.encode
//   |> test_err(SyntaxError)
// }

// pub fn parse_keys_arg_is_utf8_test() {
//   Array([BulkString(Some(<<"KEYS":utf8>>)), BulkString(Some(<<"*":utf8>>))])
//   |> resp.encode
//   |> test_ok(Keys("*"))
// }

// pub fn test_ok(input, expected) {
//   input
//   |> commands.parse
//   |> should.be_ok
//   |> should.equal(expected)
// }

// pub fn test_err(input, expected) {
//   input
//   |> commands.parse
//   |> should.be_error
//   |> should.equal(expected)
// }
