// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// ERC20 Interface for custom token functionality
interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

// Ownable for access control
contract Ownable {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        owner = newOwner;
    }
}

// Governance Contract to decide on investments
contract Governance is Ownable {
    struct Proposal {
        address projectAddress;
        string projectDescription;
        uint256 votesFor;
        uint256 votesAgainst;
        bool active;
        uint256 deadline;
    }

    Proposal[] public proposals;
    uint256 public proposalCount;
    IERC20 public token;

    mapping(address => bool) public voters;
    mapping(uint256 => mapping(address => bool)) public hasVoted; // Proposal ID -> Voter -> Voted?

    uint256 public votingPeriod = 7 days;
    uint256 public quorumThreshold = 1000 * 10**18; // Minimum tokens needed to pass proposal

    event ProposalCreated(uint256 proposalId, address projectAddress, string description);
    event Voted(uint256 proposalId, address voter, bool inFavor);

    constructor(address tokenAddress) {
        token = IERC20(tokenAddress);
    }

    function createProposal(address project, string memory description) public onlyOwner {
        proposals.push(Proposal({
            projectAddress: project,
            projectDescription: description,
            votesFor: 0,
            votesAgainst: 0,
            active: true,
            deadline: block.timestamp + votingPeriod
        }));

        emit ProposalCreated(proposalCount, project, description);
        proposalCount++;
    }

    function vote(uint256 proposalId, bool voteFor) public {
        require(proposals[proposalId].active, "Proposal is not active");
        require(block.timestamp <= proposals[proposalId].deadline, "Voting period has ended");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        uint256 voterBalance = token.balanceOf(msg.sender);
        require(voterBalance > 0, "Must hold tokens to vote");

        if (voteFor) {
            proposals[proposalId].votesFor += voterBalance;
        } else {
            proposals[proposalId].votesAgainst += voterBalance;
        }

        hasVoted[proposalId][msg.sender] = true;
        voters[msg.sender] = true;

        emit Voted(proposalId, msg.sender, voteFor);
    }

    function finalizeProposal(uint256 proposalId) public onlyOwner {
        require(proposals[proposalId].active, "Proposal already finalized");
        require(block.timestamp > proposals[proposalId].deadline, "Voting period not over");

        uint256 totalVotes = proposals[proposalId].votesFor + proposals[proposalId].votesAgainst;
        require(totalVotes >= quorumThreshold, "Not enough votes to pass proposal");

        if (proposals[proposalId].votesFor > proposals[proposalId].votesAgainst) {
            proposals[proposalId].active = false; // Mark as funded
            investInProject(proposals[proposalId].projectAddress);
        } else {
            proposals[proposalId].active = false; // Mark as rejected
        }
    }

    function investInProject(address project) internal {
        // Implement complex funding logic here.
        // Sending funds, handling staking, etc.
    }
}

// Core Decentralized Venture Capital Fund Contract
contract DAVCFund is Ownable {
    IERC20 public stablecoin;
    Governance public governance;
    
    uint256 public totalFunds; // Total pooled capital

    mapping(address => uint256) public stakes; // Each user’s investment amount

    event FundDeposited(address investor, uint256 amount);
    event FundWithdrawn(address investor, uint256 amount);
    event ProjectFunded(address project, uint256 amount);

    constructor(address stablecoinAddress, address governanceAddress) {
        stablecoin = IERC20(stablecoinAddress);
        governance = Governance(governanceAddress);
    }

    function depositFunds(uint256 amount) public {
        require(stablecoin.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        totalFunds += amount;
        stakes[msg.sender] += amount;

        emit FundDeposited(msg.sender, amount);
    }

    function withdrawFunds(uint256 amount) public {
        require(stakes[msg.sender] >= amount, "Insufficient funds");

        totalFunds -= amount;
        stakes[msg.sender] -= amount;

        require(stablecoin.transfer(msg.sender, amount), "Transfer failed");

        emit FundWithdrawn(msg.sender, amount);
    }

    function fundProject(address project, uint256 amount) public onlyOwner {
        require(totalFunds >= amount, "Not enough funds");

        totalFunds -= amount;

        require(stablecoin.transfer(project, amount), "Transfer failed");

        emit ProjectFunded(project, amount);
    }
}
