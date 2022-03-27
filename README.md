# Attention Streams

This project is an implementation of [Attention Streams](https://docs.google.com/document/d/1TKA-K8YadRdgz-Qek01TUcCkRaI9CKCXGtJ31AbVWIU/edit?usp=sharing).

## Quick start
clone this repo in desired location:
```shell
git clone https://github.com/attention-streams/contracts.git
```
cd into the repo
```shell
cd contracts
```
install dependencies
```shell
npm install
```
generate types from contracts for tests
```shell
npx hardhat typechain
```
run test in a local hardhat blockchain
```shell
npx hardhat test
```


Try running some of the following tasks:

```shell
npx hardhat accounts
npx hardhat compile
npx hardhat clean
npx hardhat test
npx hardhat node
npx hardhat help
REPORT_GAS=true npx hardhat test
npx hardhat coverage
npx hardhat run scripts/deploy.ts
TS_NODE_FILES=true npx ts-node scripts/deploy.ts
npx eslint '**/*.{js,ts}'
npx eslint '**/*.{js,ts}' --fix
npx prettier '**/*.{json,sol,md}' --check
npx prettier '**/*.{json,sol,md}' --write
npx solhint 'contracts/**/*.sol'
npx solhint 'contracts/**/*.sol' --fix
```
