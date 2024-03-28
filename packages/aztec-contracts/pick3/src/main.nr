contract Pick3 {
    use dep::aztec::protocol_types::{
        abis::function_selector::FunctionSelector,
        address::{
            AztecAddress,
            EthAddress,
        },
    };

    // Storage structure, containing all storage, and specifying what slots they use.
    struct Storage {
        admin: PublicMutable<AztecAddress>,
        secret_num: PrivateMutable<U128>,
        prize_pool: PublicMutable<Field>,
    }

    pub fn compute_withdraw_hash(
        recipient: EthAddress,
        amount: Field,
    ) -> Field {
        // Based off hash calculation here:
        // https://docs.aztec.network/developers/tutorials/uniswap/swap_publicly
        let mut hash_bytes = [0; 68]; // 2 fields of 32 bytes each + 4 bytes fn selector

        let recipient_bytes = recipient.to_field().to_be_bytes(32);
        let amount_bytes = amount.to_be_bytes(32);

        // function selector: 0xf3fef3a3 keccak256("withdraw(address,uint256)")
        hash_bytes[0] = 0xf3;
        hash_bytes[1] = 0xfe;
        hash_bytes[2] = 0xf3;
        hash_bytes[3] = 0xa3;

        for i in 0..32 {
            hash_bytes[i + 4] = recipient_bytes[i];
            hash_bytes[i + 36] = amount_bytes[i];
        }

        let content_hash = sha256_to_field(hash_bytes);
        content_hash
    }

    pub fn get_make_guess_content_hash(
        recipient: EthAddress,
    ) -> Field {
        let mut hash_bytes = [0; 36];
        let recipient_bytes = recipient.to_field().to_be_bytes(32);

        for i in 0..32 {
            hash_bytes[i + 4] = recipient_bytes[i];
        }
        // Function selector: 0xd161a8eb keccak256('make_guess(bytes32)')
        hash_bytes[0] = 0xd1;
        hash_bytes[1] = 0x61;
        hash_bytes[2] = 0xa8;
        hash_bytes[3] = 0xeb;

        let content_hash = sha256_to_field(hash_bytes);
        content_hash
    }

    #[aztec(public)]
    #[aztec(initializer)]
    fn constructor(admin: AztecAddress) {
        assert(!admin.is_zero(), "invalid admin");
        storage.admin.write(admin);
        storage.prize_pool.initialize(0);
        // Initialize secret num to 1000 (to avoid exploit where someone guesses 0 before 
        // game is fully set up - our check that number is 3 digits will block it)
        storage.secret_num.initialize(1000);
    }

    #[aztec(private)]
    fn set_secret_num(secret_num: AztecAddress) {
        assert(storage.admin.read().eq(context.msg_sender()), "caller is not admin");
        storage.secret_num.write(secret_num);
    }

    #[aztec(public)]
    internal fn _make_guess(pick3_guess: U128, recipient: EthAddress) {
        // Hardcoding 100 USDC as cost to play
        storage.prize_pool.write(storage.prize_pool + 100);
        if pick3_guess > 999 {
            panic("Invalid guess");
        }
        // If they guessed the number - cash out full prize pool!
        if storage.secret_num == pick3_guess {
            // Have to convert amount to 6 decimals to match USDC precision
            let amount = storage.prize_pool * 10**6;
            let content = compute_withdraw_hash(recipient, amount);
            context.message_portal(content);
            // context.message_portal(context.this_portal_address(), content_hash);

            // Reset game...
            storage.prize_pool.write(0);
        }
        // Should we emit an event or something if they guess wrong?
    }

    // Consumes a L1->L2 message and allows user to make a guess at 3 digit number
    #[aztec(private)]
    fn claim_and_make_guess_private(
        msg_key: Field, // L1 to L2 message key as derived from the inbox contract
        secret_for_L1_to_L2_message_consumption: Field // secret used to consume the L1 to L2 message
        pick3_guess: U128,  // Separate from the claim, we'll include our guess and cashout address for if we win
        recipient: EthAddress,
    ) {
        // Consume L1 to L2 message and emit nullifier
        let content_hash = get_make_guess_content_hash(recipient);
        context.consume_l1_to_l2_message(msg_key, content_hash, secret_for_L1_to_L2_message_consumption);

        // If we've made it past the check, we can proceed with their guess
        context.call_public_function(
            context.this_address(),
            FunctionSelector::from_signature("_make_guess(U128,EthAddress)"),
            [pick3_guess, recipient]
        );
    }
}