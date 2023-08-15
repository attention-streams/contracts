# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```

# attention

todo:
[ ] The public and external function signatures and public storage items in https://github.com/spsina/attention/blob/main/contracts/Choice.sol are ok, except the constructor should only take the topic. The contributorFee and cycleShareGrowth( or shareAccrualRate -- whatever we decide to call it) should be defined in the topic and read from the topic when setting the immutables.
@
