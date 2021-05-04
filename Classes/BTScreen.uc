class BTScreen extends Mutator;

var bool bInitialized;
var int CurrentID;

struct PlayerInfoScreen
{
	var PlayerPawn 	Player;
	var	int 		PlayerID;
	var BTScreenPRI RI;
};
var PlayerInfoScreen PIS[32];

struct SpecInfo
{
	var	PlayerPawn 	Spec;
	var	int 		PlayerID;
	var BTScreenPRI RI;
};
var SpecInfo SI[32];


//====================================
// PreBeginPlay
//====================================
function PreBeginPlay() {	
	if( bInitialized )
		return;

	bInitialized = True;
		
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

		if( PIS[i].RI.lastDeaths != PIS[i].Player.PlayerReplicationInfo.Deaths ){
			PIS[i].RI.lastDeaths = PIS[i].Player.PlayerReplicationInfo.Deaths;
			PIS[i].RI.bNeedsRespawn = True;
		}

		if( PIS[i].RI.lastScore != PIS[i].Player.PlayerReplicationInfo.Score ){
			PIS[i].RI.lastScore = PIS[i].Player.PlayerReplicationInfo.Score;
			PIS[i].RI.bNeedsRespawn = True;
		}
			
		if( PIS[i].RI.bNeedsRespawn )//1 update if idle
			PIS[i].RI.runTime = 0;
		else
			PIS[i].RI.runTime = MeasureTime(i, Level.TimeSeconds);
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
		for( Other=Level.PawnList; Other!=None; Other=Other.NextPawn )
			if( Other.PlayerReplicationInfo.PlayerID == CurrentID )
				break;

		CurrentID++;

		// Make sure it is a player.
		pp = PlayerPawn(Other);

		if( pp == none || !Other.bIsPlayer )
			return;

		if( Other.PlayerReplicationInfo.bIsSpectator && !Other.PlayerReplicationInfo.bWaitingPlayer )
			InitNewSpec(pp);
		else
			InitNewPlayer(pp);
	}
}

//====================================
// InitNewPlayer
//====================================
function InitNewPlayer(PlayerPawn P) {
	local int i;
	i = FindFreePISlot();
		
	if( PIS[i].RI != none ) {
		PIS[i].RI.Destroy();
		PIS[i].RI = None;
	}

	PIS[i].Player = P;
	PIS[i].PlayerID = P.PlayerReplicationInfo.PlayerID;

	PIS[i].RI = spawn(class'BTScreenPRI', P);
	PIS[i].RI.PlayerID = P.PlayerReplicationInfo.PlayerID;
	
	if( PIS[i].RI.lastDeaths != 0 || PIS[i].RI.lastScore != 0 ) {
		PIS[i].RI.bStartedFirstRun = True;
		PIS[i].RI.bNeedsRespawn = True;

		P.AttitudeToPlayer = ATTITUDE_Follow;
	}

	PIS[i].RI.lastDeaths = P.PlayerReplicationInfo.Deaths;
	PIS[i].RI.lastScore  = P.PlayerReplicationInfo.Score;

}

//====================================
// InitNewSpec
//====================================
function InitNewSpec(PlayerPawn P) {
	local int i;

	i = FindFreeSISlot();
	SI[i].Spec = P;
	SI[i].PlayerID = P.PlayerReplicationInfo.PlayerID;

	SI[i].RI = spawn(class'BTScreenPRI', P);
	SI[i].RI.PlayerID = P.PlayerReplicationInfo.PlayerID;
}

//====================================
// FindFreePISlot
//====================================
function int FindFreePISlot() {
	local int i;

	for(i=0;i<32;i++) {
		if( PIS[i].Player == none ) return i;
		else if( PIS[i].Player.Player == none ) return i;
	}
}

//====================================
// FindFreeSISlot
//====================================
function int FindFreeSISlot() {
	local int i;
	for(i=0;i<32;i++)
		if( SI[i].Spec == none ) return i;
		else if( SI[i].Spec.Player == none ) return i;
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
// FindPlayer
//====================================
function int FindPlayerByID(coerce int ID) {
	local int i;

	for(i=0;i<32;i++)
		if( PIS[i].PlayerID == ID )
			return i;
}

//====================================
// MeasureTime
//====================================
function int MeasureTime(int ID, float TimeSeconds) {
	return 90.909090909*(TimeSeconds - PIS[ID].RI.StartTime);
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
		if ( NextMutator != None )
			NextMutator.ModifyPlayer(Other);
		
		return;
	}
			
	
	//allow grab/cap again
	if( PIS[ID].RI.bNeedsRespawn ) {
		PIS[ID].RI.bNeedsRespawn = False;
		PIS[ID].RI.StartTime = Level.TimeSeconds;
	}
	else if( PIS[ID].RI.lastDeaths == 0 && PIS[ID].RI.lastScore == 0 ) {
		if( !PIS[ID].RI.bStartedFirstRun ) {
			PIS[ID].RI.bStartedFirstRun = True;
			PIS[ID].RI.StartTime = Level.TimeSeconds;
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