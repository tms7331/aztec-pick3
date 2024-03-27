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
        secretNum: PrivateMutable<u8>
    }

}
