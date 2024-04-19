// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Ownable {

    constructor() Ownable(msg.sender) {
    }

    // Structure d'un votant
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    // Structure d'une proposition 
    struct Proposal {
        string description;
        uint voteCount;
        uint id;
    }

    // status d'une session
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    // events
    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);

    mapping(address => Voter) whiteList; // whitelist des votants
    Proposal[] proposals; // liste des proposition
    WorkflowStatus status; // current status

    /**
      * Permet de déterminer si on est sur un status precis pour la session
      * @param _status WorkflowStatus
      */
    modifier isStatus(WorkflowStatus _status) {
        require(status == _status, "You can't do this action, wait the phase");
        _;
    }

    /**
      * Permet de start les propositions
      */
    function startProposal() external onlyOwner {
        require(status == WorkflowStatus.RegisteringVoters, "It must be registering voter before");
        status = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, status);
    }

    /**
      * Permet de start les votes
      */
    function startVote() external onlyOwner {
        require(status == WorkflowStatus.ProposalsRegistrationEnded, "It must be the end of proposal before");
        status = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, status);
    }

    /**
      * Permet de terminer les propositions
      */
    function endProposal() external onlyOwner {
        require(status == WorkflowStatus.ProposalsRegistrationStarted, "It must proposal session");
        status = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, status);
    }

    /**
      * Permet de terminer les votes
      */
    function endVote() external onlyOwner {
        require(status == WorkflowStatus.VotingSessionStarted, "It must be voting session");
        status = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, status);
    }

    /**
      * Permet de rendre public les votes
      */
    function publishResult() external onlyOwner {
        require(status == WorkflowStatus.VotingSessionEnded, "It must be the end of the session");
        status = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, status);
    }

    /**
      * Fonction permettant d'ajouter d'un votant à la liste
      * @param _address address
      */
    function addVoter(address _address) external onlyOwner isStatus(WorkflowStatus.RegisteringVoters) {
        whiteList[_address] = Voter(true, false, 0);
        emit VoterRegistered(_address);
    }

    /**
      * Fonction permettant d'ajouter une proposition à la liste
      * @param _description string
      */
    function addProposal(string calldata _description) external isStatus(WorkflowStatus.ProposalsRegistrationStarted) {
        // on check si le user est enregistré à la liste d'électeur
        require(whiteList[msg.sender].isRegistered, "Your are not registered in list");
        uint idProposal = proposals.length + 1;
        proposals.push(Proposal(_description, 0, idProposal));
        emit ProposalRegistered(idProposal);
    }

    /**
      * Fonction permettant de voter pour une proposition et ajouter un vote à la proposition 
      * @param _id uint
      */
    function vote(uint _id) external isStatus(WorkflowStatus.VotingSessionStarted) {
        require(whiteList[msg.sender].isRegistered, "Your are not registered in list");
        require(!whiteList[msg.sender].hasVoted, "You have already voted");
        require(_id != 0 && _id <= proposals.length, "This proposal doesn't exist");
        whiteList[msg.sender].hasVoted = true;
        whiteList[msg.sender].votedProposalId = _id;
        proposals[_id - 1].voteCount += 1;
        emit Voted(msg.sender, _id);
    }

    /**
      * Fonction permettant de regarder la liste des propositions 
      */
    function getProposals() external view returns(Proposal[] memory) {
        require(whiteList[msg.sender].isRegistered, "Your are not registered in list");
        return proposals;
    }

    /**
      * Fonction permettant de regarder le vote d'une personne 
      * @param _address address
      */
    function getVoteTo(address _address) external view returns(Voter memory) {
        require(whiteList[msg.sender].isRegistered, "Your are not registered in list");
        return whiteList[_address];
    }

    /**
      * Reset de la session 
      */
    function resetSession() external onlyOwner {
        status = WorkflowStatus.RegisteringVoters;
        delete proposals;
        // todo essayer de vider le mapping
    }

    /**
      * Get le winner 
      */
    function getWinner() external view isStatus(WorkflowStatus.VotesTallied) returns (Proposal memory) {
        Proposal memory winner;
        for (uint i = 0 ; i < proposals.length ; i++) {
            if (winner.voteCount < proposals[i].voteCount) {
                winner = proposals[i];
            }
        }
        return winner;
    }

}