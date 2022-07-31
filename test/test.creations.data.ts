import { BigNumber, BigNumberish } from "ethers";

export interface ArenaParams {
  _name: string;
  _token: string;
  _minContributionAmount: BigNumber;
  _maxChoiceFeePercentage: number;
  _maxTopicFeePercentage: number;
  _arenaFeePercentage: number;
  _choiceCreationFee: BigNumber;
  _topicCreationFee: BigNumber;
  _funds: string;
}

export interface TopicParams {
  _cycleDuration: number;
  _sharePerCyclePercentage: number;

  _prevContributorsFeePercentage: number;
  _topicFeePercentage: number;

  _maxChoiceFeePercentage: number;

  _relativeSupportThreshold: number;
  _fundingPeriod: number;
  _fundingPercentage: number;
  _funds: string;
}

export interface ChoiceParams {
  _description: string;
  _funds: string;
  _feePercentage: number;
  _fundingTarget: BigNumber;
  _accFeePershare: BigNumberish;
}

export function getValidChoiceParams(): ChoiceParams {
  return {
    _description: "choice A",
    _funds: "0x90F79bf6EB2c4f870365E785982E1f101E93b906",
    _feePercentage: 1000, // 10 %
    _fundingTarget: BigNumber.from(
      "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
    ),
    _accFeePershare: BigNumber.from(0),
  };
}

export function getValidChoiceBParams(): ChoiceParams {
  return {
    _description: "choice B",
    _funds: "0xdD2FD4581271e230360230F9337D5c0430Bf44C0",
    _feePercentage: 1500, // 15 %
    _fundingTarget: BigNumber.from(
      "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
    ),
    _accFeePershare: BigNumber.from(0),
  };
}

export function getValidTopicParams(): TopicParams {
  return {
    _cycleDuration: 100, // 100 blocks
    _sharePerCyclePercentage: 100 * 10 ** 2, // 100%

    _prevContributorsFeePercentage: 12 * 10 ** 2, // 12 %
    _topicFeePercentage: 5 * 10 ** 2, // 5%

    _maxChoiceFeePercentage: 25 * 10 ** 2, // 25%

    _relativeSupportThreshold: 0,
    _fundingPeriod: 0,
    _fundingPercentage: 0,
    _funds: "0x71bE63f3384f5fb98995898A86B02Fb2426c5788",
  };
}

export function getValidArenaParams(): ArenaParams {
  return {
    _name: "Test Arena",
    _token: "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984",
    _minContributionAmount: BigNumber.from(10),
    _maxChoiceFeePercentage: 3000, // 1 percent
    _maxTopicFeePercentage: 500, // 5 percent
    _arenaFeePercentage: 1000, // 10 percent
    _choiceCreationFee: BigNumber.from(0),
    _topicCreationFee: BigNumber.from(0),
    _funds: "0xFABB0ac9d68B0B445fB7357272Ff202C5651694a",
  };
}

export function getFlatParamsFromDict(paramsDict: any): any[] {
  return Object.entries(paramsDict).map((e) => e[1]);
}
