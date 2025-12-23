// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @notice Simple contract for hackathon submissions and awarding a reward
contract HackathonSubmission {
	// Owner (organizer)
	address public owner;

	// Submission structure
	struct Submission {
		address participant;
		string repoLink;
		string description;
		uint256 timestamp;
		bool winner;
	}

	Submission[] private submissions;

	// participant => list of submission ids
	mapping(address => uint256[]) private participantSubmissions;

	// Events
	event Submitted(uint256 indexed id, address indexed participant, string repoLink);
	event WinnerSelected(uint256 indexed id, address indexed participant, uint256 reward);
	event Funded(address indexed from, uint256 amount);
	event Withdrawn(address indexed to, uint256 amount);

	modifier onlyOwner() {
		require(msg.sender == owner, "Only owner");
		_;
	}

	constructor() {
		owner = msg.sender;
	}

	/// @notice Participants submit their project repo and optional description
	/// @param repoLink GitHub repo or URL
	/// @param description short description
	function submit(string calldata repoLink, string calldata description) external {
		require(bytes(repoLink).length > 0, "repoLink required");

		submissions.push(Submission({
			participant: msg.sender,
			repoLink: repoLink,
			description: description,
			timestamp: block.timestamp,
			winner: false
		}));

		uint256 id = submissions.length - 1;
		participantSubmissions[msg.sender].push(id);

		emit Submitted(id, msg.sender, repoLink);
	}

	/// @notice Owner funds the reward pool
	function fundPool() external payable {
		require(msg.value > 0, "Send ETH to fund");
		emit Funded(msg.sender, msg.value);
	}

	/// @notice Owner selects a winner and transfers `reward` (in wei) to the participant
	/// @param id submission id
	/// @param reward amount in wei to send to winner
	function selectWinner(uint256 id, uint256 reward) external onlyOwner {
		require(id < submissions.length, "Invalid id");
		Submission storage s = submissions[id];
		require(!s.winner, "Already winner");

		// mark winner first
		s.winner = true;

		// ensure contract has enough balance
		require(address(this).balance >= reward, "Insufficient reward pool");

		(address payable to,) = payable(s.participant).call{value: reward}("");
		require(to != address(0), "Invalid recipient");

		emit WinnerSelected(id, s.participant, reward);
	}

	/// @notice Get total submissions
	function totalSubmissions() external view returns (uint256) {
		return submissions.length;
	}

	/// @notice Get submission details by id
	/// @param id submission id
	function getSubmission(uint256 id) external view returns (
		address participant,
		string memory repoLink,
		string memory description,
		uint256 timestamp,
		bool winner
	) {
		require(id < submissions.length, "Invalid id");
		Submission storage s = submissions[id];
		return (s.participant, s.repoLink, s.description, s.timestamp, s.winner);
	}

	/// @notice Get submission ids for a participant
	function getParticipantSubmissions(address participant) external view returns (uint256[] memory) {
		return participantSubmissions[participant];
	}

	/// @notice Owner can withdraw remaining funds
	function withdraw(uint256 amount) external onlyOwner {
		require(amount <= address(this).balance, "Amount exceeds balance");
		payable(owner).transfer(amount);
		emit Withdrawn(owner, amount);
	}

	/// @notice Fallback/receive to accept ETH
	receive() external payable {
		emit Funded(msg.sender, msg.value);
	}
}
