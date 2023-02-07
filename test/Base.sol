pragma solidity 0.8.13;

import {ManagedRewardsFactory} from "contracts/factories/ManagedRewardsFactory.sol";
import {VotingRewardsFactory} from "contracts/factories/VotingRewardsFactory.sol";
import {GaugeFactory} from "contracts/factories/GaugeFactory.sol";
import {PairFactory, IPairFactory} from "contracts/factories/PairFactory.sol";
import {FactoryRegistry} from "contracts/FactoryRegistry.sol";
import {Minter} from "contracts/Minter.sol";
import {Reward} from "contracts/rewards/Reward.sol";
import {FeesVotingReward} from "contracts/rewards/FeesVotingReward.sol";
import {BribeVotingReward} from "contracts/rewards/BribeVotingReward.sol";
import {FreeManagedReward} from "contracts/rewards/FreeManagedReward.sol";
import {LockedManagedReward} from "contracts/rewards/LockedManagedReward.sol";
import {Gauge} from "contracts/Gauge.sol";
import {PairFees} from "contracts/PairFees.sol";
import {RewardsDistributor} from "contracts/RewardsDistributor.sol";
import {Router, IRouter} from "contracts/Router.sol";
import {IVelo, Velo} from "contracts/Velo.sol";
import {Voter} from "contracts/Voter.sol";
import {VeArtProxy} from "contracts/VeArtProxy.sol";
import {IVotingEscrow, VotingEscrow} from "contracts/VotingEscrow.sol";
import {VeloGovernor} from "contracts/VeloGovernor.sol";
import {EpochGovernor} from "contracts/EpochGovernor.sol";
import {SinkManager} from "contracts/v1/sink/SinkManager.sol";
import {SinkDrain} from "contracts/v1/sink/SinkDrain.sol";
import {SinkConverter} from "contracts/v1/sink/SinkConverter.sol";
import {IGaugeV1} from "contracts/interfaces/v1/IGaugeV1.sol";
import {IVoterV1} from "contracts/interfaces/v1/IVoterV1.sol";
import {IVotingEscrowV1} from "contracts/interfaces/v1/IVotingEscrowV1.sol";
import {IWETH} from "contracts/interfaces/IWETH.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";

/// @notice Base contract used for tests and deployment scripts
/// TODO: where should this file be placed?
abstract contract Base is Script, Test {
    enum Deployment {
        DEFAULT,
        FORK,
        CUSTOM
    }
    /// @dev Determines whether or not to use the base set up configuration
    ///      Local v2 deployment used by default
    Deployment deploymentType;

    IWETH WETH;
    Velo VELO;
    address[] tokens;

    /// @dev Core v2 Deployment
    Router router;
    VotingEscrow escrow;
    PairFactory factory;
    FactoryRegistry factoryRegistry;
    GaugeFactory gaugeFactory;
    VotingRewardsFactory votingRewardsFactory;
    ManagedRewardsFactory managedRewardsFactory;
    Voter voter;
    RewardsDistributor distributor;
    Minter minter;
    Gauge gauge;
    VeloGovernor governor;
    EpochGovernor epochGovernor;

    /// @dev velodrome v1 contracts
    Velo vVELO;
    IVotingEscrowV1 vEscrow;
    IVoterV1 vVoter;
    PairFactory vFactory;
    Router vRouter;
    VeloGovernor vGov;
    RewardsDistributor vDistributor;
    Minter vMinter;

    /// @dev additional contracts required by v2
    SinkManager sinkManager;
    IGaugeV1 gaugeSinkDrain;
    SinkDrain sinkDrain;
    SinkConverter sinkConverter;

    /// @dev tokenId of nft owned by black hole
    uint256 ownedTokenId;

    /// @dev Global address to set
    address allowedManager;
    address team;

    function _coreSetup() public {
        deployFactories();

        VeArtProxy artProxy = new VeArtProxy();
        escrow = new VotingEscrow(address(VELO), address(artProxy), address(factoryRegistry), team);

        // Setup voter
        voter = new Voter(address(escrow), address(factoryRegistry));

        escrow.setVoter(address(voter));
        escrow.setAllowedManager(allowedManager);

        // Setup router
        router = new Router(address(factory), address(voter), address(WETH));

        // Setup minter
        distributor = new RewardsDistributor(address(escrow));
        minter = new Minter(address(voter), address(escrow), address(distributor));
        distributor.setDepositor(address(minter));
        VELO.setMinter(address(minter));

        /// @dev tokens are already set in the respective setupBefore()
        voter.initialize(tokens, address(minter));

        // Setup governors
        governor = new VeloGovernor(escrow);
        epochGovernor = new EpochGovernor(escrow, address(minter));
        voter.setEpochGovernor(address(epochGovernor));
        voter.setGovernor(address(governor));
    }

    function _sinkSetup() public {
        // layer on additional contracts required by v2 deployment
        /// @dev manager.setOwnedTokenId()/setSinkDrain() ar(e) set in either forkSetupAfter()
        sinkManager = new SinkManager(
            address(vVoter),
            address(vVELO),
            address(VELO),
            address(vEscrow),
            address(escrow),
            address(vDistributor)
        );

        sinkDrain = new SinkDrain(address(sinkManager));
        sinkConverter = new SinkConverter(address(sinkManager));

        factory.setSinkConverter(address(sinkConverter), address(vVELO), address(VELO));
        VELO.setSinkManager(address(sinkManager));
    }

    function _loadV1(string memory chainName) public {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/script/constants/");
        path = string.concat(path, chainName);
        path = string.concat(path, ".json");

        string memory json = vm.readFile(path);

        vVELO = Velo(abi.decode(vm.parseJson(json, ".v1.VELO"), (address)));
        vEscrow = IVotingEscrowV1(abi.decode(vm.parseJson(json, ".v1.Escrow"), (address)));
        vVoter = IVoterV1(abi.decode(vm.parseJson(json, ".v1.Voter"), (address)));
        vFactory = PairFactory(abi.decode(vm.parseJson(json, ".v1.Factory"), (address)));
        vRouter = Router(payable(abi.decode(vm.parseJson(json, ".v1.Router"), (address))));
        vGov = VeloGovernor(payable(abi.decode(vm.parseJson(json, ".v1.Gov"), (address))));
        vDistributor = RewardsDistributor(abi.decode(vm.parseJson(json, ".v1.Distributor"), (address)));
        vMinter = Minter(abi.decode(vm.parseJson(json, ".v1.Minter"), (address)));
    }

    function deployFactories() public {
        factory = new PairFactory();
        // TODO: set correct fees
        factory.setFee(true, 1); // set fee back to 0.01% for old tests
        factory.setFee(false, 1);

        votingRewardsFactory = new VotingRewardsFactory();
        gaugeFactory = new GaugeFactory();
        managedRewardsFactory = new ManagedRewardsFactory();
        factoryRegistry = new FactoryRegistry(
            address(factory),
            address(votingRewardsFactory),
            address(gaugeFactory),
            address(managedRewardsFactory)
        );
    }
}