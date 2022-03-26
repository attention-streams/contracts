import { BigNumber } from "ethers";

export interface ArenaParams {
    name: string;
    token: string;
    minContributionAmount: BigNumber;
    maxChoiceFeePercentage: Number;
    maxTopicFeePercentage: Number;
    arenaFeePercentage: Number;
    choiceCreationFee: BigNumber;
    topicCreationFee: BigNumber;
};

export interface TopicParams {
    cycleDuration: Number;
    sharePerCyclePercentage: Number;

    prevContributorsFeePercentage: Number;
    topicFeePercentage: Number;

    maxChoiceFeePercentage: Number;

    relativeSupportThreshold: Number;
    fundingPeriod: Number;
    fundingPercentage: Number;
}


export interface ChoiceParams {
    description: string;
    fundsAddress: string;
    feePercentage: Number;
    fundingTarget: BigNumber;
}

export function getValidChoiceParams(): ChoiceParams {
    return {
        description: "choice A",
        fundsAddress: "0x90F79bf6EB2c4f870365E785982E1f101E93b906",
        feePercentage: 1000, // 10 %
        fundingTarget: BigNumber.from("0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")
    }
}

export function getValidTopicParams(): TopicParams {
    return {
        cycleDuration: 100, // 100 blocks
        sharePerCyclePercentage: 100 * 10 ** 2, // 100%

        prevContributorsFeePercentage: 10 * 10 ** 2, // 10 %
        topicFeePercentage: 5 * 10 ** 2, // 5%

        maxChoiceFeePercentage: 25 * 10 ** 2, // 25%

        relativeSupportThreshold: 0,
        fundingPeriod: 0,
        fundingPercentage: 0
    }
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
    };
}

export function getFlatParamsFromDict(paramsDict: any): any[] {
    return Object.entries(paramsDict).map((e) => e[1]);
}