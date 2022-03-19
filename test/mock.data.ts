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
    arena: string; // arena contract address

    cycleDuration: Number;
    sharePerCyclePercentage: Number;

    prevContributorsFee: Number;
    topicFeePercentage: Number;

    maxChoiceFundFeePercentage: Number;

    relativeSupportThreshold: Number;
    fundingPeriod: Number;
    fundingPercentage: Number;
    hasExternalFunding: Boolean
}

export function getValidTopicParams(arenaAddress: string): TopicParams {
    return {
        arena: arenaAddress,
        cycleDuration: 100, // 100 cycles
        sharePerCyclePercentage: 100 * 10 ** 2,
        prevContributorsFee: 10 * 10 ** 2,
        topicFeePercentage: 5 * 10 ** 2,

        maxChoiceFundFeePercentage: 25 * 10 ** 2,

        relativeSupportThreshold: 0,
        fundingPeriod: 0,
        fundingPercentage: 0,
        hasExternalFunding: false
    }
}

export function getValidArenaParams(): ArenaParams {
    return {
        name: "Test Arena",
        token: "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984",
        minContributionAmount: BigNumber.from(10),
        maxChoiceFeePercentage: 100, // 1 percent
        maxTopicFeePercentage: 0,
        arenaFeePercentage: 1000, // 10 percent
        choiceCreationFee: BigNumber.from(10),
        topicCreationFee: BigNumber.from(10),
    };
}

export function getInvalidArenaParams(): ArenaParams {
    return {
        name: "Test Arena",
        token: "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984",
        minContributionAmount: BigNumber.from(10),
        maxChoiceFeePercentage: 0,
        maxTopicFeePercentage: 0,
        arenaFeePercentage: 10100,// more than 100% fee
        choiceCreationFee: BigNumber.from(10),
        topicCreationFee: BigNumber.from(10),
    };
}


export function getFlatParamsFromDict(paramsDict: any) {
    return Object.entries(paramsDict).map((e) => e[1]);
}