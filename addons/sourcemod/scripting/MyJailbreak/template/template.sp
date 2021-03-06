//includes
#include <cstrike>
#include <sourcemod>
#include <smartjaildoors>
#include <warden>
#include <emitsoundany>
#include <colors>
#include <autoexecconfig>
#include <myjailbreak>

//Compiler Options
#pragma semicolon 1
#pragma newdecls required

//Booleans
bool IsEVENTNAME;
bool StartEVENTNAME;

//ConVars    gc_i = global convar integer / gc_i = global convar bool ...
ConVar gc_bPlugin;
ConVar gc_bSetW;
ConVar gc_iCooldownStart;
ConVar gc_bSetA;
ConVar gc_bSpawnCell;
ConVar gc_bVote;
ConVar gc_iCooldownDay;
ConVar gc_iRoundTime;
ConVar gc_iTruceTime;
ConVar gc_bOverlays;
ConVar gc_sOverlayStartPath;
ConVar gc_bSounds;
ConVar gc_iRounds;
ConVar gc_sSoundStartPath;
ConVar gc_sCustomCommand;
ConVar g_iGetRoundTime;

//Integers    g_i = global integer
int g_iOldRoundTime;
int g_iCoolDown;
int g_iTruceTime;
int g_iVoteCount;
int g_iRound;
int g_iMaxRound;

//Floats    g_i = global float
float g_fPos[3];

//Handles
Handle TruceTimer;
Handle EVENTNAMEMenu;

//Strings    g_s = global string
char g_sHasVoted[1500];
char g_sSoundStartPath[256];
char g_sCustomCommand[64];

public Plugin myinfo = {
	name = "MyJailbreak - EVENTNAME",
	author = "yourname",
	description = "Event Day for Jailbreak Server",
	version = "0.x",
	url = "http://www.sourcemod.net/"
};

public void OnPluginStart()
{
	// Translation
	LoadTranslations("MyJailbreak.Warden.phrases");
	LoadTranslations("MyJailbreak.EVENTNAME.phrases");
	
	//Client Commands
	RegConsoleCmd("sm_seteventname", SetEVENTNAME, "Allows the Admin or Warden to set eventname as next round");
	RegConsoleCmd("sm_eventname", VoteEVENTNAME, "Allows players to vote for a eventname");
	
	//AutoExecConfig
	AutoExecConfig_SetFile("EVENTNAME", "MyJailbreak/EventDays");
	AutoExecConfig_SetCreateFile(true);
	
	AutoExecConfig_CreateConVar("sm_eventname_version", PLUGIN_VERSION, "The version of this MyJailbreak SourceMod plugin", FCVAR_SPONLY|FCVAR_PLUGIN|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	gc_bPlugin = AutoExecConfig_CreateConVar("sm_eventname_enable", "1", "0 - disabled, 1 - enable this MyJailbreak SourceMod plugin", _, true,  0.0, true, 1.0);
	gc_sCustomCommand = AutoExecConfig_CreateConVar("sm_eventname_cmd", "yourname", "Set your custom chat command for Event voting. no need for sm_ or !");
	gc_bSetW = AutoExecConfig_CreateConVar("sm_eventname_warden", "1", "0 - disabled, 1 - allow warden to set eventname round", _, true,  0.0, true, 1.0);
	gc_bSetA = AutoExecConfig_CreateConVar("sm_eventname_admin", "1", "0 - disabled, 1 - allow admin to set eventname round", _, true,  0.0, true, 1.0);
	gc_bVote = AutoExecConfig_CreateConVar("sm_eventname_vote", "1", "0 - disabled, 1 - allow player to vote for eventname", _, true,  0.0, true, 1.0);
	gc_bSpawnCell = AutoExecConfig_CreateConVar("sm_eventname_spawn", "0", "0 - T teleport to CT spawn, 1 - cell doors auto open", _, true,  0.0, true, 1.0);
	gc_iRounds = AutoExecConfig_CreateConVar("sm_eventname_rounds", "3", "Rounds to play in a row", _, true, 1.0);
	gc_iRoundTime = AutoExecConfig_CreateConVar("sm_eventname_roundtime", "5", "Round time in minutes for a single eventname round", _, true, 1.0);
	gc_iTruceTime = AutoExecConfig_CreateConVar("sm_eventname_trucetime", "15", "Time in seconds players can't deal damage", _, true,  0.0);
	gc_iCooldownDay = AutoExecConfig_CreateConVar("sm_eventname_cooldown_day", "3", "Rounds cooldown after a event until event can be start again", _, true,  0.0);
	gc_iCooldownStart = AutoExecConfig_CreateConVar("sm_eventname_cooldown_start", "3", "Rounds until event can be start after mapchange.", _, true, 0.0);
	gc_bSounds = AutoExecConfig_CreateConVar("sm_eventname_sounds_enable", "1", "0 - disabled, 1 - enable sounds ", _, true, 0.1, true, 1.0);
	gc_sSoundStartPath = AutoExecConfig_CreateConVar("sm_eventname_sounds_start", "music/MyJailbreak/start.mp3", "Path to the soundfile which should be played for a start.");
	gc_bOverlays = AutoExecConfig_CreateConVar("sm_eventname_overlays_enable", "1", "0 - disabled, 1 - enable overlays", _, true,  0.0, true, 1.0);
	gc_sOverlayStartPath = AutoExecConfig_CreateConVar("sm_eventname_overlays_start", "overlays/MyJailbreak/start" , "Path to the start Overlay DONT TYPE .vmt or .vft");
	
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
	
	//Hooks
	HookEvent("round_start", RoundStart);
	HookEvent("round_end", RoundEnd);
	HookConVarChange(gc_sOverlayStartPath, OnSettingChanged);
	HookConVarChange(gc_sSoundStartPath, OnSettingChanged);
	HookConVarChange(gc_sCustomCommand, OnSettingChanged);
	
	//Find
	g_iGetRoundTime = FindConVar("mp_roundtime");
	gc_sOverlayStartPath.GetString(g_sOverlayStart , sizeof(g_sOverlayStart));
	gc_sSoundStartPath.GetString(g_sSoundStartPath, sizeof(g_sSoundStartPath));
	gc_sCustomCommand.GetString(g_sCustomCommand , sizeof(g_sCustomCommand));
}

//ConVarChange for Strings

public int OnSettingChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	if(convar == gc_sOverlayStartPath)    //Add overlay to download and precache table if changed
	{
		strcopy(g_sOverlayStart, sizeof(g_sOverlayStart), newValue);
		if(gc_bOverlays.BoolValue) PrecacheDecalAnyDownload(g_sOverlayStart);
	}
	else if(convar == gc_sSoundStartPath)    //Add sound to download and precache table if changed
	{
		strcopy(g_sSoundStartPath, sizeof(g_sSoundStartPath), newValue);
		if(gc_bSounds.BoolValue) PrecacheSoundAnyDownload(g_sSoundStartPath);
	}
	else if(convar == gc_sCustomCommand)    //Register the custom command if changed
	{
		strcopy(g_sCustomCommand, sizeof(g_sCustomCommand), newValue);
		char sBufferCMD[64];
		Format(sBufferCMD, sizeof(sBufferCMD), "sm_%s", g_sCustomCommand);
		if(GetCommandFlags(sBufferCMD) == INVALID_FCVAR_FLAGS)
			RegConsoleCmd(sBufferCMD, VoteEVENTNAME, "Allows players to vote for EVENTNAME");
	}
}

//Initialize Event

public void OnMapStart()
{
	//set default start values
	g_iVoteCount = 0; //how many player voted for the event
	g_iRound = 0;
	IsEVENTNAME = false;
	StartEVENTNAME = false;
	
	//Precache Sound & Overlay
	if(gc_bSounds.BoolValue) PrecacheSoundAnyDownload(g_sSoundStartPath);
	if(gc_bOverlays.BoolValue) PrecacheDecalAnyDownload(g_sOverlayStart);
}

public void OnConfigsExecuted()
{
	//Find Convar Times
	g_iTruceTime = gc_iTruceTime.IntValue;
	g_iCoolDown = gc_iCooldownStart.IntValue + 1;
	g_iMaxRound = gc_iRounds.IntValue;
	
	//Register the custom command
	char sBufferCMD[64];
	Format(sBufferCMD, sizeof(sBufferCMD), "sm_%s", g_sCustomCommand);
	if(GetCommandFlags(sBufferCMD) == INVALID_FCVAR_FLAGS)
		RegConsoleCmd(sBufferCMD, VoteEVENTNAME, "Allows players to vote for EVENTNAME");
}

//Admin & Warden set Event

public Action SetEVENTNAME(int client,int args)
{
	if (gc_bPlugin.BoolValue) //is plugin enabled?
	{
		if (warden_iswarden(client)) //is player warden?
		{
			if (gc_bSetW.BoolValue) //is warden allowed to set?
			{
				char EventDay[64];
				GetEventDay(EventDay);
				
				if(StrEqual(EventDay, "none", false)) //is an other event running or set?
				{
					if (g_iCoolDown == 0) //is event cooled down?
					{
						StartNextRound(); //prepare Event for next round
					}
					else CPrintToChat(client, "%t %t", "eventname_tag" , "eventname_wait", g_iCoolDown);
				}
				else CPrintToChat(client, "%t %t", "eventname_tag" , "eventname_progress" , EventDay);
			}
			else CPrintToChat(client, "%t %t", "warden_tag" , "nocscope_setbywarden");
		}
		else if (CheckCommandAccess(client, "sm_map", ADMFLAG_CHANGEMAP, true)) //is player admin?
			{
				if (gc_bSetA.BoolValue) //is admin allowed to set?
				{
					char EventDay[64];
					GetEventDay(EventDay);
					
					if(StrEqual(EventDay, "none", false)) //is an other event running or set?
					{
						if (g_iCoolDown == 0) //is event cooled down?
						{
							StartNextRound(); //prepare Event for next round
						}
						else CPrintToChat(client, "%t %t", "eventname_tag" , "eventname_wait", g_iCoolDown);
					}
					else CPrintToChat(client, "%t %t", "eventname_tag" , "eventname_progress" , EventDay);
				}
				else CPrintToChat(client, "%t %t", "nocscope_tag" , "eventname_setbyadmin");
			}
			else CPrintToChat(client, "%t %t", "warden_tag" , "warden_notwarden");
	}
	else CPrintToChat(client, "%t %t", "eventname_tag" , "eventname_disabled");
}

//Voting for Event

public Action VoteEVENTNAME(int client,int args)
{
	char steamid[64];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	
	if (gc_bPlugin.BoolValue) //is plugin enabled?
	{	
		if (gc_bVote.BoolValue) //is voting enabled?
		{	
			char EventDay[64];
			GetEventDay(EventDay);
			
			if(StrEqual(EventDay, "none", false)) //is an other event running or set?
			{
				if (g_iCoolDown == 0) //is event cooled down?
				{
					if (StrContains(g_sHasVoted, steamid, true) == -1) //has player already voted
					{
						int playercount = (GetClientCount(true) / 2);
						g_iVoteCount++;
						int Missing = playercount - g_iVoteCount + 1;
						Format(g_sHasVoted, sizeof(g_sHasVoted), "%s,%s", g_sHasVoted, steamid);
						
						if (g_iVoteCount > playercount) 
						{
							StartNextRound(); //prepare Event for next round
						}
						else CPrintToChatAll("%t %t", "eventname_tag" , "eventname_need", Missing, client);
					}
					else CPrintToChat(client, "%t %t", "eventname_tag" , "eventname_voted");
				}
				else CPrintToChat(client, "%t %t", "eventname_tag" , "eventname_wait", g_iCoolDown);
			}
			else CPrintToChat(client, "%t %t", "eventname_tag" , "eventname_progress" , EventDay);
		}
		else CPrintToChat(client, "%t %t", "eventname_tag" , "eventname_voting");
	}
	else CPrintToChat(client, "%t %t", "eventname_tag" , "eventname_disabled");
}

//Prepare Event

void StartNextRound()
{
	StartEVENTNAME = true;
	g_iCoolDown = gc_iCooldownDay.IntValue + 1;
	g_iVoteCount = 0;
	
	SetEventDay("eventname"); //tell myjailbreak new event is set
	
	CPrintToChatAll("%t %t", "eventname_tag" , "eventname_next");
	PrintHintTextToAll("%t", "eventname_next_nc");
}

//Round start

public void RoundStart(Handle event, char[] name, bool dontBroadcast)
{
	if (StartEVENTNAME || IsEVENTNAME)
	{
		char info1[255], info2[255], info3[255], info4[255], info5[255], info6[255], info7[255], info8[255];
		
		//disable other plugins
		SetCvar("sm_hosties_lr", 0);
		SetCvar("sm_weapons_enable", 0);
		SetCvar("sm_menu_enable", 0);
		SetCvar("sm_warden_enable", 0);
		SetCvar("mp_teammates_are_enemies", 1);
		
		IsEVENTNAME = true;
		
		g_iRound++; //Add Round number
		StartEVENTNAME = false;
		SJD_OpenDoors(); //open Jail
		
		//Create info Panel
		
		EVENTNAMEMenu = CreatePanel();
		Format(info1, sizeof(info1), "%T", "eventname_info_title", LANG_SERVER);
		SetPanelTitle(EVENTNAMEMenu, info1);
		DrawPanelText(EVENTNAMEMenu, "                                   ");
		Format(info2, sizeof(info2), "%T", "eventname_info_line1", LANG_SERVER);
		DrawPanelText(EVENTNAMEMenu, info2);
		DrawPanelText(EVENTNAMEMenu, "-----------------------------------");
		Format(info3, sizeof(info3), "%T", "eventname_info_line2", LANG_SERVER);
		DrawPanelText(EVENTNAMEMenu, info3);
		Format(info4, sizeof(info4), "%T", "eventname_info_line3", LANG_SERVER);
		DrawPanelText(EVENTNAMEMenu, info4);
		Format(info5, sizeof(info5), "%T", "eventname_info_line4", LANG_SERVER);
		DrawPanelText(EVENTNAMEMenu, info5);
		Format(info6, sizeof(info6), "%T", "eventname_info_line5", LANG_SERVER);
		DrawPanelText(EVENTNAMEMenu, info6);
		Format(info7, sizeof(info7), "%T", "eventname_info_line6", LANG_SERVER);
		DrawPanelText(EVENTNAMEMenu, info7);
		Format(info8, sizeof(info8), "%T", "eventname_info_line7", LANG_SERVER);
		DrawPanelText(EVENTNAMEMenu, info8);
		DrawPanelText(EVENTNAMEMenu, "-----------------------------------");
		
		//Find Position in CT Spawn
		
		int RandomCT = 0;
		
		LoopClients(client)
		{
			if (IsClientInGame(client))
			{
				if (GetClientTeam(client) == CS_TEAM_CT)
				{
					RandomCT = client;
					break;
				}
			}
		}
		if (RandomCT)
		{	
			GetClientAbsOrigin(RandomCT, g_fPos);
			
			g_fPos[2] = g_fPos[2] + 45;
			
			if (g_iRound > 0)
			{
				LoopClients(client)
				{
					//Give Players Start Equiptment & parameters
					
					if (IsClientInGame(client))
					{
						StripAllWeapons(client);
						
						if (GetClientTeam(client) == CS_TEAM_CT && IsValidClient(client, false, false))
						{
							//here start Equiptment & parameters
						}
						if (GetClientTeam(client) == CS_TEAM_T && IsValidClient(client, false, false))
						{
							//here start Equiptment & parameters
						}
						GivePlayerItem(client, "weapon_knife"); //give Knife
						SetEntData(client, FindSendPropInfo("CBaseEntity", "m_CollisionGroup"), 2, 4, true); //NoBlock
						SendPanelToClient(EVENTNAMEMenu, client, NullHandler, 20); //open info Panel
						SetEntProp(client, Prop_Data, "m_takedamage", 0, 1); //disable damage
						if (!gc_bSpawnCell.BoolValue) //spawn Terrors to CT Spawn
						{
							TeleportEntity(client, g_fPos, NULL_VECTOR, NULL_VECTOR);
						}
					}
				}
				//Set Start Timer
				g_iTruceTime--;
				TruceTimer = CreateTimer(1.0, StartTimer, _, TIMER_REPEAT);
				CPrintToChatAll("%t %t", "eventname_tag" ,"eventname_rounds", g_iRound, g_iMaxRound);
			}
		}
	}
	else
	{
		//If Event isnt running - subtract cooldown round
		
		char EventDay[64];
		GetEventDay(EventDay);
		
		if(!StrEqual(EventDay, "none", false))
		{
			g_iCoolDown = gc_iCooldownDay.IntValue + 1;
		}
		else if (g_iCoolDown > 0) g_iCoolDown--;
	}
}

//Round End

public void RoundEnd(Handle event, char[] name, bool dontBroadcast)
{
	int winner = GetEventInt(event, "winner");
	
	if (IsEVENTNAME) //if event was running this round
	{
		LoopClients(client)
		{
			if (IsClientInGame(client)) SetEntData(client, FindSendPropInfo("CBaseEntity", "m_CollisionGroup"), 0, 4, true); //disbale noblock
		}
		if (TruceTimer != null) KillTimer(TruceTimer); //kill start time if still running
		if (winner == 2) PrintHintTextToAll("%t", "eventname_twin_nc");
		if (winner == 3) PrintHintTextToAll("%t", "eventname_ctwin_nc");
		if (g_iRound == g_iMaxRound) //if this was the last round
		{
			//return to default start values
			IsEVENTNAME = false;
			StartEVENTNAME = false;
			g_iRound = 0;
			Format(g_sHasVoted, sizeof(g_sHasVoted), "");
			
			//enable other pluigns
			SetCvar("sm_hosties_lr", 1);
			SetCvar("sm_weapons_enable", 1);
			SetCvar("sv_infinite_ammo", 0);
			SetCvar("mp_teammates_are_enemies", 0);
			SetCvar("sm_menu_enable", 1);
			SetCvar("sm_warden_enable", 1);
			
			g_iGetRoundTime.IntValue = g_iOldRoundTime; //return to original round time
			SetEventDay("none"); //tell myjailbreak event is ended
			CPrintToChatAll("%t %t", "eventname_tag" , "eventname_end");
		}
	}
	if (StartEVENTNAME)
	{
		g_iOldRoundTime = g_iGetRoundTime.IntValue; //save original round time
		g_iGetRoundTime.IntValue = gc_iRoundTime.IntValue;//set event round time
		
		CPrintToChatAll("%t %t", "eventname_tag" , "eventname_next");
		PrintHintTextToAll("%t", "eventname_next_nc");
	}
}

//Map End

public void OnMapEnd()
{
	//return to default start values
	IsEVENTNAME = false;
	StartEVENTNAME = false;
	if (TruceTimer != null) KillTimer(TruceTimer); //kill start time if still running
	g_iVoteCount = 0;
	g_iRound = 0;
	g_sHasVoted[0] = '\0'; 
	SetEventDay("none");
}

//Start Timer

public Action StartTimer(Handle timer)
{
	if (g_iTruceTime > 1) //countdown to start
	{
		g_iTruceTime--;
		LoopClients(client)
		if (IsClientInGame(client) && IsPlayerAlive(client))
			{
				PrintCenterText(client,"%t", "eventname_timeuntilstart_nc", g_iTruceTime);
			}
		return Plugin_Continue;
	}
	
	g_iTruceTime = gc_iTruceTime.IntValue;
	
	if (g_iRound > 0)
	{
		LoopClients(client)
		{
			if (IsClientInGame(client) && IsPlayerAlive(client))
			{
				SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
				PrintCenterText(client,"%t", "eventname_start_nc");
			}
			if(gc_bOverlays.BoolValue) CreateTimer( 0.0, ShowOverlayStart, client);
			if(gc_bSounds.BoolValue)	
			{
				EmitSoundToAllAny(g_sSoundStartPath);
			}
		}
		CPrintToChatAll("%t %t", "eventname_tag" , "eventname_start");
	}
	
	TruceTimer = null;
	
	return Plugin_Stop;
}
