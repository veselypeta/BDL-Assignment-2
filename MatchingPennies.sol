pragma solidity ^0.5.17;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.3.0/contracts/math/SafeMath.sol";


contract MatchingPennies {
    
    using SafeMath for uint256;
    
    // Each user of the contract will their winning stored
    // until they wish to withdraw
    mapping(address => uint256) balance;
    
    // Events for logging
    event Commit(address player, bytes32 hash);
    event Reveal(address player, Choice choice);
    event Win(address player, uint256 win_amount);
    
    
    enum Choice {
        HEADS,
        TAILS,
        NONE
    }
    
    enum Stage {
        FirstCommit,
        SecondCommit,
        FirstReveal,
        SecondReveal,
        Distribute
    }
    
    struct CommitChoice {
        address playerAddress;
        bytes32 commitment;
        Choice choice;
    }
    
    // store each commit choice of each player (only two players)
    CommitChoice[2] public players;
    uint256 public revealDeadline;
    Stage public stage = Stage.FirstCommit;
    
    
    uint256 public bet;
    uint256 public deposit;
    uint256 public revealSpan;
    
    // constructor for this contarct
    // set the bet/deposit & reveal span for this contract on creation
    constructor(uint256 _bet, uint256 _deposit, uint256 _revealSpan) public {
        bet = _bet;
        deposit = _deposit;
        revealSpan = _revealSpan;
    }
    
    
    // We run this function to allow a player to make a commit
    function commit(bytes32 commitment) public payable {
        
        // allow this function to continue iff in First/Second Commit
        uint playerIndex;
        if(stage == Stage.FirstCommit) playerIndex = 0;
        else if(stage == Stage.SecondCommit) playerIndex = 1;
        else revert("both players have already played");
        
        // Same sender is not allow to make another commitment
        if(stage==Stage.SecondCommit && (players[0].playerAddress == msg.sender)){
            revert("Commits received from same account!");
        }
    
        uint commitAmount = bet.add(deposit); // safemath
        require(msg.value >= commitAmount, "value must be greater than commit amount");
    
        // Any additional funds we add to balance to allow user to retrieve
        if(msg.value > commitAmount){
            balance[msg.sender] += msg.value.sub(commitAmount);
        }
        
    
        // Store the commitment
        players[playerIndex] = CommitChoice(msg.sender, commitment, Choice.NONE);
        
        // log as event
        emit Commit(msg.sender, commitment);
    
    
        // If we're on the first commit, then move to the second
        if(stage == Stage.FirstCommit) stage = Stage.SecondCommit;
        // Otherwise we must already be on the second, move to first reveal
        else stage = Stage.FirstReveal;
    }
    
    
    function reveal(Choice choice, bytes32 nonce) public {
        // only allow to be executed during reveal stages
        require(stage == Stage.FirstReveal || stage == Stage.SecondReveal, "not currently in a reveal stage");
        // only valid choices are accepted
        require(choice == Choice.HEADS || choice == Choice.TAILS, "invalid choice type");
        
        
        // get the index of the player that is revealing
        uint playerIndex;
        if(players[0].playerAddress == msg.sender) playerIndex = 0;
        else if(players[1].playerAddress == msg.sender) playerIndex = 1;
        else revert("Invalid player");
        
        
        // get the data of the players
        CommitChoice storage commitedChoice = players[playerIndex];
        
        // Check the hash to ensure the commitment is correct
        require(keccak256(abi.encodePacked(msg.sender, choice, nonce)) == commitedChoice.commitment, "invalid hash");
        
        // save the revealed value when correct
        commitedChoice.choice = choice;
        
        // log as event
        emit Reveal(msg.sender, choice);
        
        if(stage == Stage.FirstReveal) {
            // If this is the first reveal, set the deadline for the second one
            revealDeadline = block.number.add(revealSpan);
            // Move to second reveal
            stage = Stage.SecondReveal;
        }
        // If we're on second reveal, move to distribute stage
        else stage = Stage.Distribute;
    }
    
    
    function distribute() public {
        // To distribute we need to either be in distrubute Stage
        // or be in SecondReveal and past deadline
        require(stage == Stage.Distribute || (stage == Stage.SecondReveal && block.number > revealDeadline), "not ready to distribute");
        
        // at least one party must have made a choice
        require(players[0].choice != Choice.NONE || players[1].choice != Choice.NONE, "players have not made a choice" );
        
        // log the used gas
        uint256 init_gas = gasleft();
        
        // calculate the winnings - return deposit and duplicate the bet
        uint win_amt = deposit.add(bet.mul(2));
        
        // determine the winner of the game
        // if the choices are the save (Even (player1)) wins, otherwise Odd wins
        uint winnerIdx;
        uint loserIdx;
        // if either player failed to play then the other wins by default
        if(players[0].choice == Choice.NONE){
            winnerIdx = 1; // player 1 wins by default
            loserIdx = 0; 
        }
        else if(players[1].choice == Choice.NONE){
            winnerIdx = 0; // player 0 wins by default
            loserIdx = 1;
        }
        else if(players[0].choice == players[1].choice){
            winnerIdx = 0; // player 0 wins if choices match
            loserIdx = 1;
        }
        else{
            winnerIdx = 1; // otherwise player 1 wins
            loserIdx = 0;
        }
        
        
        // update the balance to reflect that the winner has received funds
        address winnerAdr = players[winnerIdx].playerAddress;
        balance[winnerAdr] = balance[winnerAdr].add(win_amt);
        
        // add the deposit to balance of loser
        address loserAdr = players[loserIdx].playerAddress;
        balance[loserAdr] = balance[loserAdr].add(deposit);
        
        

        // reset the state ready for a new game
        delete players;
        revealDeadline = 0;
        stage = Stage.FirstCommit;
        
        // split the gas used
        uint256 gas_used = init_gas.sub(gasleft());
        uint256 gas_share = gas_used.div(2);
        // loser has to contribute to cas gosts
        balance[loserAdr] = balance[loserAdr].sub(gas_share);

        
    }
    
    // get the current stage of the contract
    function get_cur_stage() public view returns (Stage){
        return stage;
    }
    
    
    // players can withdraw their money at any time
    function withdraw() public {
        uint256 cur_ballance = balance[msg.sender];
        require(cur_ballance > 0, "No balance in account");
        balance[msg.sender] = 0;
        (bool success, ) = msg.sender.call.value(cur_ballance)("");
        require(success, "transfer failed");
    }
    
    // players can also view their winnings
    function get_balance() public view returns (uint256) {
        return balance[msg.sender];
    }
    
    
}