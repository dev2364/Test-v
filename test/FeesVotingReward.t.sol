pragma solidity 0.8.13;

import "./BaseTest.sol";

contract FeesVotingRewardTest is BaseTest {
    event NotifyReward(address indexed from, address indexed reward, uint256 epoch, uint256 amount);

    function _setUp() public override {
        // ve
        VELO.approve(address(escrow), TOKEN_1);
        escrow.createLock(TOKEN_1, MAXTIME);
        vm.startPrank(address(owner2));
        VELO.approve(address(escrow), TOKEN_1);
        escrow.createLock(TOKEN_1, MAXTIME);
        vm.stopPrank();
        vm.startPrank(address(owner3));
        VELO.approve(address(escrow), TOKEN_1);
        escrow.createLock(TOKEN_1, MAXTIME);
        vm.stopPrank();
        skip(1);
    }

    function testGetRewardWithZeroTotalSupply() public {
        skip(1 weeks / 2);

        // create a reward
        FRAX.approve(address(feesVotingReward), TOKEN_1);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1);

        // vote
        address[] memory pools = new address[](1);
        pools[0] = address(pair);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;
        voter.vote(1, pools, weights);

        skipToNextEpoch(1);

        // check earned is correct
        uint256 earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1);

        // add reward for epoch 2
        FRAX.approve(address(feesVotingReward), TOKEN_1 * 2);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1 * 2);
        // remove supply by voting for other pair
        pools[0] = address(pair2);
        voter.vote(1, pools, weights);

        assertEq(feesVotingReward.totalSupply(), 0);

        skipToNextEpoch(1);

        // check can still claim reward
        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(FRAX);

        uint256 pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        uint256 post = FRAX.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1);
    }

    function testGetRewardWithMultipleStaggeredRewardsInOneEpoch() public {
        skip(1 weeks / 2);

        uint256 reward = TOKEN_1;
        uint256 reward2 = TOKEN_1 * 2;

        // create a reward
        FRAX.approve(address(feesVotingReward), reward);
        feesVotingReward.notifyRewardAmount((address(FRAX)), reward);

        // vote
        address[] memory pools = new address[](1);
        pools[0] = address(pair);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;
        voter.vote(1, pools, weights);

        skip(1 days);

        // create another reward for the same pool in the same epoch
        FRAX.approve(address(feesVotingReward), reward2);
        feesVotingReward.notifyRewardAmount((address(FRAX)), reward2);

        skipToNextEpoch(1);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(FRAX);

        uint256 pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        uint256 post = FRAX.balanceOf(address(owner));

        // expect both rewards
        uint256 totaFRAXeward = reward + reward2;
        assertEq(post - pre, totaFRAXeward);
    }

    function testCannotGetRewardMoreThanOncePerEpochWithSingleReward() public {
        skip(1 weeks / 2);

        // create a reward
        FRAX.approve(address(feesVotingReward), TOKEN_1);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1);

        // vote
        address[] memory pools = new address[](1);
        pools[0] = address(pair);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;
        voter.vote(1, pools, weights);

        vm.prank(address(owner2));
        voter.vote(2, pools, weights);

        skipToNextEpoch(1);

        uint256 pre = FRAX.balanceOf(address(owner));
        uint256 earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1 / 2);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(FRAX);

        vm.startPrank(address(voter));
        // claim first time
        feesVotingReward.getReward(1, rewards);
        uint256 post = FRAX.balanceOf(address(owner));
        skip(1);
        // claim second time
        feesVotingReward.getReward(1, rewards);
        vm.stopPrank();

        uint256 post_post = FRAX.balanceOf(address(owner));
        assertEq(post_post, post);
        assertEq(post_post - pre, TOKEN_1 / 2);
    }

    function testCannotGetRewardMoreThanOncePerEpochWithMultipleRewards() public {
        skip(1 weeks / 2);

        // create a reward
        FRAX.approve(address(feesVotingReward), TOKEN_1);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1);

        // vote
        address[] memory pools = new address[](1);
        pools[0] = address(pair);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;
        voter.vote(1, pools, weights);

        vm.prank(address(owner2));
        voter.vote(2, pools, weights);

        skipToNextEpoch(1);

        uint256 pre = FRAX.balanceOf(address(owner));
        uint256 earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1 / 2);

        // rewards
        address[] memory rewards = new address[](2);
        rewards[0] = address(FRAX);
        rewards[1] = address(FRAX);

        vm.startPrank(address(voter));
        // claim first time
        feesVotingReward.getReward(1, rewards);
        uint256 post = FRAX.balanceOf(address(owner));
        // claim second time
        feesVotingReward.getReward(1, rewards);
        vm.stopPrank();

        uint256 post_post = FRAX.balanceOf(address(owner));
        assertEq(post_post, post);
        assertEq(post_post - pre, TOKEN_1 / 2);
    }

    function testGetRewardWithMultipleVotes() public {
        skip(1 weeks / 2);

        uint256 reward = TOKEN_1;
        uint256 reward2 = TOKEN_1 * 2;

        // create a reward
        FRAX.approve(address(feesVotingReward), reward);
        feesVotingReward.notifyRewardAmount((address(FRAX)), reward);

        // vote
        address[] memory pools = new address[](1);
        pools[0] = address(pair);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        voter.vote(1, pools, weights);

        skipToNextEpoch(1);

        // create another reward for the same pool the following week
        FRAX.approve(address(feesVotingReward), reward2);
        feesVotingReward.notifyRewardAmount((address(FRAX)), reward2);

        voter.vote(1, pools, weights);

        skipToNextEpoch(1);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(FRAX);

        uint256 pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        uint256 post = FRAX.balanceOf(address(owner));

        uint256 totaFRAXeward = reward + reward2;
        assertEq(post - pre, totaFRAXeward);
    }

    function testGetRewardWithVotesForDifferentPoolsAcrossEpochs() public {
        skip(1 weeks / 2);

        uint256 reward = TOKEN_1;
        uint256 reward2 = TOKEN_1 * 2;

        // create a reward for pair in epoch 0
        FRAX.approve(address(feesVotingReward), reward);
        feesVotingReward.notifyRewardAmount((address(FRAX)), reward);

        // vote
        address[] memory pools = new address[](1);
        pools[0] = address(pair);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        voter.vote(1, pools, weights);
        vm.prank(address(owner2));
        voter.vote(2, pools, weights);

        skipToNextEpoch(1);

        // create a reward for pair2 in epoch 1
        FRAX.approve(address(feesVotingReward2), reward2);
        feesVotingReward2.notifyRewardAmount((address(FRAX)), reward2);
        pools[0] = address(pair2);

        voter.vote(1, pools, weights);

        skipToNextEpoch(1);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(FRAX);

        // check rewards accrue correctly for pair
        uint256 pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        uint256 post = FRAX.balanceOf(address(owner));

        assertEq(post - pre, reward / 2);

        // check rewards accrue correctly for pair2
        pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward2.getReward(1, rewards);
        post = FRAX.balanceOf(address(owner));

        assertEq(post - pre, reward2);
    }

    function testGetRewardWithPassiveVote() public {
        skip(1 weeks / 2);

        // create a reward in epoch 0
        FRAX.approve(address(feesVotingReward), TOKEN_1);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1);
        assertEq(FRAX.balanceOf(address(feesVotingReward)), TOKEN_1);

        // vote
        address[] memory pools = new address[](1);
        pools[0] = address(pair);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;
        voter.vote(1, pools, weights);
        skip(1);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(FRAX);

        uint256 earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, 0);

        skipToNextEpoch(1);

        uint256 pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        uint256 post = FRAX.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1);

        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, 0);

        // create another reward in epoch 1 but do not vote
        FRAX.approve(address(feesVotingReward), TOKEN_1 * 2);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1 * 2);
        assertEq(FRAX.balanceOf(address(feesVotingReward)), TOKEN_1 * 2);

        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, 0);

        skipToNextEpoch(1);

        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1 * 2);

        pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        post = FRAX.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 * 2);
    }

    function testGetRewardWithPassiveVotes() public {
        skip(1 weeks / 2);

        // create a reward
        FRAX.approve(address(feesVotingReward), TOKEN_1);
        feesVotingReward.notifyRewardAmount((address(FRAX)), TOKEN_1);

        // vote in epoch 0
        address[] memory pools = new address[](1);
        pools[0] = address(pair);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        voter.vote(1, pools, weights);
        skip(1);

        uint256 earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, 0);

        // epoch 1: five epochs pass, with an incrementing reward
        skipToNextEpoch(1);

        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1);

        FRAX.approve(address(feesVotingReward), TOKEN_1 * 2);
        feesVotingReward.notifyRewardAmount((address(FRAX)), TOKEN_1 * 2);
        skip(1);

        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1);

        // epoch 2
        skipToNextEpoch(1);

        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1 * 3);

        FRAX.approve(address(feesVotingReward), TOKEN_1 * 3);
        feesVotingReward.notifyRewardAmount((address(FRAX)), TOKEN_1 * 3);
        skip(1);

        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1 * 3);

        // epoch 3
        skipToNextEpoch(1);

        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1 * 6);

        FRAX.approve(address(feesVotingReward), TOKEN_1 * 4);
        feesVotingReward.notifyRewardAmount((address(FRAX)), TOKEN_1 * 4);
        skip(1);

        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1 * 6);

        // epoch 4
        skipToNextEpoch(1);

        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1 * 10);

        FRAX.approve(address(feesVotingReward), TOKEN_1 * 5);
        feesVotingReward.notifyRewardAmount((address(FRAX)), TOKEN_1 * 5);
        skip(1);

        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1 * 10);

        // epoch 5
        skipToNextEpoch(1);

        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1 * 15);

        FRAX.approve(address(feesVotingReward), TOKEN_1 * 6);
        feesVotingReward.notifyRewardAmount((address(FRAX)), TOKEN_1 * 6);
        skip(1);

        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1 * 15);

        skipToNextEpoch(1);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(FRAX);

        // total rewards: 1 + 2 + 3 + 4 + 5 + 6
        uint256 pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        uint256 post = FRAX.balanceOf(address(owner));

        assertEq(post - pre, TOKEN_1 * 21);
    }

    function testCannotGetRewardInSameWeekIfEpochYetToFlip() public {
        /// tests that rewards deposited that week cannot be claimed until next week
        skip(1 weeks / 2);

        // create reward in epoch 0
        FRAX.approve(address(feesVotingReward), TOKEN_1);
        feesVotingReward.notifyRewardAmount((address(FRAX)), TOKEN_1);

        // vote in epoch 0
        address[] memory pools = new address[](1);
        pools[0] = address(pair);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        voter.vote(1, pools, weights);

        skipToNextEpoch(1);

        // create reward in epoch 1
        FRAX.approve(address(feesVotingReward), TOKEN_1 * 2);
        feesVotingReward.notifyRewardAmount((address(FRAX)), TOKEN_1 * 2);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(FRAX);

        // claim before flip but after rewards are re-deposited into reward
        uint256 pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        uint256 post = FRAX.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1);

        skipToNextEpoch(1);

        // claim after flip
        pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        post = FRAX.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 * 2);
    }

    function testGetRewardWithSingleVoteAndPoke() public {
        skip(1 weeks / 2);

        uint256 reward = TOKEN_1;
        uint256 reward2 = TOKEN_1 * 2;

        // create a reward in epoch 0
        FRAX.approve(address(feesVotingReward), reward);
        feesVotingReward.notifyRewardAmount((address(FRAX)), reward);

        // vote
        address[] memory pools = new address[](1);
        pools[0] = address(pair);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        voter.vote(1, pools, weights);
        skip(1);

        uint256 earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, 0);

        skipToNextEpoch(1);

        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1);

        // create a reward in epoch 1
        FRAX.approve(address(feesVotingReward), reward2);
        feesVotingReward.notifyRewardAmount((address(FRAX)), reward2);
        skip(1);

        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1);

        voter.poke(1);
        skip(1);

        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1);

        skipToNextEpoch(1);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(FRAX);

        uint256 pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        uint256 post = FRAX.balanceOf(address(owner));

        uint256 total = reward + reward2;
        assertEq(post - pre, total);
    }

    function testGetRewardWithSingleCheckpoint() public {
        skip(1 weeks / 2);

        // create a reward
        FRAX.approve(address(feesVotingReward), TOKEN_1);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1);
        assertEq(FRAX.balanceOf(address(feesVotingReward)), TOKEN_1);

        // vote
        address[] memory pools = new address[](1);
        pools[0] = address(pair);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        voter.vote(1, pools, weights);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(FRAX);

        // cannot claim
        uint256 pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        uint256 post = FRAX.balanceOf(address(owner));
        assertEq(post - pre, 0);

        // fwd half a week
        skipToNextEpoch(1);

        pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        post = FRAX.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1);
    }

    function testGetRewardWithSingleCheckpointWithOtherVoter() public {
        skip(1 weeks / 2);

        // create a reward
        FRAX.approve(address(feesVotingReward), TOKEN_1);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1);
        assertEq(FRAX.balanceOf(address(feesVotingReward)), TOKEN_1);

        // vote
        address[] memory pools = new address[](1);
        pools[0] = address(pair);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        voter.vote(1, pools, weights);

        vm.prank(address(owner2));
        voter.vote(2, pools, weights);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(FRAX);

        skipToNextEpoch(1);

        // deliver reward
        uint256 pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        uint256 post = FRAX.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 / 2);

        pre = FRAX.balanceOf(address(owner2));
        vm.prank(address(voter));
        feesVotingReward.getReward(2, rewards);
        post = FRAX.balanceOf(address(owner2));
        assertEq(post - pre, TOKEN_1 / 2);
    }

    function testGetRewardWithSingleCheckpointWithOtherStaggeredVoter() public {
        skip(1 weeks / 2);

        // create a reward
        FRAX.approve(address(feesVotingReward), TOKEN_1);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1);
        assertEq(FRAX.balanceOf(address(feesVotingReward)), TOKEN_1);

        // vote
        address[] memory pools = new address[](1);
        pools[0] = address(pair);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        voter.vote(1, pools, weights);

        // vote delayed
        skip(1 days);
        vm.prank(address(owner2));
        voter.vote(2, pools, weights);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(FRAX);

        // fwd
        skipToNextEpoch(1);

        // deliver reward
        uint256 pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        uint256 post = FRAX.balanceOf(address(owner));
        assertGt(post - pre, TOKEN_1 / 2); // 500172176312657261
        uint256 diff = post - pre;

        pre = FRAX.balanceOf(address(owner2));
        vm.prank(address(voter));
        feesVotingReward.getReward(2, rewards);
        post = FRAX.balanceOf(address(owner2));
        assertLt(post - pre, TOKEN_1 / 2); // 499827823687342738
        uint256 diff2 = post - pre;

        assertEq(diff + diff2, TOKEN_1 - 1); // -1 for rounding
    }

    function testGetRewardWithSkippedClaims() public {
        skip(1 weeks / 2);

        uint256 reward = TOKEN_1; // epoch 0 reward
        uint256 reward2 = TOKEN_1 * 2; // epoch1 reward
        uint256 reward3 = TOKEN_1 * 3; // epoch3 reward

        // create reward with amount reward in epoch 0
        FRAX.approve(address(feesVotingReward), reward);
        feesVotingReward.notifyRewardAmount(address(FRAX), reward);
        assertEq(FRAX.balanceOf(address(feesVotingReward)), reward);

        // vote for pool
        address[] memory pools = new address[](1);
        pools[0] = address(pair);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        voter.vote(1, pools, weights);
        vm.prank(address(owner2));
        voter.vote(2, pools, weights);

        skipToNextEpoch(1);

        // check reward amount is correct
        uint256 expectedReward = reward / 2;
        uint256 earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, expectedReward);
        earned = feesVotingReward.earned(address(FRAX), 2);
        assertEq(earned, expectedReward);

        // create reward with amount reward2 in epoch 1
        FRAX.approve(address(feesVotingReward), reward2);
        feesVotingReward.notifyRewardAmount(address(FRAX), reward2);
        assertEq(FRAX.balanceOf(address(feesVotingReward)), reward + reward2);

        // vote again for same pool
        voter.vote(1, pools, weights);
        vm.prank(address(owner2));
        voter.vote(2, pools, weights);

        skipToNextEpoch(1);

        expectedReward = (reward + reward2) / 2;
        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, expectedReward);
        earned = feesVotingReward.earned(address(FRAX), 2);
        assertEq(earned, expectedReward);

        // create reward with amount reward3 in epoch 2
        FRAX.approve(address(feesVotingReward), reward3);
        feesVotingReward.notifyRewardAmount(address(FRAX), reward3);
        assertEq(FRAX.balanceOf(address(feesVotingReward)), reward + reward2 + reward3);

        // poked into voting for same pool
        voter.poke(1);
        voter.poke(2);

        skipToNextEpoch(1);

        expectedReward = (reward + reward2 + reward3) / 2;
        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, expectedReward);
        earned = feesVotingReward.earned(address(FRAX), 2);
        assertEq(earned, expectedReward);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(FRAX);

        uint256 pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        uint256 post = FRAX.balanceOf(address(owner));
        assertEq(post - pre, expectedReward);

        pre = FRAX.balanceOf(address(owner2));
        vm.prank(address(voter));
        feesVotingReward.getReward(2, rewards);
        post = FRAX.balanceOf(address(owner2));
        assertEq(post - pre, expectedReward);
    }

    function testCannotClaimRewardForPoolIfPokedButVotedForOtherPool() public {
        skip(1 weeks / 2);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(FRAX);

        // set up votes
        address[] memory pools = new address[](1);
        address[] memory pools2 = new address[](1);
        uint256[] memory weights = new uint256[](1);
        pools[0] = address(pair);
        pools2[0] = address(pair2);
        weights[0] = 10000;

        // create a reward in epoch 0
        FRAX.approve(address(feesVotingReward), TOKEN_1);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1);

        // vote for pair in epoch 0
        voter.vote(1, pools, weights);
        vm.prank(address(owner2));
        voter.vote(2, pools, weights);

        skipToNextEpoch(1);

        uint256 pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        uint256 post = FRAX.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 / 2);

        pre = FRAX.balanceOf(address(owner2));
        vm.prank(address(voter));
        feesVotingReward.getReward(2, rewards);
        post = FRAX.balanceOf(address(owner2));
        assertEq(post - pre, TOKEN_1 / 2);

        skip(1);

        // create a reward for pair in epoch 1
        FRAX.approve(address(feesVotingReward), TOKEN_1);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1);
        // create a reward for pair2 in epoch 1
        FRAX.approve(address(feesVotingReward2), TOKEN_1 * 2);
        feesVotingReward2.notifyRewardAmount(address(FRAX), TOKEN_1 * 2);
        skip(1);

        // poke causes id 1 to "vote" for pair
        voter.poke(1);
        skip(1);

        // vote for pair2 in epoch 1
        voter.vote(1, pools2, weights);

        // go to next epoch
        skipToNextEpoch(1);

        // earned for pair should be 0
        uint256 earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, 0);

        // earned for pair for nft 2 should be full reward amount
        earned = feesVotingReward.earned(address(FRAX), 2);
        assertEq(earned, TOKEN_1);

        // earned for pair2 should be TOKEN_1
        earned = feesVotingReward2.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1 * 2);

        pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward2.getReward(1, rewards);
        post = FRAX.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 * 2);
    }

    function testGetRewardWithAlternatingVotes() public {
        skip(1 weeks / 2);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(FRAX);

        // set up votes
        address[] memory pools = new address[](1);
        address[] memory pools2 = new address[](1);
        uint256[] memory weights = new uint256[](1);
        pools[0] = address(pair);
        pools2[0] = address(pair2);
        weights[0] = 10000;

        // create a reward in epoch 0
        FRAX.approve(address(feesVotingReward), TOKEN_1);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1);

        // vote for pair in epoch 0
        voter.vote(1, pools, weights);
        vm.prank(address(owner2));
        voter.vote(2, pools, weights);
        skip(1);

        // fwd half a week
        skipToNextEpoch(1);

        uint256 pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        uint256 post = FRAX.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 / 2);

        uint256 earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, 0);
        skip(1);

        // create a reward for pair in epoch 1
        FRAX.approve(address(feesVotingReward), TOKEN_1);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1);
        // create a reward for pair2 in epoch 1
        FRAX.approve(address(feesVotingReward2), TOKEN_1 * 2);
        feesVotingReward2.notifyRewardAmount(address(FRAX), TOKEN_1 * 2);
        skip(1);

        voter.vote(1, pools2, weights);
        vm.prank(address(owner3));
        voter.vote(3, pools2, weights);

        // go to next week
        skipToNextEpoch(1);

        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, 0);

        voter.vote(1, pools, weights);

        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, 0);
        earned = feesVotingReward2.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1);

        pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward2.getReward(1, rewards);
        post = FRAX.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1);
    }

    // same test as above but with some initial checkpoints in place
    function testGetRewardWithAlternatingVotesWithInitialCheckpoints() public {
        skip(1 weeks / 2);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(FRAX);

        // set up votes
        address[] memory pools = new address[](1);
        address[] memory pools2 = new address[](1);
        uint256[] memory weights = new uint256[](1);
        pools[0] = address(pair);
        pools2[0] = address(pair2);
        weights[0] = 10000;

        // add initial checkpoints
        for (uint256 i = 0; i < 5; i++) {
            // vote for pair in epoch 0
            voter.vote(1, pools, weights);
            vm.prank(address(owner2));
            voter.vote(2, pools, weights);
            skip(1);

            // fwd half a week
            skipToNextEpoch(1);
        }

        // create a reward in epoch 0
        FRAX.approve(address(feesVotingReward), TOKEN_1);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1);

        // vote for pair in epoch 0
        voter.vote(1, pools, weights);
        vm.prank(address(owner2));
        voter.vote(2, pools, weights);
        skip(1);

        // fwd half a week
        skipToNextEpoch(1);

        uint256 pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        uint256 post = FRAX.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 / 2);

        uint256 earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, 0);
        skip(1);

        // create a reward for pair in epoch 1
        FRAX.approve(address(feesVotingReward), TOKEN_1);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1);
        // create a reward for pair2 in epoch 1
        FRAX.approve(address(feesVotingReward2), TOKEN_1 * 2);
        feesVotingReward2.notifyRewardAmount(address(FRAX), TOKEN_1 * 2);
        skip(1);

        voter.vote(1, pools2, weights);
        vm.prank(address(owner3));
        voter.vote(3, pools2, weights);

        // go to next week
        skipToNextEpoch(1);

        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, 0);

        voter.vote(1, pools, weights);

        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, 0);
        earned = feesVotingReward2.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1);

        pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward2.getReward(1, rewards);
        post = FRAX.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1);
    }

    function testCannotClaimRewardForPoolIfPokedButReset() public {
        skip(1 weeks / 2);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(FRAX);

        // set up votes
        address[] memory pools = new address[](1);
        uint256[] memory weights = new uint256[](1);
        pools[0] = address(pair);
        weights[0] = 10000;

        // create a reward in epoch 0
        FRAX.approve(address(feesVotingReward), TOKEN_1);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1);

        // vote for pair in epoch 0
        voter.vote(1, pools, weights);
        vm.prank(address(owner2));
        voter.vote(2, pools, weights);

        skipToNextEpoch(1);

        uint256 pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        uint256 post = FRAX.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 / 2);
        skip(1);

        // create a reward for pair in epoch 1
        FRAX.approve(address(feesVotingReward), TOKEN_1);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1);
        skip(1);

        // poke causes id 1 to "vote" for pair
        voter.poke(1);
        skip(1);

        // abstain in epoch 1
        voter.reset(1);

        // go to next epoch
        skipToNextEpoch(1);

        // earned for pair should be 0
        uint256 earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, 0);
    }

    function testGetRewardWithVoteThenPoke() public {
        /// tests poking makes no difference to voting outcome
        skip(1 weeks / 2);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(FRAX);

        // set up votes
        address[] memory pools = new address[](1);
        uint256[] memory weights = new uint256[](1);
        pools[0] = address(pair);
        weights[0] = 10000;

        // create a reward in epoch 0
        FRAX.approve(address(feesVotingReward), TOKEN_1);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1);

        // vote for pair in epoch 0
        voter.vote(1, pools, weights);
        vm.prank(address(owner2));
        voter.vote(2, pools, weights);

        skipToNextEpoch(1);

        uint256 pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        uint256 post = FRAX.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 / 2);
        skip(1);

        // create a reward for pair in epoch 1
        FRAX.approve(address(feesVotingReward), TOKEN_1);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1);
        skip(1);

        voter.vote(1, pools, weights);
        skip(1 hours);

        // get poked an hour later
        voter.poke(1);
        vm.prank(address(owner2));
        voter.vote(2, pools, weights);

        // go to next epoch
        skipToNextEpoch(1);

        // earned for pair should be 0
        uint256 earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1 / 2);
    }

    function testGetRewardWithVotesForMultiplePools() public {
        skip(1 weeks / 2);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(FRAX);

        // set up votes
        address[] memory pools = new address[](2);
        uint256[] memory weights = new uint256[](2);
        pools[0] = address(pair);
        pools[1] = address(pair2);
        weights[0] = 2;
        weights[1] = 8;

        // create a reward in epoch 0 for pair
        FRAX.approve(address(feesVotingReward), TOKEN_1);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1);
        // create a usdc reward in epoch 1 for pair2
        USDC.approve(address(feesVotingReward2), USDC_1);
        feesVotingReward2.notifyRewardAmount(address(USDC), USDC_1);

        // vote for pair in epoch 0
        voter.vote(1, pools, weights); // 20% to pair, 80% to pair2

        // flip weights around
        weights[0] = 8;
        weights[1] = 2;
        vm.prank(address(owner2));
        voter.vote(2, pools, weights); // 80% to pair, 20% to pair2

        skipToNextEpoch(1);

        // check pair rewards are correct
        uint256 pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        uint256 post = FRAX.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 / 5);

        pre = FRAX.balanceOf(address(owner2));
        vm.prank(address(voter));
        feesVotingReward.getReward(2, rewards);
        post = FRAX.balanceOf(address(owner2));
        assertEq(post - pre, (TOKEN_1 * 4) / 5);

        // check pair2 rewards are correct
        rewards[0] = address(USDC);
        pre = USDC.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward2.getReward(1, rewards);
        post = USDC.balanceOf(address(owner));
        assertEq(post - pre, (USDC_1 * 4) / 5);

        pre = USDC.balanceOf(address(owner2));
        vm.prank(address(voter));
        feesVotingReward2.getReward(2, rewards);
        post = USDC.balanceOf(address(owner2));
        assertEq(post - pre, USDC_1 / 5);
    }

    function testCannotGetRewardForNewPoolVotedAfterEpochFlip() public {
        skip(1 weeks / 2);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(FRAX);

        // set up votes
        address[] memory pools = new address[](1);
        uint256[] memory weights = new uint256[](1);
        pools[0] = address(pair);
        weights[0] = 10000;

        // create a reward for pair and pair2 in epoch 0
        FRAX.approve(address(feesVotingReward), TOKEN_1);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1);
        USDC.approve(address(feesVotingReward2), USDC_1);
        feesVotingReward2.notifyRewardAmount(address(USDC), USDC_1);

        // vote for pair in epoch 0
        voter.vote(1, pools, weights);
        vm.prank(address(owner2));
        voter.vote(2, pools, weights);

        // owner3 votes for pair2
        pools[0] = address(pair2);
        vm.prank(address(owner3));
        voter.vote(3, pools, weights);

        // go to next epoch but do not distribute
        skipToNextEpoch(1);

        // vote for pair2 shortly after epoch flips
        voter.vote(1, pools, weights);
        skip(1);

        // attempt to claim from initial pool currently voted for fails
        uint256 pre = USDC.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward2.getReward(1, rewards);
        uint256 post = USDC.balanceOf(address(owner));
        assertEq(post - pre, 0);

        // claim last week's rewards
        pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        post = FRAX.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 / 2);
    }

    function testCannotGetRewardInSameEpochAsVote() public {
        skip(1 weeks / 2);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(FRAX);

        // set up votes
        address[] memory pools = new address[](1);
        uint256[] memory weights = new uint256[](1);
        pools[0] = address(pair);
        weights[0] = 10000;

        // create a reward for pair in epoch 0
        FRAX.approve(address(feesVotingReward), TOKEN_1);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1);
        skip(1);

        // vote for pair in epoch 0
        voter.vote(1, pools, weights);
        vm.prank(address(owner2));
        voter.vote(2, pools, weights);
        skip(1);

        uint256 pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        uint256 post = FRAX.balanceOf(address(owner));
        assertEq(post - pre, 0);

        skipToNextEpoch(1);

        // create a reward for pair in epoch 1
        FRAX.approve(address(feesVotingReward), TOKEN_1 * 2);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1 * 2);
        skip(1);

        // vote for pair in epoch 1
        voter.vote(1, pools, weights);
        vm.prank(address(owner2));
        voter.vote(2, pools, weights);
        skip(1);

        // attempt claim again after vote, only get rewards from epoch 0
        pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        post = FRAX.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 / 2);

        skipToNextEpoch(1);

        pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        post = FRAX.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1);
    }

    function testCannotGetRewardIfNotVoterOrOwnerOrApproved() public {
        skip(1 weeks / 2);

        uint256 reward = TOKEN_1;

        // create a bribe
        FRAX.approve(address(feesVotingReward), reward);
        feesVotingReward.notifyRewardAmount((address(FRAX)), reward);

        // vote
        address[] memory pools = new address[](1);
        pools[0] = address(pair);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;
        voter.vote(1, pools, weights);

        skipToNextEpoch(1);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(FRAX);

        vm.prank(address(owner2));
        vm.expectRevert("VotingReward: unpermissioned");
        feesVotingReward.getReward(1, rewards);
    }

    function testGetRewardWithVoteAndNotifyRewardInDifferentOrders() public {
        skip(1 weeks / 2);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(FRAX);

        // set up votes
        address[] memory pools = new address[](1);
        uint256[] memory weights = new uint256[](1);
        pools[0] = address(pair);
        weights[0] = 10000;

        // create a reward for pair in epoch 0
        FRAX.approve(address(feesVotingReward), TOKEN_1);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1);
        skip(1);

        // vote for pair in epoch 0
        voter.vote(1, pools, weights);
        vm.prank(address(owner2));
        voter.vote(2, pools, weights);
        skip(1);

        uint256 earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, 0);

        skipToNextEpoch(1);

        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1 / 2);

        // vote first, then create reward
        voter.vote(1, pools, weights);
        vm.prank(address(owner2));
        voter.vote(2, pools, weights);
        skip(1);

        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1 / 2);

        FRAX.approve(address(feesVotingReward), TOKEN_1 * 2);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1 * 2);
        skip(1);

        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1 / 2);

        skipToNextEpoch(1);

        earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, (TOKEN_1 * 3) / 2);

        uint256 pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        uint256 post = FRAX.balanceOf(address(owner));
        assertEq(post - pre, (TOKEN_1 * 3) / 2);
    }

    function testDepositAndWithdrawCreatesCheckpoints() public {
        skip(1 weeks / 2);

        uint256 numSupply = feesVotingReward.supplyNumCheckpoints();
        assertEq(numSupply, 0); // no existing checkpoints

        (uint256 ts, uint256 balance) = feesVotingReward.checkpoints(1, 0);
        assertEq(ts, 0);
        assertEq(balance, 0);

        // deposit by voting
        address[] memory pools = new address[](1);
        pools[0] = address(pair);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;
        voter.vote(1, pools, weights);

        uint256 expectedTs = block.timestamp;
        uint256 expectedBal = escrow.balanceOfNFT(1);

        // check single user and supply checkpoint created
        numSupply = feesVotingReward.supplyNumCheckpoints();
        assertEq(numSupply, 1);
        (uint256 sTs, uint256 sBalance) = feesVotingReward.supplyCheckpoints(0);
        assertEq(sTs, expectedTs);
        assertEq(sBalance, expectedBal);

        (ts, balance) = feesVotingReward.checkpoints(1, 0);
        assertEq(ts, expectedTs);
        assertEq(balance, expectedBal);

        skipToNextEpoch(1);

        // withdraw by voting for other pool
        pools[0] = address(pair2);
        voter.vote(1, pools, weights);

        numSupply = feesVotingReward.supplyNumCheckpoints();
        assertEq(numSupply, 2);

        expectedTs = block.timestamp;

        // check new checkpoint created
        (ts, balance) = feesVotingReward.checkpoints(1, 1);
        assertEq(ts, expectedTs);
        assertEq(balance, 0); // balance 0 on withdraw
        (sTs, sBalance) = feesVotingReward.supplyCheckpoints(1);
        assertEq(sTs, expectedTs);
        assertEq(sBalance, 0);

        skipToNextEpoch(1);
    }

    function testDepositAndWithdrawFWithinSameEpochOverwritesCheckpoints() public {
        skip(1 weeks / 2);

        // test vote and poke overwrites checkpoints
        // deposit by voting
        address[] memory pools = new address[](1);
        pools[0] = address(pair);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        voter.vote(1, pools, weights);

        uint256 expectedTs = block.timestamp;
        uint256 expectedBal = escrow.balanceOfNFT(1);

        // check single user and supply checkpoint created
        uint256 numSupply = feesVotingReward.supplyNumCheckpoints();
        assertEq(numSupply, 1);

        (uint256 sTs, uint256 sBalance) = feesVotingReward.supplyCheckpoints(0);
        assertEq(sTs, expectedTs);
        assertEq(sBalance, expectedBal);

        (uint256 ts, uint256 balance) = feesVotingReward.checkpoints(1, 0);
        assertEq(ts, expectedTs);
        assertEq(balance, expectedBal);

        // poked after one day. any checkpoints created should overwrite prior checkpoints.
        skip(1 days);
        voter.poke(1);

        expectedTs = block.timestamp;
        expectedBal = escrow.balanceOfNFT(1);

        numSupply = feesVotingReward.supplyNumCheckpoints();
        assertEq(numSupply, 1);
        (sTs, sBalance) = feesVotingReward.supplyCheckpoints(0);
        assertEq(sTs, expectedTs);
        assertEq(sBalance, expectedBal);

        (ts, balance) = feesVotingReward.checkpoints(1, 0);
        assertEq(ts, expectedTs);
        assertEq(sBalance, expectedBal);

        // check poke and reset/withdraw overwrites checkpoints
        skipToNextEpoch(0); // expect checkpoint to be created on boundary of epoch

        // poke to create a checkpoint in new epoch
        voter.poke(1);

        // check old checkpoints are not overridden
        numSupply = feesVotingReward.supplyNumCheckpoints();
        assertEq(numSupply, 2);
        (sTs, sBalance) = feesVotingReward.supplyCheckpoints(0);
        assertEq(sTs, expectedTs);
        assertEq(sBalance, expectedBal);

        (ts, balance) = feesVotingReward.checkpoints(1, 0);
        assertEq(ts, expectedTs);
        assertEq(sBalance, expectedBal);

        expectedTs = block.timestamp;
        expectedBal = escrow.balanceOfNFT(1);

        numSupply = feesVotingReward.supplyNumCheckpoints();
        assertEq(numSupply, 2);
        (sTs, sBalance) = feesVotingReward.supplyCheckpoints(1);
        assertEq(sTs, expectedTs);
        assertEq(sBalance, expectedBal);

        (ts, balance) = feesVotingReward.checkpoints(1, 1);
        assertEq(ts, expectedTs);
        assertEq(sBalance, expectedBal);

        // withdraw via reset after one day, expect supply to be zero
        skip(1 days);
        voter.reset(1);

        expectedTs = block.timestamp;

        numSupply = feesVotingReward.supplyNumCheckpoints();
        assertEq(numSupply, 2);
        (sTs, sBalance) = feesVotingReward.supplyCheckpoints(1);
        assertEq(sTs, expectedTs);
        assertEq(sBalance, 0);

        (ts, balance) = feesVotingReward.checkpoints(1, 1);
        assertEq(ts, expectedTs);
        assertEq(sBalance, 0);
    }

    function testDepositFromManyUsersInSameTimestampOverwritesSupplyCheckpoint() public {
        skip(1 weeks / 2);

        // deposit by voting
        address[] memory pools = new address[](1);
        pools[0] = address(pair);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        // test two (supply) checkpoints at same ts
        voter.vote(1, pools, weights);

        uint256 ownerBal = escrow.balanceOfNFT(1);
        uint256 owner2Bal = escrow.balanceOfNFT(2);
        uint256 totalSupply = ownerBal + owner2Bal;

        // check single user and supply checkpoint created
        uint256 numSupply = feesVotingReward.supplyNumCheckpoints();
        assertEq(numSupply, 1);
        (uint256 sTs, uint256 sBalance) = feesVotingReward.supplyCheckpoints(0);
        assertEq(sTs, block.timestamp);
        assertEq(sBalance, ownerBal);

        (uint256 ts, uint256 balance) = feesVotingReward.checkpoints(1, 0);
        assertEq(ts, block.timestamp);
        assertEq(balance, ownerBal);

        vm.prank(address(owner2));
        voter.vote(2, pools, weights);

        numSupply = feesVotingReward.supplyNumCheckpoints();
        assertEq(numSupply, 1);
        (sTs, sBalance) = feesVotingReward.supplyCheckpoints(0);
        assertEq(sTs, block.timestamp);
        assertEq(sBalance, totalSupply);

        (ts, balance) = feesVotingReward.checkpoints(2, 0);
        assertEq(ts, block.timestamp);
        assertEq(balance, owner2Bal);
    }

    function testGetRewardWithSeparateRewardClaims() public {
        skip(1 weeks / 2);

        // create a FRAX reward
        FRAX.approve(address(feesVotingReward), TOKEN_1);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1);

        // vote
        address[] memory pools = new address[](1);
        pools[0] = address(pair);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;
        voter.vote(1, pools, weights);

        vm.prank(address(owner2));
        voter.vote(2, pools, weights);

        skipToNextEpoch(1);

        // create usdc reward, vote passively this epoch
        USDC.approve(address(feesVotingReward), USDC_1);
        feesVotingReward.notifyRewardAmount(address(USDC), USDC_1);

        uint256 earned = feesVotingReward.earned(address(FRAX), 1);
        assertEq(earned, TOKEN_1 / 2);

        earned = feesVotingReward.earned(address(USDC), 1);
        assertEq(earned, 0);

        skipToNextEpoch(1);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(FRAX);

        // claim FRAX reward first
        uint256 pre = FRAX.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        uint256 post = FRAX.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 / 2);

        skipToNextEpoch(1);

        // claim USDC the week after
        rewards[0] = address(USDC);
        pre = USDC.balanceOf(address(owner));
        vm.prank(address(voter));
        feesVotingReward.getReward(1, rewards);
        post = USDC.balanceOf(address(owner));
        assertEq(post - pre, USDC_1 / 2);
    }

    function testCannotNotifyRewardWithZeroAmount() public {
        vm.expectRevert("Reward: zero amount");
        feesVotingReward.notifyRewardAmount(address(FRAX), 0);
    }

    function testCannotNotifyRewardWithInvalidRewardToken() public {
        vm.expectRevert("FeesVotingReward: invalid reward");
        feesVotingReward.notifyRewardAmount(address(WETH), TOKEN_1);
    }

    function testNotifyRewardAmountWithValidRewardToken() public {
        FRAX.approve(address(feesVotingReward), TOKEN_1);
        vm.expectEmit(true, false, false, true, address(feesVotingReward));
        emit NotifyReward(address(owner), address(FRAX), 604800, TOKEN_1);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1);

        assertEq(feesVotingReward.tokenRewardsPerEpoch(address(FRAX), 604800), TOKEN_1);
        assertEq(FRAX.balanceOf(address(feesVotingReward)), TOKEN_1);

        skip(1 hours);

        FRAX.approve(address(feesVotingReward), TOKEN_1 * 2);
        vm.expectEmit(true, false, false, true, address(feesVotingReward));
        emit NotifyReward(address(owner), address(FRAX), 604800, TOKEN_1 * 2);
        feesVotingReward.notifyRewardAmount(address(FRAX), TOKEN_1 * 2);

        assertEq(feesVotingReward.tokenRewardsPerEpoch(address(FRAX), 604800), TOKEN_1 * 3);
        assertEq(FRAX.balanceOf(address(feesVotingReward)), TOKEN_1 * 3);
    }
}