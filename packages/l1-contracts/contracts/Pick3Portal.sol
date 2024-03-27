// Modified from https://github.com/AztecProtocol/dev-rel/blob/main/tutorials/token-bridge-e2e/packages/l1-contracts/contracts/TokenPortal.sol
pragma solidity >=0.8.18;

import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";

// Messaging
import {IRegistry} from "@aztec/l1-contracts/src/core/interfaces/messagebridge/IRegistry.sol";
import {IInbox} from "@aztec/l1-contracts/src/core/interfaces/messagebridge/IInbox.sol";
import {DataStructures} from "@aztec/l1-contracts/src/core/libraries/DataStructures.sol";
import {Hash} from "@aztec/l1-contracts/src/core/libraries/Hash.sol";

contract Pick3Portal {
    using SafeERC20 for IERC20;

    IRegistry public registry;
    IERC20 public usdc;
    bytes32 public l2Bridge;

    function initialize(
        address _registry,
        address _usdc,
        bytes32 _l2Bridge
    ) external {
        registry = IRegistry(_registry);
        usdc = IERC20(_usdc);
        l2Bridge = _l2Bridge;
    }

    /**
     * @notice Deposit funds into the portal and adds an L2 message which can only be consumed privately on Aztec
     * @param _secretHashForGuess - The hash of the secret to make the guess on Aztec
     * @param _secretHashForL2MessageConsumption - The hash of the secret consumable L1 to L2 message. The hash should be 254 bits (so it can fit in a Field element)
     * @return The key of the entry in the Inbox
     */
    function depositToAztecPrivate(
        bytes32 _secretHashForRedeeming,
        bytes32 _secretHashForL2MessageConsumption
    ) external returns (bytes32) {
        // Preamble
        IInbox inbox = registry.getInbox();
        DataStructures.L2Actor memory actor = DataStructures.L2Actor(
            l2Bridge,
            1
        );

        // Hash the message content to be reconstructed in the receiving contract
        bytes32 contentHash = Hash.sha256ToField(
            abi.encodeWithSignature(
                "make_guess(bytes32)",
                _secretHashForRedeeming,
            )
        );

        // Cost to guess will always be 100 USDC (which has 6 decimals)
        uint256 amount = 100 * 10 ** 6;
        // Store the tokens in this contract
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        // Send message to rollup
        return
            inbox.sendL2Message(
                actor,
                contentHash,
                _secretHashForL2MessageConsumption
            );
    }

    /**
     * @notice Withdraw funds from the portal, only called if the guess was correct
     * @param _recipient - The address to send the funds to
     * @param _amount - The amount to withdraw
     * @return The key of the entry in the Outbox
     */
    function withdraw(
        address _recipient,
        uint256 _amount,
    ) external returns (bytes32) {
        DataStructures.L2ToL1Msg memory message = DataStructures.L2ToL1Msg({
            sender: DataStructures.L2Actor(l2Bridge, 1),
            recipient: DataStructures.L1Actor(address(this), block.chainid),
            content: Hash.sha256ToField(
                abi.encodeWithSignature(
                    "withdraw(address,uint256)",
                    _recipient,
                    _amount,
                )
            )
        });

        bytes32 entryKey = registry.getOutbox().consume(message);

        usdc.transfer(_recipient, _amount);

        return entryKey;
    }
}
