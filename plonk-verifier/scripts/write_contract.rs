use dotenv::dotenv;
use std::env;

use starknet::{
    accounts::{Account, Call, ExecutionEncoding, SingleOwnerAccount},
    core::{
        chain_id,
        types::{BlockId, BlockTag, Felt},
        utils::get_selector_from_name,
    },
    providers::{
        jsonrpc::{HttpTransport, JsonRpcClient},
        Url,
    },
    signers::{LocalWallet, SigningKey},
};

#[tokio::main]
async fn main() {

    let rpc_url = env::var("RPC_URL").unwrap_or_else(|_| {
        eprintln!("RPC_URL not set in the environment.");
        std::process::exit(1);
    });

    let private_key = env::var("PRIVATE_KEY").unwrap_or_else(|_| {
        eprintln!("PRIVATE_KEY not set in the environment.");
        std::process::exit(1);
    });

    let address = env::var("ADDRESS").unwrap_or_else(|_| {
        eprintln!("ADDRESS not set in the environment.");
        std::process::exit(1);
    });

    let provider = JsonRpcClient::new(HttpTransport::new(
        Url::parse(rpc_url).unwrap(),
    ));

    let signer = LocalWallet::from(SigningKey::from_secret_scalar(
        Felt::from_hex(private_key).unwrap(),
    ));
    let address = Felt::from_hex(address).unwrap();
    
    let tst_token_address =
        Felt::from_hex("07394cbe418daa16e42b87ba67372d4ab4a5df0b05c6e554d158458ce245bc10").unwrap();

    let mut account = SingleOwnerAccount::new(
        provider,
        signer,
        address,
        chain_id::SEPOLIA,
        ExecutionEncoding::New,
    );

    // `SingleOwnerAccount` defaults to checking nonce and estimating fees against the latest
    // block. Optionally change the target block to pending with the following line:
    account.set_block_id(BlockId::Tag(BlockTag::Pending));

    let result = account
        .execute_v1(vec![Call {
            to: tst_token_address,
            selector: get_selector_from_name("mint").unwrap(),
            calldata: vec![
                address,
                Felt::from_dec_str("1000000000000000000000").unwrap(),
                Felt::ZERO,
            ],
        }])
        .send()
        .await
        .unwrap();

    println!("Transaction hash: {:#064x}", result.transaction_hash);
}