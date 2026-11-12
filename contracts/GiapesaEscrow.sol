// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20Escrow {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

contract GiapesaEscrow {
    address public immutable admin;
    IERC20Escrow public immutable token;
    address[3] public approvers;
    uint256 public nextMilestoneId = 1;
    uint256 private entered = 1;

    struct Agreement {
        address payable subcontractor;
        uint256 totalAmount;
        uint256 fundedAmount;
        uint256 paidAmount;
        uint256 allocatedAmount;
        bool exists;
    }

    struct Milestone {
        bytes32 agreementKey;
        uint256 amount;
        uint8 approvals;
        uint8 votes;
        bool paid;
        bool exists;
        bytes32 evidenceHash;
    }

    mapping(bytes32 => Agreement) public agreements;
    mapping(uint256 => Milestone) public milestones;

    event AgreementCreated(bytes32 indexed agreementKey, address indexed subcontractor, uint256 totalAmount);
    event EscrowFunded(bytes32 indexed agreementKey, address indexed funder, uint256 amount);
    event MilestoneCreated(uint256 indexed milestoneId, bytes32 indexed agreementKey, uint256 amount, string title, string condition);
    event EvidenceSubmitted(uint256 indexed milestoneId, bytes32 indexed evidenceHash, address indexed submittedBy);
    event MilestoneApproved(uint256 indexed milestoneId, address indexed approver, uint8 approvals);
    event MilestonePaid(uint256 indexed milestoneId, bytes32 indexed agreementKey, address indexed subcontractor, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "GIAPESA: only admin");
        _;
    }

    modifier nonReentrant() {
        require(entered == 1, "GIAPESA: reentrant call");
        entered = 2;
        _;
        entered = 1;
    }

    constructor(address tokenAddress, address[3] memory approverAddresses) {
        require(tokenAddress != address(0) && tokenAddress.code.length > 0, "GIAPESA: invalid token");
        admin = msg.sender;
        token = IERC20Escrow(tokenAddress);

        for (uint256 i = 0; i < approverAddresses.length; i++) {
            address approver = approverAddresses[i];
            require(approver != address(0) && approver != msg.sender, "GIAPESA: invalid approver");
            for (uint256 j = 0; j < i; j++) {
                require(approver != approverAddresses[j], "GIAPESA: duplicate approver");
            }
            approvers[i] = approver;
        }
    }

    function createAgreement(bytes32 agreementKey, address payable subcontractor, uint256 totalAmount) external onlyAdmin {
        require(agreementKey != bytes32(0) && !agreements[agreementKey].exists, "GIAPESA: agreement exists");
        require(subcontractor != address(0) && totalAmount > 0, "GIAPESA: invalid agreement");

        agreements[agreementKey] = Agreement({
            subcontractor: subcontractor,
            totalAmount: totalAmount,
            fundedAmount: 0,
            paidAmount: 0,
            allocatedAmount: 0,
            exists: true
        });
        emit AgreementCreated(agreementKey, subcontractor, totalAmount);
    }

    function createMilestone(bytes32 agreementKey, uint256 amount, string calldata title, string calldata condition)
        external
        onlyAdmin
        returns (uint256 milestoneId)
    {
        Agreement storage agreement = agreements[agreementKey];
        require(agreement.exists, "GIAPESA: unknown agreement");
        require(amount > 0 && agreement.allocatedAmount + amount <= agreement.totalAmount, "GIAPESA: invalid amount");
        require(bytes(title).length > 0 && bytes(condition).length > 0, "GIAPESA: missing milestone details");

        milestoneId = nextMilestoneId++;
        agreement.allocatedAmount += amount;
        milestones[milestoneId] = Milestone({
            agreementKey: agreementKey,
            amount: amount,
            approvals: 0,
            votes: 0,
            paid: false,
            exists: true,
            evidenceHash: bytes32(0)
        });
        emit MilestoneCreated(milestoneId, agreementKey, amount, title, condition);
    }

    function deposit(bytes32 agreementKey, uint256 amount) external onlyAdmin nonReentrant {
        Agreement storage agreement = agreements[agreementKey];
        require(agreement.exists && amount > 0, "GIAPESA: invalid deposit");
        require(agreement.fundedAmount + amount <= agreement.totalAmount, "GIAPESA: exceeds agreement amount");
        require(token.transferFrom(msg.sender, address(this), amount), "GIAPESA: token transfer failed");
        agreement.fundedAmount += amount;
        emit EscrowFunded(agreementKey, msg.sender, amount);
    }

    function submitEvidence(uint256 milestoneId, bytes32 evidenceHash) external {
        Milestone storage milestone = milestones[milestoneId];
        require(milestone.exists && !milestone.paid, "GIAPESA: invalid milestone");
        Agreement storage agreement = agreements[milestone.agreementKey];
        require(msg.sender == agreement.subcontractor || msg.sender == admin, "GIAPESA: unauthorized submitter");
        require(evidenceHash != bytes32(0), "GIAPESA: empty evidence hash");
        milestone.evidenceHash = evidenceHash;
        emit EvidenceSubmitted(milestoneId, evidenceHash, msg.sender);
    }

    function approveMilestone(uint256 milestoneId) external nonReentrant {
        Milestone storage milestone = milestones[milestoneId];
        require(milestone.exists && !milestone.paid, "GIAPESA: invalid milestone");
        require(milestone.evidenceHash != bytes32(0), "GIAPESA: evidence required");

        uint8 approverIndex = type(uint8).max;
        for (uint8 i = 0; i < approvers.length; i++) {
            if (msg.sender == approvers[i]) {
                approverIndex = i;
                break;
            }
        }
        require(approverIndex < 3, "GIAPESA: unauthorized approver");
        uint8 voteMask = uint8(1 << approverIndex);
        require(milestone.votes & voteMask == 0, "GIAPESA: already approved");

        milestone.votes |= voteMask;
        milestone.approvals++;
        emit MilestoneApproved(milestoneId, msg.sender, milestone.approvals);

        if (milestone.approvals >= 2) {
            Agreement storage agreement = agreements[milestone.agreementKey];
            require(agreement.fundedAmount - agreement.paidAmount >= milestone.amount, "GIAPESA: insufficient escrow");
            milestone.paid = true;
            agreement.paidAmount += milestone.amount;
            require(token.transfer(agreement.subcontractor, milestone.amount), "GIAPESA: payment failed");
            emit MilestonePaid(milestoneId, milestone.agreementKey, agreement.subcontractor, milestone.amount);
        }
    }
}