use core::traits::Into;
use core::byte_array::ByteArrayTrait;
use core::to_byte_array::FormatAsByteArray;

fn convert_le_to_be(le: u256) -> ByteArray {
    let hex_base: NonZero<u256> = 16_u256.try_into().unwrap();
    let mut le = le.format_as_byte_array(hex_base);

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
