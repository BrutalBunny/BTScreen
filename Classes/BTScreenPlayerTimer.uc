class BTScreenPlayerTimer extends ScreenSlide;

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

var PlayerPawn PlayerLocal;
var BTScreenMutator Controller;

var float cStamp;
var float oldUpdate;

// ============================================================================
// Prepare
//
// Does whatever preparation is needed for displaying this slide. Called
// immediately before Draw. After calling this function, all properties of
// this slide are expected to represent whatever values will be used in the
// next Draw operation, particularly in regard to ClientWidth and ClientHeight.
// ============================================================================

simulated function Prepare(ScriptedTexture TextureCanvas) 
{
  	if(	PlayerLocal == None ) 
  	{
	    foreach AllActors(class 'PlayerPawn', PlayerLocal) 
	    {
	      	if( PlayerLocal != None && Viewport(PlayerLocal.Player) != None )
	      	{
	        	break;
	      	}
	    }
  	}
}

// ============================================================================
// Draw
// ============================================================================

simulated function Draw(ScriptedTexture TextureCanvas, int Left, int Top, float Fade) {	
  	local string TextCaption, TextInfo;
  	local Color ColorCaption;

	local float AliveTime;
	local float Time;
	local String TimeString;

  	local float HeightTextCaption;
  	local float HeightTextInfo;
  	local float WidthText;

  	local PlayerPawn PlayerP;

  	if( Controller == None ) return; //No controller found
  	if( PlayerLocal == None ) return; //No local player found
  	if( PlayerLocal.PlayerReplicationInfo == None ) return;
  	if( PlayerLocal.PlayerReplicationInfo.bIsSpectator ) return; //Don't allow spectators

  	if( PlayerLocal.ViewTarget != None && PlayerLocal.ViewTarget.IsA('PlayerPawn') ) 
  	{
  		PlayerP = PlayerPawn(PlayerLocal.ViewTarget);
  	}
  	else
  	{
  		PlayerP = PlayerLocal;
  	}

	AliveTime = Controller.GetPlayerAliveTime(PlayerP);

	if( oldUpdate != AliveTime ){
		oldUpdate = AliveTime;
		cStamp = Level.TimeSeconds;
	}

	Time = oldUpdate;

	if( Time != 0 ) 
	{
		Time = (oldUpdate + ((Level.TimeSeconds - cStamp) / Level.TimeDilation));
	}

	TimeString = Controller.GetFormattedPlayerAliveTime(Time);

	//CAPTION SETTINGS
	ColorCaption = CaptionColor;
	if( CaptionColorTeam )
	{
		switch (PlayerP.PlayerReplicationInfo.Team) 
		{
			case 0: ColorCaption.R = 255; ColorCaption.G =   0; ColorCaption.B =   0; break;
			case 1: ColorCaption.R =   0; ColorCaption.G =   0; ColorCaption.B = 255; break;
			case 2: ColorCaption.R =   0; ColorCaption.G = 255; ColorCaption.B =   0; break;
			case 3: ColorCaption.R = 255; ColorCaption.G = 255; ColorCaption.B =   0; break;
	    }
	}

	TextCaption = Caption;
	TextCaption = Replace(TextCaption, "%p", PlayerP.PlayerReplicationInfo.PlayerName);

	if( CaptionCaps )
	{
		TextCaption = Caps(TextCaption);
	}

	//INFO SETTGINS
	TextInfo = Info;
	TextInfo = Replace(TextInfo, "%t", TimeString);

	if( InfoCaps )
	{
		TextInfo = Caps(TextInfo);
	}

	//DRAW
	//Get font sizes for the given font
	TextureCanvas.TextSize("X", WidthText, HeightTextCaption, CaptionFont);
	TextureCanvas.TextSize("X", WidthText, HeightTextInfo, InfoFont);

	TextureCanvas.DrawColoredText(Left + CaptionX, Top + CaptionY + HeightTextCaption, TextCaption, CaptionFont, FadeColor(ColorCaption, Fade));
	TextureCanvas.DrawColoredText(Left + InfoX, Top + InfoY + HeightTextInfo, TextInfo, InfoFont, FadeColor(InfoColor, Fade));
}