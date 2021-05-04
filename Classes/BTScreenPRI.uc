class BTScreenPRI expands ReplicationInfo;

var int PlayerID; // used to identify the owner
var int runTime;//last update from the server: length of the current run

var int lastDeaths;
var int lastScore;

var bool bNeedsRespawn; //indicates if the player needs a respawn to take flag/also stops the timers on him
var bool bStartedFirstRun;

var float StartTime;

replication {
	reliable if (Role == ROLE_Authority)
	PlayerID,  StartTime, bNeedsRespawn, bStartedFirstRun, runTime;
}

event Spawned() {
	if(ROLE == ROLE_Authority) {
		SetTimer(0.5, true);
	}
}

function Timer() {
	if( Owner == None )
		Destroy();
}