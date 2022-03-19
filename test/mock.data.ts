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

    cycleDuration: BigNumber;
    sharePerCyclePercentage: BigNumber;

    prevContributorsFee: BigNumber;
    topicFeePercentage: BigNumber;

    maxChoiceFundFeePercentage: BigNumber;

    relativeSupportThreshold: BigNumber;
    fundingPeriod: BigNumber;
    fundingPercentage: BigNumber;
}

export function getValidTopicParams(arenaAddress: string): TopicParams {
    return {
        arena: arenaAddress,
        cycleDuration: BigNumber.from(100),
        sharePerCyclePercentage: BigNumber.from(100 * 10 ** 2),
        prevContributorsFee: BigNumber.from(10 * 10 ** 2),
        topicFeePercentage: BigNumber.from(5 * 10 ** 2),

        maxChoiceFundFeePercentage: BigNumber.from(25 * 10 ** 2),

        relativeSupportThreshold: BigNumber.from(0),
        fundingPeriod: BigNumber.from(0),
        fundingPercentage: BigNumber.from(0)
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