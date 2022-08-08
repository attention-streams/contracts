import { BigNumber, BigNumberish } from "ethers";

export interface ArenaParams {
  name: string;
  token: string;
  minContributionAmount: BigNumber;
  maxChoiceFeePercentage: number;
  maxTopicFeePercentage: number;
  arenaFeePercentage: number;
  choiceCreationFee: BigNumber;
  topicCreationFee: BigNumber;
  funds: string;
}

export interface TopicParams {
  cycleDuration: number;
  startBlock: BigNumberish;
  sharePerCyclePercentage: number;

  prevContributorsFeePercentage: number;
  topicFeePercentage: number;

  maxChoiceFeePercentage: number;

  relativeSupportThreshold: number;
  fundingPeriod: number;
  fundingPercentage: number;
  funds: string;
}

export interface ChoiceParams {
  description: string;
  funds: string;
  feePercentage: number;
  fundingTarget: BigNumber;
  metaDataUrl: string;
}

export function getValidChoiceParams(): ChoiceParams {
  return {
    description: "choice A",
    funds: "0x90F79bf6EB2c4f870365E785982E1f101E93b906",
    feePercentage: 1000, // 10 %
    fundingTarget: BigNumber.from(
      "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
    ),
    metaDataUrl: "",
  };
}

export function getValidChoiceBParams(): ChoiceParams {
  return {
    description: "choice B",
    funds: "0xdD2FD4581271e230360230F9337D5c0430Bf44C0",
    feePercentage: 1500, // 15 %
    fundingTarget: BigNumber.from(
      "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
    ),
    metaDataUrl: "",
  };
}

export function getValidTopicParams(): TopicParams {
  return {
    cycleDuration: 100, // 100 blocks
    startBlock: 0,
    sharePerCyclePercentage: 100 * 10 ** 2, // 100%

    prevContributorsFeePercentage: 12 * 10 ** 2, // 12 %
    topicFeePercentage: 5 * 10 ** 2, // 5%

    maxChoiceFeePercentage: 25 * 10 ** 2, // 25%

    relativeSupportThreshold: 0,
    fundingPeriod: 0,
    fundingPercentage: 0,
    funds: "0x71bE63f3384f5fb98995898A86B02Fb2426c5788",
  };
}

export function getValidArenaParams(): ArenaParams {
  return {
    name: "Test Arena",
    token: "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984",
    minContributionAmount: BigNumber.from(10),
    maxChoiceFeePercentage: 3000, // 1 percent
    maxTopicFeePercentage: 500, // 5 percent
    arenaFeePercentage: 1000, // 10 percent
    choiceCreationFee: BigNumber.from(0),
    topicCreationFee: BigNumber.from(0),
    funds: "0xFABB0ac9d68B0B445fB7357272Ff202C5651694a",
  };
}

export function getFlatParamsFromDict(paramsDict: any): any[] {
  return Object.entries(paramsDict).map((e) => e[1]);
}
