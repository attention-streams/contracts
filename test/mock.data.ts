import { BigNumber } from "ethers";

interface ArenaParams {
    name: string;
    token: string;
    minContributionAmount: BigNumber;
    maxChoiceFeePercentage: BigNumber;
    maxTopicFeePercentage: BigNumber;
    arenaFeePercentage: BigNumber;
    choiceCreationFee: BigNumber;
    topicCreationFee: BigNumber;
};

interface TopicParams {
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

export function getValidArenaParams(): ArenaParams {
    return {
        name: "Test Arena",
        token: "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984",
        minContributionAmount: BigNumber.from(10),
        maxChoiceFeePercentage: BigNumber.from(1),
        maxTopicFeePercentage: BigNumber.from(0),
        arenaFeePercentage: BigNumber.from(10 * 10 ** 2),
        choiceCreationFee: BigNumber.from(10),
        topicCreationFee: BigNumber.from(10),
    };
}

export function getInvalidArenaParams(): ArenaParams {
    return {
        name: "Test Arena",
        token: "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984",
        minContributionAmount: BigNumber.from(10),
        maxChoiceFeePercentage: BigNumber.from(1),
        maxTopicFeePercentage: BigNumber.from(0),
        arenaFeePercentage: BigNumber.from(101 * 10 ** 2),// more than 100% fee
        choiceCreationFee: BigNumber.from(10),
        topicCreationFee: BigNumber.from(10),
    };
}


export function getFlatParamsFromDict(paramsDict: any) {
    return Object.entries(paramsDict).map((e) => e[1]);
}