import binary_utils.{Big, Little}
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn binary_to_int_test() {
  <<"123":utf8>>
  |> binary_utils.binary_to_int
  |> should.be_ok
  |> should.equal(123)
}

pub fn binary_to_int_negative_int_test() {
  <<"-123":utf8>>
  |> binary_utils.binary_to_int
  |> should.be_ok
  |> should.equal(-123)
}

pub fn binary_to_int_not_an_int_test() {
  <<"abc":utf8>>
  |> binary_utils.binary_to_int
  |> should.be_error
  |> should.equal(Nil)
}

pub fn binary_to_int_letters_and_numbers_test() {
  <<"123abc":utf8>>
  |> binary_utils.binary_to_int
  |> should.be_error
  |> should.equal(Nil)
}

pub fn binary_to_int_empty_test() {
  <<>>
  |> binary_utils.binary_to_int
  |> should.be_error
  |> should.equal(Nil)
}

pub fn binary_to_int_integer_bytes_test() {
  <<1:int-size(8)>>
  |> binary_utils.binary_to_int
  |> should.be_error
  |> should.equal(Nil)
}

pub fn decode_unsigned_int_test() {
  <<1:int-size(8)>>
  |> binary_utils.decode_unsigned_int(Big)
  |> should.be_ok
  |> should.equal(1)
}

pub fn decode_unsigned_int_not_byte_aligned_test() {
  <<1:int-size(9)>>
  |> binary_utils.decode_unsigned_int(Big)
  |> should.be_error
  |> should.equal(Nil)
}

pub fn decode_unsigned_int_empty_binary_test() {
  <<>>
  |> binary_utils.decode_unsigned_int(Big)
  |> should.be_ok
  |> should.equal(0)
}
