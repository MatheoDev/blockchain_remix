// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract VotingPlus is Ownable {

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

    // ajout d'une structure de mapping pour conserver les clés et pouvoir les reset au besoin d'une nouvelle session de vote
    struct WhiteListMap {
        mapping(address => Voter) list;
        address[] keys;
    }

    // events
    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);

    WhiteListMap whiteList; // whitelist des votants
    Proposal[] proposals; // liste des proposition
    WorkflowStatus status; // current status
    uint winningProposalId; // winner id

    // check si l'address est enregistrer dans la liste
    modifier isAuthorize() {
        require(whiteList.list[msg.sender].isRegistered, "Your are not registered in list");
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
        require(status == WorkflowStatus.ProposalsRegistrationStarted, "It must be proposal session");
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
    function talliedVote() external onlyOwner {
        require(status == WorkflowStatus.VotingSessionEnded, "It must be the end of the session");

        // on détermine le gagnant 
        Proposal memory winner;
        for (uint i = 0 ; i < proposals.length ; i++) {
            if (winner.voteCount < proposals[i].voteCount) { // le nb de vote est supp on replace le gagnant 
                winner = proposals[i];
                winningProposalId = i;
            }
        }

        status = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, status);
    }

    /**
      * Fonction permettant d'ajouter d'un votant à la liste
      * @param _address address
      */
    function addVoter(address _address) external onlyOwner {
        require(status == WorkflowStatus.RegisteringVoters, "It must be registering voter");
        require(!whiteList.list[_address].isRegistered, "This address is already registered");
        whiteList.list[_address] = Voter(true, false, 0);
        whiteList.keys.push(_address);
        emit VoterRegistered(_address);
    }

    /**
      * Fonction permettant d'ajouter une proposition à la liste
      * @param _description string
      */
    function addProposal(string calldata _description) external isAuthorize {
        require(status == WorkflowStatus.ProposalsRegistrationStarted, "It must be proposal session");
        proposals.push(Proposal(_description, 0));
        emit ProposalRegistered(proposals.length);
    }

    /**
      * Fonction permettant de voter pour une proposition et ajouter un vote à la proposition 
      * @param _id uint
      */
    function vote(uint _id) external isAuthorize {
        require(status == WorkflowStatus.VotingSessionStarted, "It must be voting session");
        require(!whiteList.list[msg.sender].hasVoted, "You have already voted");
        require(proposals.length != 0 && _id <= proposals.length, "This proposal doesn't exist");
        whiteList.list[msg.sender].hasVoted = true;
        whiteList.list[msg.sender].votedProposalId = _id;
        proposals[_id].voteCount += 1;
        emit Voted(msg.sender, _id);
    }

    /**
      * Fonction permettant de regarder la liste des propositions 
      * @return Proposal[]
      */
    function getProposals() external view isAuthorize returns(Proposal[] memory) {
        require(proposals.length != 0, "There aren't proposal");
        return proposals;
    }

    /**
      * Fonction permettant de regarder le vote d'une personne 
      * @param _address address
      * @return Voter
      */
    function getVoteTo(address _address) external view isAuthorize returns(Voter memory) {
        require(whiteList.list[msg.sender].hasVoted, "This person hasn't voted");
        return whiteList.list[_address];
    }

    /**
      * Get le winner 
      * @return Proposal
      */
    function getWinner() external view returns (Proposal memory) {
        require(status == WorkflowStatus.VotesTallied, "It must be tallied session");
        return proposals[winningProposalId];
    }

    /**
      * Reset session
      */
    function resetSession() external onlyOwner {
        require(status == WorkflowStatus.VotesTallied, "It must be tallied session");
        status = WorkflowStatus.RegisteringVoters; // register des votant
        delete proposals; // delete les propositions
        delete winningProposalId; // delete le gagnant 
        for (uint i = 0; i < whiteList.keys.length; i++) {
            delete whiteList.list[whiteList.keys[i]]; // delete les infos à l'adresse concerné
        }
        delete whiteList.keys;
    }

}