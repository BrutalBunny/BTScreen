class BTScreenTimer extends ScreenSlide;

// ============================================================================
// Compiler Directives
// ============================================================================

#exec obj load file=Textures\ScreenFonts.utx package=ScreenFonts

// ============================================================================
// Properties
// ============================================================================

var() string Caption;
var() bool CaptionCaps;
var() Font CaptionFont;
var() Color CaptionColor;
var() bool CaptionColorTeam;

var() int CaptionY;
var() int CaptionX;

var() string Info;
var() bool InfoCaps;
var() Font InfoFont;
var() Color InfoColor;


var() int InfoY;
var() int InfoX;

var bool bInitialized;

var PlayerPawn PlayerLocal;
var BTScreenPRI BT_PRI_Local;

var float cStamp;
var int oldUpdate;

var int LastTime;

function PreBeginPlay() {
	if( bInitialized )
		return;

	bInitialized = True;

	Spawn(class'BTScreen');
}

// ============================================================================
// Prepare
//
// Does whatever preparation is needed for displaying this slide. Called
// immediately before Draw. After calling this function, all properties of
// this slide are expected to represent whatever values will be used in the
// next Draw operation, particularly in regard to ClientWidth and ClientHeight.
// ============================================================================

simulated function Prepare(ScriptedTexture TextureCanvas) {
  	if(	PlayerLocal == None )
	    foreach AllActors(class 'PlayerPawn', PlayerLocal)
	      	if( Viewport(PlayerLocal.Player) != None )
	        	break;


	BT_PRI_Local = GetBTPRI(PlayerLocal);
}


// ============================================================================
// Draw
// ============================================================================

simulated function Draw(ScriptedTexture TextureCanvas, int Left, int Top, float Fade) {	
  	local string TextCaption, TextInfo;
  	local Color ColorCaption;

	local int Time;
	local String T;

  	local float HeightTextCaption;
  	local float HeightTextInfo;
  	local float WidthText;

  	local PlayerPawn PlayerP;
  	local BTScreenPRI BT_PRI;

  	if( PlayerLocal.PlayerReplicationInfo.bIsSpectator ) return;

  	if( PlayerLocal.ViewTarget != None && PlayerLocal.ViewTarget.IsA('PlayerPawn') ){
  		PlayerP = PlayerPawn(PlayerLocal.ViewTarget);
  		BT_PRI = GetBTPRI(PlayerP);
  	}else{
  		PlayerP = PlayerLocal;
  		BT_PRI = BT_PRI_Local;
  	}

  	if( PlayerP != None && BT_PRI != None ){
		//see if server sent a new runtime
		if( oldUpdate != BT_PRI.runTime ){
			oldUpdate = BT_PRI.runTime;
			cStamp = Level.TimeSeconds;
		}

		if( PlayerP.PlayerReplicationInfo.bWaitingPlayer ){
			oldUpdate = 0; //game has not started yet
			Time = 0;
			LastTime = Time;
		}else if( !PlayerP.IsInState('GameEnded') && !BT_PRI.bNeedsRespawn ) { //update HUD-Timer if the Game is not ended and the player is on a run
			//round down
			//Time = BT_PRI.runTime/10;
			//this is about the current time: runs on until server saw a cap; this may cause the timer to jump back a bit

			Time = (oldUpdate + int((Level.TimeSeconds - cStamp) * 90.9090909))/10;//move on from last update until server sends a new one
			LastTime = Time;
		}else{
			oldUpdate = 0; //dead or game over
			Time = 0;
			LastTime = Time;
		}

		//Current run time
		T = GetFormattedTime(Time / 600, Time % 600);

	  	//Get color of current player team
	    ColorCaption = CaptionColor;
	    if( CaptionColorTeam ){
	      	switch (PlayerP.PlayerReplicationInfo.Team) {
		        case 0: ColorCaption.R = 255; ColorCaption.G =   0; ColorCaption.B =   0; break;
	        	case 1: ColorCaption.R =   0; ColorCaption.G =   0; ColorCaption.B = 255; break;
	        	case 2: ColorCaption.R =   0; ColorCaption.G = 255; ColorCaption.B =   0; break;
	        	case 3: ColorCaption.R = 255; ColorCaption.G = 255; ColorCaption.B =   0; break;
	        }
	    }

	    //Get font sizes for the given font
	  	TextureCanvas.TextSize("X", WidthText, HeightTextCaption, CaptionFont);
	  	TextureCanvas.TextSize("X", WidthText, HeightTextInfo, InfoFont);


	    TextCaption = Caption;
	    TextCaption = Replace(TextCaption, "%p", PlayerP.PlayerReplicationInfo.PlayerName);

	   	if( CaptionCaps )
	      	TextCaption = Caps(TextCaption);

	    TextInfo = Info;
	    TextInfo = Replace(TextInfo, "%t", T);

	    if( InfoCaps )
	      	TextInfo = Caps(TextInfo);



	    TextureCanvas.DrawColoredText(Left + CaptionX, Top + CaptionY + HeightTextCaption, TextCaption, CaptionFont, FadeColor(ColorCaption, Fade));
	    TextureCanvas.DrawColoredText(Left + InfoX, Top + InfoY + HeightTextInfo, TextInfo, InfoFont, FadeColor(InfoColor, Fade));
  	}
}

//==========================================================
simulated function string GetFormattedTime(int Minutes, int Seconds)
{
	local int d;
	local String formatted;

	if( Minutes > 99 ) { 
		//too long run time: show -:-- in red

		formatted = "-:--";
	}
	else{ 
		//show actual timer

		if ( Minutes >= 10 ){
			formatted = formatted $ Minutes $ ":";
		}
		else{
			//leading 0
			formatted = formatted $ "0" $ Minutes $ ":";
		}

		//Seconds 1
		d = Seconds/100;
		formatted = formatted $ d;

		//Seconds 2
		Seconds -=  100*d;
		d = Seconds / 10;
		formatted = formatted $ d;

		// "."
		formatted = formatted $ ".";

		//Deciseconds
		Seconds -= 10*d;
		formatted = formatted $ Seconds;
	}

	return formatted;
}

//==========================================================
simulated function BTScreenPRI GetBTPRI(PlayerPawn P){
	local BTScreenPRI BTPRI;
	local PlayerReplicationInfo PRI;

	if( P != None ){
		PRI = P.PlayerReplicationInfo;
   		foreach AllActors(class'BTScreenPRI', BTPRI)
    		if( BTPRI.PlayerID == PRI.PlayerID ) 
    			break;

		return BTPRI;
	}

	return None;
}