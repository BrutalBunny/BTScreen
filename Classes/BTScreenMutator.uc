class BTScreenMutator extends Mutator;

var bool bInitialized;
var int CurrentID;

struct PlayerInfoScreen
{
	var PlayerPawn 	Player;
	var	int 		PlayerID;

	var int lastDeaths;
	var int lastScore;

	var bool bNeedsRespawn; //indicates if the player needs a respawn to take flag/also stops the timers on him
	var bool bStartedFirstRun;

	var float StartTime;
	var int runTime; //last update from the server: length of the current run
};
var PlayerInfoScreen PIS[32];

replication {
	reliable if ( Role == ROLE_Authority )
		PIS, GetRunTimeByPlayerID;
}

//====================================
// PreBeginPlay
//====================================
simulated function PreBeginPlay() {	
	local BTScreenTimer temp;

	if( bInitialized )
		return;

	bInitialized = True;

	foreach AllActors(class'BTScreenTimer', temp)
   		if( temp.Controller == None )
   			temp.Controller = Self;


   	if( Role == ROLE_Authority )
   		Level.Game.BaseMutator.AddMutator(Self);
}

//====================================
// Tick
//====================================
function tick(float DeltaTime) {
	local int i;
	Super.tick(DeltaTime);

	//update run-times
	for(i = 0;i < 32;i++) {
		if( PIS[i].Player == None )
			continue;

		if( PIS[i].lastDeaths != PIS[i].Player.PlayerReplicationInfo.Deaths ){
			PIS[i].lastDeaths = PIS[i].Player.PlayerReplicationInfo.Deaths;
			PIS[i].bNeedsRespawn = True;
		}

		if( PIS[i].lastScore != PIS[i].Player.PlayerReplicationInfo.Score ){
			PIS[i].lastScore = PIS[i].Player.PlayerReplicationInfo.Score;
			PIS[i].bNeedsRespawn = True;
		}
			
		if( PIS[i].bNeedsRespawn )
			PIS[i].runTime = 0;
		else
			PIS[i].runTime = MeasureTime(i, Level.TimeSeconds);
	}
	
	CheckForNewPlayer();
}

//====================================
// CheckForNewPlayer
//====================================
function CheckForNewPlayer() {
	local Pawn Other;
	local PlayerPawn pp;

	if( Level.Game.CurrentID > CurrentID ) { // At least one new player has joined - sometimes this happens faster than tick
		for(Other=Level.PawnList; Other!=None; Other=Other.NextPawn)
			if( Other.PlayerReplicationInfo.PlayerID == CurrentID )
				break;

		CurrentID++;

		// Make sure it is a player.
		pp = PlayerPawn(Other);

		if( pp == none || !Other.bIsPlayer )
			return;

		if( Other.PlayerReplicationInfo.bIsSpectator && !Other.PlayerReplicationInfo.bWaitingPlayer )
			return;
	
		InitNewPlayer(pp);
	}
}

//====================================
// InitNewPlayer
//====================================
function InitNewPlayer(PlayerPawn P) {
	local int i;
	i = FindFreePISlot();


	PIS[i].Player = P;
	PIS[i].PlayerID = P.PlayerReplicationInfo.PlayerID;
	
	if( PIS[i].lastDeaths != 0 || PIS[i].lastScore != 0 ) {
		PIS[i].bStartedFirstRun = True;
		PIS[i].bNeedsRespawn = True;

		P.AttitudeToPlayer = ATTITUDE_Follow;
	}

	PIS[i].lastDeaths = P.PlayerReplicationInfo.Deaths;
	PIS[i].lastScore  = P.PlayerReplicationInfo.Score;
}

//====================================
// FindFreePISlot
//====================================
function int FindFreePISlot() {
	local int i;

	for(i=0;i<32;i++)
		if( PIS[i].Player == none ) 
			return i;
		else if( PIS[i].Player.Player == none ) 
			return i;

}

//====================================
// FindPlayer
//====================================
function int FindPlayer(Pawn P) {
	local int i, ID;
	ID = P.PlayerReplicationInfo.PlayerID;

	for(i=0;i<32;i++)
		if( PIS[i].PlayerID == ID )
			return i;
	
	return -1;
}

//====================================
// GetRunTimeByPlayerID
//====================================
simulated function int GetRunTimeByPlayerID(coerce int ID) {
	local int i, runTime;
	local bool found;

	for(i=0;i<32;i++){
		if( PIS[i].PlayerID == ID ){
			found = true;
			break;
		}
	}

	if( !found ) return 0;

	if( PIS[i].Player.PlayerReplicationInfo.bWaitingPlayer )
		runTime = 0;
	else if( !PIS[i].Player.IsInState('GameEnded') && !PIS[i].bNeedsRespawn )
		runTime = PIS[i].runTime;
	else
		runTime = 0;

	return runTime;
}

//====================================
// MeasureTime
//====================================
function int MeasureTime(int ID, float TimeSeconds) {
	return 90.909090909*(TimeSeconds - PIS[ID].StartTime);
}

//====================================
// AddMutator
//====================================
function AddMutator(Mutator M) {
	if( M.Class != Class )
		Super.AddMutator(M);
	else if( M != Self )
		M.Destroy();
}

//====================================
// ModifyPlayeR
//====================================
function ModifyPlayer(Pawn Other) {
	local int ID;
	
	CheckForNewPlayer(); // sometimes modifyplayer is being called faster than a tick where usual new player detection is done thus we have to search for new players also here
	
	ID = FindPlayer(Other);
	
	//No bots & ignore waiting players: on gamestart we get another call
	if( ID == -1 && !Other.IsA('TournamentPlayer') || Other.PlayerReplicationInfo.bWaitingPlayer ) {
		if( NextMutator != None )
			NextMutator.ModifyPlayer(Other);
		
		return;
	}
			
	
	//allow grab/cap again
	if( PIS[ID].bNeedsRespawn ) {
		PIS[ID].bNeedsRespawn = False;
		PIS[ID].StartTime = Level.TimeSeconds;
	}
	else if( PIS[ID].lastDeaths == 0 && PIS[ID].lastScore == 0 ) {
		if( !PIS[ID].bStartedFirstRun ) {
			 PIS[ID].bStartedFirstRun = True;
			 PIS[ID].StartTime = Level.TimeSeconds;
		}
	}	

	if( NextMutator != None )
		NextMutator.ModifyPlayer(Other);
}

//====================================
// Destroyed
//====================================
function Destroyed() {
	local Mutator M;

	if( Level.Game != None ) {
        if( Level.Game.BaseMutator == Self )
            Level.Game.BaseMutator = NextMutator;
        if( Level.Game.DamageMutator == Self )
            Level.Game.DamageMutator = NextDamageMutator;
        if( Level.Game.MessageMutator == Self )
            Level.Game.MessageMutator = NextMessageMutator;
    }

    ForEach AllActors(Class'Engine.Mutator', M) {
        if( M.NextMutator == Self )
            M.NextMutator = NextMutator;
        if( M.NextDamageMutator == Self )
            M.NextDamageMutator = NextDamageMutator;
        if( M.NextMessageMutator == Self )
            M.NextMessageMutator = NextMessageMutator;
    }
}


defaultproperties  {
      bNoDelete=True
      bAlwaysRelevant=True
      RemoteRole=ROLE_SimulatedProxy
}