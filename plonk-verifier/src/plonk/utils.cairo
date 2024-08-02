use core::traits::Into;
use core::byte_array::ByteArrayTrait;
use core::to_byte_array::FormatAsByteArray;

fn convert_le_to_be(le: u256) -> ByteArray {
    let hex_base: NonZero<u256> = 16_u256.try_into().unwrap();
    let mut le = le.format_as_byte_array(hex_base);
    println!("le hex: {}", le);
    if le.len() < 64 {
        le = left_padding_32_bytes(le);
    }
    let mut rev_le: ByteArray = le.rev();
    let mut be_ba: ByteArray = "";

    let mut i = 0;
    while i < rev_le.len() {
        let mut word: ByteArray = "";

        word.append_byte(rev_le[i]);
        word.append_byte(rev_le[i + 1]);

        let rev: ByteArray = word.rev();
        be_ba.append(@rev);
        i += 2;
    };

    be_ba
}

fn left_padding_32_bytes(ba_in: ByteArray) -> ByteArray {
    let mut ba_len = ba_in.len();
    let mut ba_out: ByteArray = ba_in;
    let mut i = 0;

    while i < 64 - ba_len {
        let ba = ByteArrayTrait::concat(@"0", @ba_out);
        ba_out = ba;
        i += 1;
    };

    ba_out
}

// converts a big endian hexadecial byte array to u256 decimal
fn hex_to_decimal(mut hex_string: ByteArray) -> u256 {
    let mut result: u256 = 0;
    let mut power: u256 = 1;
    let mut i = 0;
    hex_string = hex_string.rev();

    while i < hex_string.len() {
        let byte_ascii_value = hex_string[i];
        let mut byte_value = ascii_to_dec(byte_ascii_value);
        let u256_byte_value: u256 = byte_value.into();

        result += u256_byte_value * power;
        if i != hex_string.len() - 1 {
            power *= 16;
        }
        i += 1;
    };
    result
}

fn decimal_to_byte_array(mut n: u256) -> ByteArray {
    let mut byte_array: ByteArray = "";
    let mut hex_ba_n = n.format_as_byte_array(16_u256.try_into().unwrap());

    if hex_ba_n.len() < 64 {
        hex_ba_n = left_padding_32_bytes(hex_ba_n);
    }
    let mut i = 0;
    while i < hex_ba_n.len() {
        let first_byte = ascii_to_dec(hex_ba_n[i]);
        let second_byte = ascii_to_dec(hex_ba_n[i + 1]);
        let mut value: u32 = first_byte * 16_u32;

        value = value + second_byte;
        let byte_word: felt252 = value.into();
        byte_array.append_word(byte_word, 1);
        i += 2;
    };
    byte_array
}

fn ascii_to_dec(mut b: u8) -> u32 {
    let mut b_32: u32 = b.into();
    let mut byte_value = 0;
    if b_32 >= 97 {
        byte_value = b_32 - 87;
    } else {
        byte_value = b_32 - 48;
    }
    byte_value
}

#[test]
fn test_hex_to_decimal() {
    let test_hex_1: ByteArray = "1a45183d6c56cf5364935635b48815116ad40d9382a41e525d9784b4916c2c70";
    let dec_1 = hex_to_decimal(test_hex_1);
    assert_eq!(
        dec_1, 11882213808513143293994894265765176245869305285611379364593291279901519522928
    );

    let test_hex_2: ByteArray = "acc0b671a0e5c50307b930cfd05ed26ff6db6c6aa81ac7f8a1ed11b077a2a7cc";
    let dec_2 = hex_to_decimal(test_hex_2);
    assert_eq!(
        dec_2, 78138303774012846250814548983539832692685901550348365675046268153074630698956
    );

    let test_hex_3: ByteArray = "ff";
    let dec_3 = hex_to_decimal(test_hex_3);
    assert_eq!(dec_3, 255);
}

#[test]
fn test_convert_le_to_be() {
    let test_1: u256 =
        61490746474045761767661087867430693677409928396669494327352779807704464432003;
    let le_1 = convert_le_to_be(test_1);
    assert_eq!(le_1, "831b973f210f2ca7224752808be5c58fa20f316b67823942965aa4517687f287");

    let test_2: u256 =
        19101300766783147186443130233662574138172230046365805365368327481934084863501;
    let le_2 = convert_le_to_be(test_2);
    assert_eq!(le_2, "0d765c165a19aa287707be08978a793366584fc2d5553e76957a1fe7fef33a2a");
}

#[test]
fn test_left_padding_32_bytes() {
    let test_1: ByteArray = "hello";
    let padded_1 = left_padding_32_bytes(test_1);
    assert_eq!(padded_1, "00000000000000000000000000000000000000000000000000000000000hello");

    let test_2: ByteArray = "2c6c91b484975d521ea482930dd46a111588b43556936453cf566c3d18451a";
    let padded_2 = left_padding_32_bytes(test_2);
    assert_eq!(padded_2, "002c6c91b484975d521ea482930dd46a111588b43556936453cf566c3d18451a");
}

#[test]
fn test_ascii_to_dec() {
    let test_1: u8 = 97;
    let dec_1 = ascii_to_dec(test_1);
    assert_eq!(dec_1, 10);

    let test_2: u8 = 48;
    let dec_2 = ascii_to_dec(test_2);
    assert_eq!(dec_2, 0);

    let test_3: u8 = 102;
    let dec_3 = ascii_to_dec(test_3);
    assert_eq!(dec_3, 15);
}
