class BTScreenMutator extends Mutator;

var bool bInitialized;

var float ServerTime;
var float TimeDilation;

struct PlayerData
{
    var PlayerPawn      Player;
    var int             PlayerID;

    var float           SpawnTime;
};

var PlayerData PlayerDataArray[32];

replication 
{
    reliable if ( Role == ROLE_Authority )
        ServerTime, TimeDilation, PlayerDataArray;
}

simulated function PreBeginPlay() 
{ 
    local BTScreenPlayerTimer temp;

    if( bInitialized ) 
    {
        return;
    }

    bInitialized = True;

    foreach AllActors(class'BTScreenPlayerTimer', temp) {
        if( temp.Controller == None ) {
            temp.Controller = Self;
        }
    }

    if( Role == ROLE_Authority ) 
    {
        Level.Game.BaseMutator.AddMutator(Self);
    }
}

function Tick(float DeltaTime)
{
    ServerTime = Level.TimeSeconds;
    TimeDilation = Level.TimeDilation;
}

function UpdateOrCreatePlayerData(PlayerPawn Player)
{
    local int i;
    local bool bFound;
    local PlayerData NewData;
    local PlayerData ExistingData;

    NewData.Player = Player;
    NewData.PlayerID = Player.PlayerReplicationInfo.PlayerID;
    NewData.SpawnTime = Level.TimeSeconds;

    bFound = false;

    for( i=0; i<ArrayCount(PlayerDataArray); i++ )
    {
        ExistingData = PlayerDataArray[i];

        if( ExistingData.PlayerID == NewData.PlayerID )
        {
            bFound = true;
            PlayerDataArray[i] = NewData;
            break;
        }
    }

    if( !bFound ) 
    {
        i = GetAvailableEmptyIndex();
        if( i >= 0 ) PlayerDataArray[i] = NewData;
    }
}

function int GetAvailableEmptyIndex()
{
    local int i;

    for( i=0; i<ArrayCount(PlayerDataArray); i++ )
    {
        if( PlayerDataArray[i].Player == None )
        {
            return i;
        }
        else if( PlayerDataArray[i].Player.Player == None )
        {
            return i;
        }
    }

    return -1;
}

simulated function float GetPlayerSpawnTime(PlayerPawn Other)
{
    local int i;
    local PlayerData PData;

    for( i=0; i<ArrayCount(PlayerDataArray); i++ )
    {
        PData = PlayerDataArray[i];
        if( PData.PlayerID == Other.PlayerReplicationInfo.PlayerID ) return PData.SpawnTime;
    }

    return 0;
}

simulated function float GetPlayerAliveTime(PlayerPawn Other)
{
    local int i;
    local float SpawnTime;

    SpawnTime = GetPlayerSpawnTime(Other);

    if( Other.Health <= 0 ) return 0; //dead
    if( Other.IsInState('GameEnded') ) return 0; //game ended
    if( Other.PlayerReplicationInfo.bWaitingPlayer ) return 0; //waiting for game

    return (ServerTime - SpawnTime) / TimeDilation;
}

simulated function String GetFormattedPlayerAliveTime(float time)
{
    local float AliveTime;
    local int Minutes, Seconds, Milliseconds;
    local String Result;

    AliveTime = time;
    if( AliveTime == 0 ) return "00:00.0";

    Minutes = int(AliveTime / 60);
    Seconds = int(AliveTime - (Minutes * 60));
    Milliseconds = int((AliveTime - (Minutes * 60) - Seconds) * 10);

    if( Minutes < 10 )
    {
        Result = Result $ "0";
    }
    
    Result = Result $ Minutes;
    Result = Result $ ":";

    if( Seconds < 10 )
    {
        Result = Result $ "0";
    }
    
    Result = Result $ Seconds;
    Result = Result $ ".";

    Result = Result $ Milliseconds;
    return Result;
}

function ModifyPlayer(Pawn Other)
{
    local PlayerPawn Player;

    if( Other.bIsPlayer && !Other.PlayerReplicationInfo.bWaitingPlayer )
    {
        Player = PlayerPawn(Other);
        if( Player != None )
        {
            UpdateOrCreatePlayerData(Player);
        }
    }

    if( NextMutator != None )
    {
        NextMutator.ModifyPlayer(Other);
    }
}

function AddMutator(Mutator M) 
{
    if( M.Class != Class )
    {
        Super.AddMutator(M);
    }
    else if( M != Self )
    {
        M.Destroy();
    }
}

function Destroyed() 
{
    local Mutator M;

    if( Level.Game != None ) 
    {
        if( Level.Game.BaseMutator == Self )
        {
            Level.Game.BaseMutator = NextMutator;
        }

        if( Level.Game.DamageMutator == Self )
        {
            Level.Game.DamageMutator = NextDamageMutator;
        }

        if( Level.Game.MessageMutator == Self )
        {
            Level.Game.MessageMutator = NextMessageMutator;
        }
    }

    ForEach AllActors(Class'Engine.Mutator', M) 
    {
        if( M.NextMutator == Self )
        {
            M.NextMutator = NextMutator;
        }

        if( M.NextDamageMutator == Self )
        {
            M.NextDamageMutator = NextDamageMutator;
        }

        if( M.NextMessageMutator == Self ) 
        {
            M.NextMessageMutator = NextMessageMutator;
        }
    }
}

defaultproperties {
    bNoDelete=True
    bAlwaysRelevant=True
    RemoteRole=ROLE_SimulatedProxy
}