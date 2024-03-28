# Aztec zkPick3

Built for Encode Club ZK Bootcamp.  

zkPick3 is a spin on a popular lottery game played in the US, called Pick3. 

In Pick3, Players select a unique 3 digit number and "commit" to it by purchasing a ticket with that unique number.  Then, there’s a draw that happens at the end of the day, and a random number is selected as the winner.  Those that purchased a ticket with a matching number win the jackpot.  In zkPick3, we leverage privacy, zkproofs, and the Aztec network to build a similar game that’s onchain and verifiable, and uses tokens too!

## Aztec

Aztec is a compelling platform for building an implementation of Pick3 because of the integrated cross chain functionality.  Bridging has always been a poor user experience, yet many web3 game offerings require users to bridge funds to obscure networks.  However, with Aztec we're able to instead lock user funds on L1 only for the duration of the game, while leveraging the unique privacy features of Aztec for our game implementation.  Aztec's integrated message portal system streamlines building this functionality.

## User Flow

On L1, a user calls the "depositToAztecPrivate" function of the deployed Pick3Portal contract.  This function transfers 100 USDC from the user and locks it in the portal contract.  The portal contract sends a message to the Aztec L2 Inbox.  Now on Aztec, a user can call the "claim_and_make_guess_private" function.  This function verifies that the user has successfully purchased a ticket on L1, and then allows the user to make a guess at a 3 digit number.  If the guess is correct, the lottery winnings are automatically credited back to the user via the Aztec message portal, enabling the user to claim their winnings on L1.  If the guess is incorrect the jackpot increases by 100 USDC.

## Challenges

Overall, there were a lot of moving parts since we interact with the proof system, Ethereum L1, and Aztec L2, so setting everything up was a challenge.  We were unable to fully set up the Aztec dev environment, which resulted in serious challenges including difficulty compiling contracts and building tests.


## Dependencies
1. Node >= v18

2. Docker

3. Hardhat

4. A running updated Aztec sandbox

```bash
bash -i <(curl -s install.aztec.network) 
aztec-sandbox
```


### Installing

Run this in the root dir, ie `aztec-pick3`. This will install packages required for `src` and `l1-contracts`.

```bash
cd packages/src && yarn && cd ..
cd l1-contracts && yarn && cd ..
```
### Compiling

You need to compile L1 and L2 contracts before you can test them. Run this in the root dir.

```bash
cd packages/aztec-contracts/pick3 && aztec-nargo compile
aztec-cli codegen target -o ../../src/test/fixtures --ts
cd ../../l1-contracts && npx hardhat compile
```

