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

    #[aztec(public)]
    #[aztec(initializer)]
    fn constructor(admin: AztecAddress) {
        assert(!admin.is_zero(), "invalid admin");
        storage.admin.write(admin);
        storage.prize_pool.initialize(0);
        // Initialize secret num to 1000 (to avoid exploit where someone guesses 0 before 
        // game is fully set up - our check that number is 3 digits will block it)
        storage.secret_num.initialize(0);
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
            let amount = storage.prize_pool;
            // TODO - how can we compute hash?
            let content = compute_hash_somehow(recipient, amount);
            context.message_portal(content);

            // Reset game...
            storage.prize_pool.write(0);
        }
        // Should we emit an event or something if they guess wrong?
    }

    // Consumes a L1->L2 message and calls the token contract to mint the appropriate amount in private assets
    #[aztec(private)]
    fn claim_and_make_guess_private(
        secret_hash_for_redeeming: Field, // Corresponds to value in Pick3Portal.sol
        canceller: EthAddress,
        msg_key: Field, // L1 to L2 message key as derived from the inbox contract
        secret_for_L1_to_L2_message_consumption: Field // secret used to consume the L1 to L2 message
        pick3_guess: U128,  // Separate from the claim, we'll include our guess and cashout address for if we win
        recipient: EthAddress,
    ) {
        // Consume L1 to L2 message and emit nullifier
        let content_hash = compute_hash_somehow(secret_hash_for_redeeming, canceller);
        context.consume_l1_to_l2_message(msg_key, content_hash, secret_for_L1_to_L2_message_consumption);

        // If we've made it past the check, we can proceed with their guess
        context.call_public_function(
            context.this_address(),
            FunctionSelector::from_signature("_make_guess(U128,EthAddress)"),
            [pick3_guess, recipient]
        );
    }
}