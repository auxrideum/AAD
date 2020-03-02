/*
	TODO:
		Most Damages at the end of the round,
		Team-mates stats at the right of screen,
		
*/

#include <a_samp>
#include <a_http>
#include <dini>
#include <zcmd>
#include <sscanf2>
#include <foreach>
#include <YSF>
#include <geolocation>
native gpci(playerid, serial [], len);

#define GM_NAME "AAD"

#define NONE 0
#define ATTACKER 1
#define DEFENDER 2
#define REFEREE 3
#define ATTACKER_SUB 4
#define DEFENDER_SUB 5

#define BASE 0
#define ARENA 1

#define ATTACKER_PLAYING 0xFF000055 
#define ATTACKER_NOT_PLAYING 0xFF444455 
#define ATTACKER_SUB_COLOR 0xFF888855
#define DEFENDER_PLAYING 0x0000FF55
#define DEFENDER_NOT_PLAYING 0x4444FF55
#define DEFENDER_SUB_COLOR 0x8888FF55 
#define REFEREE_COLOR 0xFFFF0055
#define ANN_ADMIN 0x14EC00FF

#define CP_SIZE 2
#define CLEAR_REQUEST_TIME 7

#undef MAX_PLAYERS
#define MAX_PLAYERS 20

#define MAX_TEAMS 6
#define MAX_BASES 20
#define MAX_ARENAS 10
#define MAX_PEDS 40
#define MAX_LOGIN_ATTEMPTS 6
#define MAX_LEVELS 5
#define MAX_COUNTRY_NAME 25
#define MAX_DMS 20

#define DIALOG_LOGIN 0
#define DIALOG_REGISTER 1
#define DIALOG_WEAPONS_TYPE 2
#define DIALOG_SWITCH_TEAM 3
#define DIALOG_ARENA_GUNS 4

#define USER_PATH "AAD/Users/%s.ini"
#define CONFIG_PATH "AAD/config.ini"
#define BASE_PATH "AAD/Bases/%d.ini"
#define ARENA_PATH "AAD/Arenas/%d.ini"
#define DM_PATH "AAD/DMs/%d.ini"

#define KickEx(%1) SetTimerEx("OnPlayerKicked", 500, false, "i", %1)
#define Exclude(%2) SetTimerEx("OnPlayerKicked", 500, false, "i", %2), SendClientMessagef(%2, -1, "Your country is banned.")
#define IsSymbolPacked(%1) ((%1)[0] > 255)

#define KNIFE 4
#define SILENCER 23
#define DEAGLE 24
#define SHOTGUN 25
#define COMBAT 27
#define MP5 29
#define AK47 30
#define M4 31
#define RIFLE 33
#define SNIPER 34

enum pVariables
{
	Name[MAX_PLAYER_NAME],
	
	Level,
	Team,
	Time,
	Weather,
	Netcheck,
	
	FPS,
	DLlast,
	DMReadd,
	
	Float:pHealth,
	Float:pArmour,
	
	Float:RoundDamage,
	RoundDeaths,
	RoundKills,
	
	Float:TotalDamages,
	TotalDeaths,
	TotalKills,
	
	LoginAttempts,
	WeaponPicked,
	OutOfArena,
	
	Float:Z,
	Float:X,
	Float:Y,
	
	bool:Saved,
	bool:Logged,
	bool:Syncing,
	bool:Playing,
	bool:WasInCP,
	bool:ToBeAdded,
	bool:WasInBase,
	bool:InDM
}
new Player[MAX_PLAYERS][pVariables];
new MainTime, MainWeather, Float:MainSpawn[4], MainInterior;
new Skin[MAX_TEAMS], ConfigCPTime, ConfigRoundTime, RoundMints, RoundSeconds;
new TimesPicked[3][6], bool: WarMode = false, CurrentRound = 0, TotalRounds, GameType;

/* DM Variables */

new Float:DMSpawn[MAX_DMS][4];
new DMInterior[MAX_DMS];
new DMWeapons[MAX_DMS][3];
new bool:DMExist[MAX_DMS] = false;

/* Arena Variables */

new Float:AAttackerSpawn[MAX_ARENAS][3], Float:ADefenderSpawn[MAX_ARENAS][3], Float:ACPSpawn[MAX_ARENAS][3];
new AInterior[MAX_ARENAS];
new AName[MAX_ARENAS][128];
new Float:AMax[MAX_ARENAS][2], Float:AMin[MAX_ARENAS][2];
new bool:AExist[MAX_ARENAS] = false, TotalArenas, ArenaZone;
new ArenaWeapons[2][MAX_PLAYERS];
new MenuID[MAX_PLAYERS];

/* Base Variables */

new Float:AttackerSpawn[MAX_BASES][3], Float:DefenderSpawn[MAX_BASES][3], Float:CPSpawn[MAX_BASES][3], Float:ViewArenaCamPos[3];
new BInterior[MAX_BASES], BName[MAX_BASES][128], fWarStats[256];
new bool:BExist[MAX_BASES] = false;

/* Round Variables */

new Current = -1, bool:AllowStartBase = true, bool:BaseStarted = false, bool:ArenaStarted = false, bool:RoundPaused = false, bool:RoundUnPausing = false;
new PlayersAlive[3], Float:TeamHP[3], TeamName[MAX_TEAMS][24], CurrentCPTime, PlayersInCP = 0, bool:TeamHelp[MAX_TEAMS], WeaponLimit[6];
new ViewTimer, bool:FallProtection = false, ElapsedTime = 0, TeamScore[MAX_TEAMS], bool:WaitSwap = false, RoundUnPauseTimer;
new AttList[256], DefList[256], AttKills[256], DefKills[256], AttDeaths[256], DefDeaths[256], AttDamages[256], DefDamages[256];

/* GiveTakeDamage Variables */

new bool:Declared[4][MAX_PLAYERS];
new gLastHit[6][MAX_PLAYERS];
new TakeDmgCD[9][MAX_PLAYERS];
new H[6][MAX_PLAYERS];
new Float:HPLost[2][MAX_PLAYERS][MAX_PLAYERS];
new Float:ILost[MAX_PLAYERS];

/* TextDraws */

new Text: RoundStats[2];
new Text: Intro[8];
new Text: WarStats;

new PlayerText: HPsArmour;
new PlayerText: FPSPingPacket;
new PlayerText: KillsDeathsDamages;
new PlayerText: DoingDamage[3][MAX_PLAYERS];
new PlayerText: GettingDamaged[3][MAX_PLAYERS];

new Text: EndRound_Box, Text: EndRound_BoxA, Text: EndRound_BoxD, Text: EndRound_NameA, Text: EndRound_NameD;
new Text: EndRound_ColTextD, Text: EndRound_NamesA, Text: EndRound_NamesD, Text: EndRound_KillA, Text: EndRound_KillD;
new Text: EndRound_DeathsD, Text: EndRound_DamagesA, Text: EndRound_DamagesD, Text: EndRound_BoxMost, Text: EndRound_TDMost;
new Text: EndRound_BoxHide, Text: EndRound_TDHide, Text: EndRound_DeathsA, Text: EndRound_ColTextA;

/* Continue */

new CCountry[][MAX_COUNTRY_NAME] =
{
	"Russia"
};

/* Functions */

main(){}

public OnGameModeInit()
{
	SetGameModeText(GM_NAME);
	UsePlayerPedAnims();
	
	GameType = BASE;
	
	LoadBases();
	LoadArenas();
	LoadDMs();
	
	if(!fexist(CONFIG_PATH)) dini_Create(CONFIG_PATH);
	else LoadConfig();
	
	LoadTextDraws();
	
	SetWorldTime(MainTime);
	SetWeather(MainWeather);
	
	TeamName[ATTACKER] = "Attackers";
	TeamName[ATTACKER_SUB] = "Attackers Sub";
	TeamName[DEFENDER] = "Defenders";
	TeamName[DEFENDER_SUB] = "Defenders Sub";
	TeamName[REFEREE] = "Referee";
	
	AllowNickNameCharacter(';', true);
	
	SetTimer("OnScriptUpdate", 1000, true);
	
	// my Tests
	

	
	return 1;
}

public OnGameModeExit()
{
	return 1;
}

public OnPlayerConnect(playerid)
{
    LoadPlayerTextDraws(playerid);
    
    Player[playerid][Team] = NONE;
    SetPlayerColor(playerid, 0xAAAAAAAA);

    GetPlayerName(playerid, Player[playerid][Name], 24);
    
    Player[playerid][Level] = 0;
    Player[playerid][Time] = MainTime;
    Player[playerid][Weather] = MainWeather;
	Player[playerid][Netcheck] = 1;
	Player[playerid][RoundKills] = 0;
	Player[playerid][RoundDeaths] = 0;
	Player[playerid][RoundDamage] = 0;
    Player[playerid][TotalDamages] = 0;
	Player[playerid][TotalKills] = 0;
	Player[playerid][TotalDeaths] = 0;
	Player[playerid][LoginAttempts] = 0;
	Player[playerid][WeaponPicked] = 0;
	Player[playerid][OutOfArena] = 10;
	Player[playerid][DMReadd] = 0;
	Player[playerid][Logged] = false;
	Player[playerid][Syncing] = false;
	Player[playerid][Playing] = false;
	Player[playerid][WasInCP] = false;
	Player[playerid][WasInBase] = false;
	Player[playerid][InDM] = false;
	
	new Country[50];
    GetPlayerCountry(playerid, Country, sizeof(Country));
	
	SendClientMessageToAllf(-1, "%s has joined the server. [%s]", Player[playerid][Name], Country);
    
	if(Player[playerid][Logged] == false)
    {
        if(dini_Exists(PlayerPath(playerid)))
        {
            ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "{FFFFFF}Login", "{FFFFFF}Welcome back, your account result registered!\nPut below your password to log in!", "Ok", "Exit");
        }
        else ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "{FFFFFF}Registration", "{FFFFFF}Welcome, your account does not result registered!\nPut below your password to register!", "Ok", "Exit");
	}
    
    for(new i = 0; i < sizeof(CCountry); i++)
    {
 		if(strcmp(CCountry[i], Country, true) == 0) return Exclude(playerid);
	}
	
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    if(Player[playerid][WasInCP] == true)
	{
	    PlayersInCP--;
		if(PlayersInCP <= 0)
		{
		    CurrentCPTime = ConfigCPTime;
		}
	}
	
	if(WarMode == true && Player[playerid][Playing] == true) PauseRound(), SendClientMessageToAllf(-1, "Round has been auto-paused.");

    new DisconnectReason[26];
    
    switch(reason) { case 0: DisconnectReason = "Timeout/Crash"; case 1: DisconnectReason = "Quit"; case 2: DisconnectReason = "Kick/Ban"; }
    
	if(Player[playerid][Playing] == false) SendClientMessageToAllf(-1, "%s has left the server. (%s)", Player[playerid][Name], DisconnectReason);
	else if(Player[playerid][Playing] == true)
	{
	    SendClientMessageToAllf(-1, "%s has left the server. (%s) [HP: %.0f] [Armour: %.0f]", Player[playerid][Name], DisconnectReason, Player[playerid][pHealth], Player[playerid][pArmour]);
		return 1;
    }
	
	return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
	if(Player[playerid][Logged] == true)
	{
		Player[playerid][Team] = NONE;
		SetPlayerPos(playerid, 0, 0, 0); // 1283.097045, -829.105834, 83.140625
	    SetPlayerFacingAngle(playerid, 1.974371);
	    SetPlayerCameraLookAt(playerid, 1283.097045, -829.105834, 83.140625);
	    SetPlayerCameraPos(playerid, 1283.097045 + (5 * floatsin(-1.974371, degrees)), -829.105834 + (5 * floatcos(-1.974371, degrees)), 83.140625);

        TextDrawShowForPlayer(playerid, Intro[0]);
		TextDrawShowForPlayer(playerid, Intro[1]);
		TextDrawShowForPlayer(playerid, Intro[2]);
		TextDrawShowForPlayer(playerid, Intro[3]);
		TextDrawShowForPlayer(playerid, Intro[4]);
		TextDrawShowForPlayer(playerid, Intro[5]);
		TextDrawShowForPlayer(playerid, Intro[6]);
		TextDrawShowForPlayer(playerid, Intro[7]);

	    SelectTextDraw(playerid, -1);
	}
	return 1;
}

public OnPlayerClickTextDraw(playerid, Text:clickedid)
{
	if(Player[playerid][Team] == NONE)
	{
        if(clickedid == Text:65535)
		{
	        return 1;
		}
		
		if(clickedid == Intro[2])
		{
			Player[playerid][Team] = ATTACKER;
		}
		else if(clickedid == Intro[3])
		{
            Player[playerid][Team] = REFEREE;
		}
		else if(clickedid == Intro[4])
		{
            Player[playerid][Team] = DEFENDER;
		}
		
		SpawnPlayer(playerid);
		
		TextDrawHideForPlayer(playerid, Intro[0]);
		TextDrawHideForPlayer(playerid, Intro[1]);
		TextDrawHideForPlayer(playerid, Intro[2]);
		TextDrawHideForPlayer(playerid, Intro[3]);
		TextDrawHideForPlayer(playerid, Intro[4]);
		TextDrawHideForPlayer(playerid, Intro[5]);
		TextDrawHideForPlayer(playerid, Intro[6]);
		TextDrawHideForPlayer(playerid, Intro[7]);

		PlayerTextDrawShow(playerid, FPSPingPacket);
		PlayerTextDrawShow(playerid, HPsArmour);
		PlayerTextDrawShow(playerid, KillsDeathsDamages);
		
		for(new i = 0; i < 3; i++)
		{
			PlayerTextDrawShow(playerid, DoingDamage[i][playerid]);
			PlayerTextDrawShow(playerid, GettingDamaged[i][playerid]);
		}

		if(Current != -1)
		{
			TextDrawShowForPlayer(playerid, RoundStats[0]);
			TextDrawShowForPlayer(playerid, RoundStats[1]);
		}
		
		if(WarMode == true)
		{
		    format(fWarStats, sizeof(fWarStats), "~r~%s ~w~(~r~%d~w~) vs ~b~%s ~w~(~b~%d~w~)~n~Round %d/%d", TeamName[ATTACKER], TeamScore[ATTACKER], TeamName[DEFENDER], TeamScore[DEFENDER], CurrentRound, TotalRounds);

			TextDrawShowForAll(WarStats);
			TextDrawSetString(WarStats, fWarStats);
		}
		
		CancelSelectTextDraw(playerid);
	}
	
	
	
	if(clickedid == EndRound_TDHide) ToggleEndRoundTDs(playerid, false), CancelSelectTextDraw(playerid);
	
	return 1;
}

public OnPlayerRequestSpawn(playerid)
{
	return 0;
}

public OnPlayerSpawn(playerid)
{
    if(Player[playerid][Syncing] == true) return 1;
    
    ClearAnimations(playerid);
    
    SetPlayerPos(playerid, MainSpawn[0], MainSpawn[1], MainSpawn[2]);
	SetPlayerFacingAngle(playerid, MainSpawn[3]);
	SetCameraBehindPlayer(playerid);
	SetPlayerInterior(playerid, MainInterior);
	SetPlayerVirtualWorld(playerid, 0);
	SetPlayerSkin(playerid, Skin[Player[playerid][Team]]);
    
    SetPlayerHealth(playerid, 100);
	SetPlayerArmour(playerid, 100);
    
    ResetPlayerWeapons(playerid);
	SetPlayerTeam(playerid, playerid);
	
	ColorFix(playerid);
	
	if(Player[playerid][DMReadd] > 0)
	{
	    SpawnInDM(playerid, Player[playerid][DMReadd]);
	    return 1;
	}
    
	return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
    if(killerid == INVALID_PLAYER_ID)
	{
	    if(Current == -1) SendDeathMessage(INVALID_PLAYER_ID, playerid, reason);

	    if(Player[playerid][Playing] == true)
		{
            SendDeathMessage(INVALID_PLAYER_ID, playerid, reason);
            
			Player[playerid][RoundDeaths]++;
			Player[playerid][TotalDeaths]++;
	    }

	}
	else if(killerid != INVALID_PLAYER_ID && IsPlayerConnected(killerid))
	{
		if(Current == -1) SendDeathMessage(killerid, playerid, reason);
		
		if(Player[killerid][InDM] == true)
		{
			SetPlayerHealth(killerid, 100);
			SetPlayerArmour(killerid, 100);
		}

		if(Player[killerid][Playing] == true)
		{
		    SendDeathMessage(killerid, playerid, reason);
		    
		    Player[killerid][RoundKills]++;
		    Player[playerid][RoundDeaths]++;
		    
		    Player[killerid][TotalKills]++;
		    Player[playerid][TotalDeaths]++;
		}
	}
	
    if(Player[playerid][WasInCP] == true)
	{
	    PlayersInCP--;
	    Player[playerid][WasInCP] = false;
	    
		if(PlayersInCP <= 0)
		{
		    CurrentCPTime = ConfigCPTime;
		}
	}
	
	if(Player[playerid][Playing] == true)
	{
		SetPlayerVirtualWorld(playerid, 0);
		SetPlayerScore(playerid, 0);

		DisablePlayerCheckpoint(playerid);
		RemovePlayerMapIcon(playerid, 59);

	    Player[playerid][Playing] = false;
		Player[playerid][ToBeAdded] = false;
		Player[playerid][WasInBase] = true;
	}
	
	Player[playerid][InDM] = false;
    
	SetPlayerHealth(playerid, 100);
	
	if(IsPlayerInAnyVehicle(playerid)) RemovePlayerFromVehicle(playerid);
	SetPlayerPos(playerid, 0, 0, 0);

	return 1;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	if(newkeys == 160 && (GetPlayerWeapon(playerid) == 0 || GetPlayerWeapon(playerid) == 1) && !IsPlayerInAnyVehicle(playerid))
	{
		SyncPlayer(playerid);
		return 1;
	}
	
	if(PRESSED(131072) && AllowStartBase == true && Player[playerid][Playing] == true)
	{
	    if(Player[playerid][Team] == ATTACKER && TeamHelp[ATTACKER] == false)
	    {
	        foreach(new i : Player)
			{
			    if((Player[i][Playing] == true || GetPlayerState(i) == PLAYER_STATE_SPECTATING) && i != playerid && Player[i][Team] == ATTACKER)
				{
					SendClientMessagef(i, -1, "[WARNING] Your team-mate %s is asking for help. Distance between you and him: %.0f", Player[playerid][Name], GetDistanceBetweenPlayers(i, playerid));
					
					PlayerPlaySound(i, 6001, 0.0, 0.0, 0.0);
				}
			}
			
			TeamHelp[ATTACKER] = true;
			
			SendClientMessage(playerid, -1, "You have sent a help request.");
			SetTimerEx("ClearAttackerRequest", CLEAR_REQUEST_TIME * 1000, 0, "i", playerid);
	    }
	    else if(Player[playerid][Team] == DEFENDER && TeamHelp[DEFENDER] == false)
	    {
	        foreach(new i : Player)
			{
			    if((Player[i][Playing] == true || GetPlayerState(i) == PLAYER_STATE_SPECTATING) && i != playerid && Player[i][Team] == DEFENDER)
				{
				    SendClientMessagef(i, -1, "[WARNING] Your team-mate %s is asking for help. Distance between you and him: %.0f", Player[playerid][Name], GetDistanceBetweenPlayers(i, playerid));
				    
				    PlayerPlaySound(i, 6001, 0.0, 0.0, 0.0);
				}
			}
			
			TeamHelp[DEFENDER] = true;

			SendClientMessage(playerid, -1, "You have sent a help request.");
			SetTimerEx("ClearDefenderRequest", CLEAR_REQUEST_TIME * 1000, 0, "i", playerid);
	    }
	}
	
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	if(dialogid == DIALOG_REGISTER)
	{
		if(response)
		{
		    if(isnull(inputtext)) return ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "{FFFFFF}Registration", "{FFFFFF}Welcome, your account does not result registered!\nPut below your password to register!", "Ok", "Exit");
			if(strlen(inputtext) > 20) return ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "{FFFFFF}Registration", "{FFFFFF}Welcome, your account does not result registered!\nPut below your password to register!", "Ok", "Exit");

		    new IPAddress[16], Serial[56];

		    GetPlayerIp(playerid, IPAddress, sizeof(IPAddress));
		    gpci(playerid, Serial, sizeof(Serial));

		    dini_Create(PlayerPath(playerid));

		    printf("%s just registered!", Player[playerid][Name]);

	     	dini_Set(PlayerPath(playerid), "Password", inputtext);
	     	dini_IntSet(PlayerPath(playerid), "Level", 0);
	     	dini_IntSet(PlayerPath(playerid), "Time", MainTime);
	     	dini_IntSet(PlayerPath(playerid), "Weather", MainWeather);
	     	dini_IntSet(PlayerPath(playerid), "Netcheck", 1);
	     	dini_Set(PlayerPath(playerid), "IPAddress", IPAddress);
	     	dini_Set(PlayerPath(playerid), "Serial", Serial);

	     	Player[playerid][Level] = 0;
	     	Player[playerid][Time] = MainTime;
	     	Player[playerid][Weather] = MainWeather;
	     	Player[playerid][Netcheck] = 1;
	     	Player[playerid][Logged] = true;

	     	SetPlayerTime(playerid, Player[playerid][Time], 0);
	     	SetPlayerWeather(playerid, Player[playerid][Weather]);

	     	SendClientMessagef(playerid, -1, "Account has been registered! Password: %s", inputtext);
		}
		else KickEx(playerid);
	}

	if(dialogid == DIALOG_LOGIN)
	{
	    if(response)
	    {
	        if(isnull(inputtext)) return ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "{FFFFFF}Login", "{FFFFFF}Welcome back, your account result registered!\nPut below your password to log in!", "Ok", "Exit");

	        new IPAddress[16], Serial[56], CurrentPass[20];

		    GetPlayerIp(playerid, IPAddress, sizeof(IPAddress));
		    gpci(playerid, Serial, sizeof(Serial));
	        format(CurrentPass, sizeof(CurrentPass), dini_Get(PlayerPath(playerid), "Password"));

	        if(strcmp(inputtext, CurrentPass, true) == 0)
			{
			    dini_Set(PlayerPath(playerid), "IPAddress", IPAddress);
	     		dini_Set(PlayerPath(playerid), "Serial", Serial);

	     		Player[playerid][Level] = dini_Int(PlayerPath(playerid), "Level");
	     		Player[playerid][Time] = dini_Int(PlayerPath(playerid), "Time");
	     		Player[playerid][Weather] = dini_Int(PlayerPath(playerid), "Weather");
	     		Player[playerid][Netcheck] = dini_Int(PlayerPath(playerid), "Netcheck");
	     		Player[playerid][Logged] = true;

	     		SetPlayerTime(playerid, Player[playerid][Time], 0);
	     		SetPlayerWeather(playerid, Player[playerid][Weather]);

	     		SendClientMessagef(playerid, -1, "Success Login! Password: %s", inputtext);

	     		OnPlayerRequestClass(playerid, 0);

			}
			else
			{
			    SendClientMessagef(playerid, -1, "You still have %d attempts [%d/%d]", MAX_LOGIN_ATTEMPTS, Player[playerid][LoginAttempts], MAX_LOGIN_ATTEMPTS);
				if(Player[playerid][LoginAttempts] >= MAX_LOGIN_ATTEMPTS) KickEx(playerid);

				return ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "{FFFFFF}Login", "{FFFFFF}Welcome back, your account result registered!\nPut below your password to log in!", "Ok", "Exit"), Player[playerid][LoginAttempts]++;
			}
	    }
	    else KickEx(playerid);
	}

	if(dialogid == DIALOG_WEAPONS_TYPE)
	{
	    if(response)
	    {
	        if(listitem != 0)
			{
				if((Player[playerid][Team] == ATTACKER && TimesPicked[ATTACKER][listitem - 1] >= WeaponLimit[listitem - 1]) || (Player[playerid][Team] == DEFENDER && TimesPicked[DEFENDER][listitem - 1] >= WeaponLimit[listitem - 1]))
				{
	                ShowPlayerWeaponMenu(playerid, Player[playerid][Team]);
	                SendClientMessage(playerid, -1, "Slot totally full.");
					return 1;
		        }
			}
			
			new iStr[128];

			switch(listitem)
			{
   				case 0:
				{
					ShowPlayerWeaponMenu(playerid, Player[playerid][Team]);
					return 1;
     			}
				case 1:
				{
				    GivePlayerWeapon(playerid, SNIPER, 9999);
				    GivePlayerWeapon(playerid, SHOTGUN, 9999);
				    TimesPicked[Player[playerid][Team]][listitem-1]++;
				    Player[playerid][WeaponPicked] = listitem;
				    
					format(iStr, sizeof(iStr), "%s has chosen [Sniper and Shotgun]", Player[playerid][Name]);
				}
				case 2:
				{
				    GivePlayerWeapon(playerid, DEAGLE, 9999);
				    GivePlayerWeapon(playerid, SHOTGUN, 9999);
				    TimesPicked[Player[playerid][Team]][listitem-1]++;
				    Player[playerid][WeaponPicked] = listitem;
				    
				    format(iStr, sizeof(iStr), "%s has chosen [Deagle and Shotgun]", Player[playerid][Name]);
				}
				case 3:
				{ 
				    GivePlayerWeapon(playerid, M4, 9999);
				    GivePlayerWeapon(playerid, SHOTGUN, 9999);
				    TimesPicked[Player[playerid][Team]][listitem-1]++;
				    Player[playerid][WeaponPicked] = listitem;
				    
				    format(iStr, sizeof(iStr), "%s has chosen [M4 and Shotgun]", Player[playerid][Name]);

				}
				case 4:
				{ 
				    GivePlayerWeapon(playerid, COMBAT, 9999);
				    GivePlayerWeapon(playerid, RIFLE, 9999);
				    TimesPicked[Player[playerid][Team]][listitem-1]++;
				    Player[playerid][WeaponPicked] = listitem;
				    
				    format(iStr, sizeof(iStr), "%s has chosen [Combat and Rifle]", Player[playerid][Name]);

				}
				case 5:
				{ 
					GivePlayerWeapon(playerid, DEAGLE, 9999);
					GivePlayerWeapon(playerid, RIFLE, 9999);
					TimesPicked[Player[playerid][Team]][listitem-1]++;
					Player[playerid][WeaponPicked] = listitem;
					
					format(iStr, sizeof(iStr), "%s has chosen [Deagle and Rifle]", Player[playerid][Name]);

				}
				case 6:
				{ 
		  			GivePlayerWeapon(playerid, DEAGLE, 9999);
				  	GivePlayerWeapon(playerid, MP5, 9999);
				  	TimesPicked[Player[playerid][Team]][listitem-1]++;
				  	Player[playerid][WeaponPicked] = listitem;
				  	
				  	format(iStr, sizeof(iStr), "%s has chosen [Deagle and MP5]", Player[playerid][Name]);
		  		}

	        }
	        
	        switch(Player[playerid][Team])
			{
				case ATTACKER:
				{
					foreach(new i : Player)
					{
                		if(Player[i][Team] == ATTACKER) SendClientMessage(i, -1, iStr);
					}
				}
				case DEFENDER:
				{
				    foreach(new i : Player)
					{
                		if(Player[i][Team] == DEFENDER) SendClientMessage(i, -1, iStr);
					}
				}
            }
            
            if(RoundPaused == true) TogglePlayerControllable(playerid, false);
	        else TogglePlayerControllable(playerid, true);
	    }
	    
		return 1;
	}
	
	if(dialogid == DIALOG_ARENA_GUNS)
	{
        if(response)
		{
		    new iString[128];
		    
	        switch(listitem)
			{
				case 0:
				{
                    ShowArenaWeaponMenu(playerid, Player[playerid][Team]);
					return 1;
                }
				case 1:
				{
                    if(MenuID[playerid] == 1)
					{
                        ArenaWeapons[0][playerid] = 24;

                        MenuID[playerid] = 2;
                        ShowArenaWeaponMenu(playerid, Player[playerid][Team]);
                        return 1;

					}
					else if(MenuID[playerid] == 2)
					{
					    if(GetWeaponSlot(24) == GetWeaponSlot(ArenaWeapons[0][playerid]))
						{
					        SendClientMessage(playerid, -1, "ERROR: You can't take again this weapon.");
					        ShowArenaWeaponMenu(playerid, Player[playerid][Team]);
							return 1;
						}

						ArenaWeapons[1][playerid] = 24;
					}
				}
				case 2:
				{
                    if(MenuID[playerid] == 1)
					{
                        ArenaWeapons[0][playerid] = 25;

                        MenuID[playerid] = 2;
                        ShowArenaWeaponMenu(playerid, Player[playerid][Team]);
                        return 1;

					}
					else if(MenuID[playerid] == 2)
					{
					    if(GetWeaponSlot(25) == GetWeaponSlot(ArenaWeapons[0][playerid]))
						{
					        SendClientMessage(playerid, -1, "ERROR: You can't take again this weapon.");
					        ShowArenaWeaponMenu(playerid, Player[playerid][Team]);
							return 1;
						}

						ArenaWeapons[1][playerid] = 25;
					}
				}
				case 3:
				{
                    if(MenuID[playerid] == 1)
					{
                        ArenaWeapons[0][playerid] = 34;

                        MenuID[playerid] = 2;
                        ShowArenaWeaponMenu(playerid, Player[playerid][Team]);
                        return 1;

					}
					else if(MenuID[playerid] == 2)
					{
					    if(GetWeaponSlot(34) == GetWeaponSlot(ArenaWeapons[0][playerid]))
						{
					        SendClientMessage(playerid, -1, "ERROR: You can't take again this weapon.");
					        ShowArenaWeaponMenu(playerid, Player[playerid][Team]);
							return 1;
						}

						ArenaWeapons[1][playerid] = 34;
					}
				}
				case 4:
				{
                    if(MenuID[playerid] == 1)
					{
                        ArenaWeapons[0][playerid] = 31;

                        MenuID[playerid] = 2;
                        ShowArenaWeaponMenu(playerid, Player[playerid][Team]);
                        return 1;

					}
					else if(MenuID[playerid] == 2)
					{
					    if(GetWeaponSlot(31) == GetWeaponSlot(ArenaWeapons[0][playerid]))
						{
					        SendClientMessage(playerid, -1, "ERROR: You can't take again this weapon.");
					        ShowArenaWeaponMenu(playerid, Player[playerid][Team]);
							return 1;
						}

						ArenaWeapons[1][playerid] = 31;
					}
				}
				case 5:
				{
                    if(MenuID[playerid] == 1)
					{
                        ArenaWeapons[0][playerid] = 29;

                        MenuID[playerid] = 2;
                        ShowArenaWeaponMenu(playerid, Player[playerid][Team]);
                        return 1;

					}
					else if(MenuID[playerid] == 2)
					{
					    if(GetWeaponSlot(29) == GetWeaponSlot(ArenaWeapons[0][playerid]))
						{
					        SendClientMessage(playerid, -1, "ERROR: You can't take again this weapon.");
					        ShowArenaWeaponMenu(playerid, Player[playerid][Team]);
							return 1;
						}

						ArenaWeapons[1][playerid] = 29;
					}
				}
				case 6:
				{
                    if(MenuID[playerid] == 1)
					{
                        ArenaWeapons[0][playerid] = 30;

                        MenuID[playerid] = 2;
                        ShowArenaWeaponMenu(playerid, Player[playerid][Team]);
                        return 1;

					}
					else if(MenuID[playerid] == 2)
					{
					    if(GetWeaponSlot(30) == GetWeaponSlot(ArenaWeapons[0][playerid]))
						{
					        SendClientMessage(playerid, -1, "ERROR: You can't take again this weapon.");
					        ShowArenaWeaponMenu(playerid, Player[playerid][Team]);
							return 1;
						}

						ArenaWeapons[1][playerid] = 30;
					}
                }
				case 7:
				{
                    if(MenuID[playerid] == 1)
					{
                        ArenaWeapons[0][playerid] = 33;

                        MenuID[playerid] = 2;
                        ShowArenaWeaponMenu(playerid, Player[playerid][Team]);
                        return 1;

					}
					else if(MenuID[playerid] == 2)
					{
					    if(GetWeaponSlot(33) == GetWeaponSlot(ArenaWeapons[0][playerid]))
						{
					        SendClientMessage(playerid, -1, "ERROR: You can't take again this weapon.");
					        ShowArenaWeaponMenu(playerid, Player[playerid][Team]);
							return 1;
						}

						ArenaWeapons[1][playerid] = 33;
					}
                }
			}

			GivePlayerWeapon(playerid, ArenaWeapons[0][playerid], 9999);
			GivePlayerWeapon(playerid, ArenaWeapons[1][playerid], 9999);

			if(Player[playerid][Team] == ATTACKER)
			{
			    format(iString, sizeof(iString), "%s has chosen [%s and %s]", Player[playerid][Name], WeaponNames[ArenaWeapons[0][playerid]], WeaponNames[ArenaWeapons[1][playerid]]);

				foreach(new i : Player)
				{
				    if(Player[i][Playing] == true && Player[i][Team] == ATTACKER)
					{
						SendClientMessage(i, -1, iString);
					}
				}
			}
			else if (Player[playerid][Team] == DEFENDER)
			{
				format(iString, sizeof(iString), "%s has chosen [%s and %s]", Player[playerid][Name], WeaponNames[ArenaWeapons[0][playerid]], WeaponNames[ArenaWeapons[1][playerid]]);

				foreach(new i : Player)
				{
				    if(Player[i][Playing] == true && Player[i][Team] == DEFENDER)
					{
						SendClientMessage(i, -1, iString);
					}
				}
			}

	        if(RoundPaused == true) TogglePlayerControllable(playerid, false);
	        else TogglePlayerControllable(playerid, true);
		}
		
		return 1;
	}
	
	if(dialogid == DIALOG_SWITCH_TEAM)
	{
	    if(response)
	    {
			switch(listitem)
			{
				case 0: Player[playerid][Team] = ATTACKER;
				case 1: Player[playerid][Team] = DEFENDER;
				case 2: Player[playerid][Team] = ATTACKER_SUB;
				case 3: Player[playerid][Team] = DEFENDER_SUB;
				case 4: Player[playerid][Team] = REFEREE;
			}
			
            ColorFix(playerid);
			SetPlayerSkin(playerid, Skin[Player[playerid][Team]]);
			SetCameraBehindPlayer(playerid);
			
			SendClientMessageToAllf(-1, "%s has switched to: %s", Player[playerid][Name], TeamName[Player[playerid][Team]]);
	    }
	    
	    return 1;
	}

	return 1;
}

public OnPlayerText(playerid, text[])
{
    new pText[144],name[MAX_PLAYER_NAME];
    GetPlayerName(playerid,name,sizeof(name));

    if(text[0] == '!')
	{
		new text2[128];
		
		format(text2, sizeof(text2), "TEAM CHAT || %s: (%d) %s", name, playerid, text[1]);
		
		foreach(new i : Player)
		{
		    if((Player[playerid][Team] == ATTACKER || Player[playerid][Team] == ATTACKER_SUB) && (Player[i][Team] == ATTACKER || Player[i][Team] == ATTACKER_SUB))
			{
				SendClientMessage(i, -1, text2);
			}
		    else if((Player[playerid][Team] == ATTACKER || Player[playerid][Team] == ATTACKER_SUB) && (Player[i][Team] == ATTACKER || Player[i][Team] == ATTACKER_SUB))
			{
				SendClientMessage(i, -1, text2);
			}
		}
		return 0;
	}
	
	format(pText, sizeof (pText), "(%d) %s", playerid, text);
    SendPlayerMessageToAll(playerid, pText);

    return 0;
}

public OnPlayerEnterCheckpoint(playerid)
{
    if(!IsPlayerInAnyVehicle(playerid) && Player[playerid][Playing] == true)
	{
		switch(Player[playerid][Team])
		{
		    case ATTACKER:
			{
				PlayersInCP++;
				Player[playerid][WasInCP] = true;
			}
			case DEFENDER:
			{
			    PlayersInCP = 0;
			    CurrentCPTime = ConfigCPTime;
			}
		}
	}

    return 1;
}

public OnPlayerLeaveCheckpoint(playerid)
{
	if(Player[playerid][Team] == ATTACKER && Player[playerid][WasInCP] == true)
	{
		PlayersInCP--;
	 	Player[playerid][WasInCP] = false;

		if(PlayersInCP <= 0)
		{
		    CurrentCPTime = ConfigCPTime;
		}
	}
    return 1;
}

public OnPlayerEnterVehicle(playerid, vehicleid)
{
	RemovePlayerFromVehicle(playerid);

	return 1;
}

public OnPlayerStreamIn(playerid, forplayerid)
{
	if(Player[playerid][Playing] == true && Player[forplayerid][Playing] == true)
	{
		if(Player[forplayerid][Team] != Player[playerid][Team])
		{
			SetPlayerMarkerForPlayer(forplayerid, playerid, GetPlayerColor(playerid) & 0xFFFFFF00);
		}
		else
		{
			SetPlayerMarkerForPlayer(forplayerid, playerid, GetPlayerColor(playerid) | 0x00000055);
		}
	}
	else if(Player[playerid][Playing] == false && Player[forplayerid][Playing] == true)
	{
		if(Player[forplayerid][Team] != Player[playerid][Team])
		{
			SetPlayerMarkerForPlayer(forplayerid, playerid, GetPlayerColor(playerid) & 0xFFFFFF00);
		}
		else
		{
			SetPlayerMarkerForPlayer(forplayerid, playerid, GetPlayerColor(playerid) | 0x00000055);
		}
	}

	return 1;
}

public OnPlayerStreamOut(playerid, forplayerid)
{
	if(Player[playerid][Playing] == true && Player[forplayerid][Playing] == true)
	{
		if(Player[forplayerid][Team] != Player[playerid][Team])
		{
			SetPlayerMarkerForPlayer(forplayerid,playerid,GetPlayerColor(playerid) & 0xFFFFFF00);
		}
		else
		{
			SetPlayerMarkerForPlayer(forplayerid,playerid,GetPlayerColor(playerid) | 0x00000055);
		}
	}
	else if(Player[playerid][Playing] == false && Player[forplayerid][Playing] == true)
	{
		if(Player[forplayerid][Team] != Player[playerid][Team])
		{
			SetPlayerMarkerForPlayer(forplayerid, playerid, GetPlayerColor(playerid) & 0xFFFFFF00);
		}
		else
		{
			SetPlayerMarkerForPlayer(forplayerid, playerid, GetPlayerColor(playerid) | 0x00000055);
		}
	}
	return 1;
}

public OnPlayerCommandReceived(playerid, cmdtext[])
{
    if(AllowStartBase == false) { SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} You can't use any command for a while."); return 0; }
	if(Player[playerid][Syncing] == true) { SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} You can't use any command for a while."); return 0; }

	if(IsPlayerPaused(playerid))
	{
		foreach(new i : Player) { if(Player[i][Level] > 0) SendClientMessagef(i, -1, "%s is probably manipulating data.", Player[i][Name]); }
	
		return 0;
	}
	
	return 1;
}

public OnPlayerTakeDamage(playerid, issuerid, Float: amount, weaponid)
{
	new iString[256], iColor[10];
	
    if(FallProtection == true && Player[playerid][Playing] == true)
	{
		if(weaponid == 54 || weaponid == 49 || weaponid == 50)
		{
	    	SetPlayerHealth(playerid, 100.0);
		}
		else
		{
		    if(issuerid != INVALID_PLAYER_ID)
			{
				if(Player[issuerid][Team] != Player[playerid][Team])
				{
		    		FallProtection = false;
				}
			}
			else
			{
			    FallProtection = false;
			}
		}
	}
	
    PlayerPlaySound(playerid, 1131, 0.0, 0.0, 0.0);

	new Float:Health[3], Float:Damage;
	
	GetPlayerHealth(playerid, Health[0]);
	GetPlayerArmour(playerid, Health[1]);

	if(Health[0] > 0)
	{
	    if(amount > Health[0])
		{
	        Damage = amount - Health[0];
	        amount = amount - Damage;
		}
	}

	Health[2] = (Health[0] + Health[1]) - amount;
	
	if(Health[2] < 0) { Health[2] = 0; iColor = "~r~"; }
	else if(Health[2] > 100) iColor = "~w~";
	else iColor = "~r~";
	
	if(issuerid != INVALID_PLAYER_ID)
	{
	    if(Player[issuerid][Playing] == true && (Player[issuerid][Team] == Player[playerid][Team])) return 1;
		if(Player[issuerid][Playing] == true && Player[playerid][Playing] == false) return 1;

		PlayerPlaySound(issuerid, 17802, 0.0, 0.0, 0.0);

		if(Player[issuerid][Playing] == true || Player[playerid][Playing] == true)
		{
			Player[issuerid][RoundDamage] += amount;
			Player[issuerid][TotalDamages] += amount;
		}

		HPLost[0][issuerid][playerid] += amount;
		HPLost[1][playerid][issuerid] += amount;

		if(Declared[0][issuerid] == false && gLastHit[1][issuerid] != playerid && gLastHit[2][issuerid] != playerid)
		{
	 		gLastHit[0][issuerid] = playerid;
			Declared[0][issuerid] = true;
		}

		if(gLastHit[0][issuerid] == playerid)
		{
		    format(iString, sizeof(iString), "~g~%s	~w~~h~~h~/ -%.0f ~g~%s ~w~~h~~h~(%s~h~~h~%.0f~w~~h~~h~)", Player[playerid][Name], HPLost[0][issuerid][playerid], WeaponNames[weaponid], iColor, Health[2]);
	     	PlayerTextDrawSetString(issuerid, DoingDamage[0][issuerid], iString);
			TakeDmgCD[0][issuerid] = 1;
			H[0][issuerid] = playerid;
		}
		else
		{
            if(Declared[1][issuerid] == false && gLastHit[2][issuerid] != playerid)
			{
			    gLastHit[1][issuerid] = playerid;
				Declared[1][issuerid] = true;
			}

			if(gLastHit[1][issuerid] == playerid )
			{
             	format(iString, sizeof(iString), "~g~%s	~w~~h~~h~/ -%.0f ~g~%s ~w~~h~~h~(%s~h~~h~%.0f~w~~h~~h~)", Player[playerid][Name], HPLost[0][issuerid][playerid], WeaponNames[weaponid], iColor, Health[2]);
	            PlayerTextDrawSetString(issuerid, DoingDamage[1][issuerid], iString);
				TakeDmgCD[1][issuerid] = 1;
                H[1][issuerid] = playerid;
			}
			else
			{
			    gLastHit[2][issuerid] = playerid;
	            format(iString, sizeof(iString), "~g~%s	~w~~h~~h~/ -%.0f ~g~%s ~w~~h~~h~(%s~h~~h~%.0f~w~~h~~h~)",Player[playerid][Name], HPLost[0][issuerid][playerid], WeaponNames[weaponid], iColor, Health[2]);
				PlayerTextDrawSetString(issuerid, DoingDamage[2][issuerid], iString);
				TakeDmgCD[2][issuerid] = 1;
                H[2][issuerid] = playerid;
			}
		}


		if(Declared[2][playerid] == false && gLastHit[4][playerid] != issuerid && gLastHit[5][playerid] != issuerid){
		    gLastHit[3][playerid] = issuerid;
			Declared[2][playerid] = true;
		}
		if(gLastHit[3][playerid] == issuerid)
		{
			format(iString, sizeof(iString), "~r~%s	~w~~h~~h~/ -%.0f ~r~%s ~w~~h~~h~(%s~h~~h~%.0f~w~~h~~h~)", Player[issuerid][Name], HPLost[1][playerid][issuerid], WeaponNames[weaponid], iColor, Health[2]);
        	PlayerTextDrawSetString(playerid, GettingDamaged[0][playerid], iString);
			TakeDmgCD[3][playerid] = 1;
			H[3][playerid] = issuerid;
		}
		else
		{
		    if(Declared[3][playerid] == false && gLastHit[5][playerid] != issuerid)
			{
			    gLastHit[4][playerid] = issuerid;
				Declared[3][playerid] = true;
			}
			if(gLastHit[4][playerid] == issuerid)
			{
				format(iString, sizeof(iString), "~r~%s	~w~~h~~h~/ -%.0f ~r~%s ~w~~h~~h~(%s~h~~h~%.0f~w~~h~~h~)", Player[issuerid][Name], HPLost[1][playerid][issuerid], WeaponNames[weaponid], iColor, Health[2]);
	        	PlayerTextDrawSetString(playerid, GettingDamaged[1][playerid], iString);
				TakeDmgCD[4][playerid] = 1;
				H[4][playerid] = issuerid;
			}
			else
			{
   				gLastHit[5][playerid] = issuerid;
				format(iString, sizeof(iString), "~r~%s	~w~~h~~h~/ -%.0f ~r~%s ~w~~h~~h~(%s~h~~h~%.0f~w~~h~~h~)", Player[issuerid][Name], HPLost[1][playerid][issuerid], WeaponNames[weaponid], iColor, Health[2]);
	        	PlayerTextDrawSetString(playerid, GettingDamaged[2][playerid], iString);
				TakeDmgCD[5][playerid] = 1;
				H[5][playerid] = issuerid;
			}
		}

	}
	else
	{
		if(GetPlayerState(playerid) != PLAYER_STATE_WASTED)
		{
			ILost[playerid] += amount;
			if(gLastHit[3][playerid] < 0)
			{
				format(iString, sizeof(iString), "~w~~h~~h~-%.0f ~r~%s ~w~~h~~h~(%s~h~~h~%.0f~w~~h~~h~)",ILost[playerid], WeaponNames[weaponid], iColor, Health[2]);
	        	PlayerTextDrawSetString(playerid, GettingDamaged[0][playerid], iString);
				TakeDmgCD[6][playerid] = 1;
			}
			else
			{
				if(gLastHit[4][playerid] < 0)
				{
					format(iString, sizeof(iString), "~w~~h~~h~-%.0f ~r~%s ~w~~h~~h~(%s~h~~h~%.0f~w~~h~~h~)",ILost[playerid], WeaponNames[weaponid], iColor, Health[2]);
		        	PlayerTextDrawSetString(playerid, GettingDamaged[1][playerid], iString);
					TakeDmgCD[7][playerid] = 1;
				}
				else
				{
					format(iString, sizeof(iString), "~w~~h~~h~-%.0f ~r~%s ~w~~h~~h~(%s~h~~h~%.0f~w~~h~~h~)",ILost[playerid], WeaponNames[weaponid], iColor, Health[2]);
		        	PlayerTextDrawSetString(playerid, GettingDamaged[2][playerid], iString);
					TakeDmgCD[8][playerid] = 1;
				}
			}
		}
	}
	
	return 1;
}

/* Silent Aimbot */

public OnPlayerWeaponShot(playerid, weaponid, hittype, hitid, Float:fX, Float:fY, Float:fZ)
{
	printf("HOOK_FUNC_BULLET_DATA: %d, %d, %d, %d, %.0f, %.0f, %.0f", playerid, weaponid, hittype, hitid, fX, fY, fZ);
        
 	new TargetID = GetClosestPlayer(playerid);
 	new Float:Pos[6];

	GetPlayerPos(playerid, Pos[0], Pos[1], Pos[2]);
	GetPlayerPos(TargetID, Pos[3], Pos[4], Pos[5]);

//	SendBulletData(playerid, TargetID, BULLET_HIT_TYPE_PLAYER, GetPlayerWeapon(playerid), Pos[0], Pos[1], Pos[2], Pos[3], Pos[4], Pos[5], 0.1, 0.1, 0.1);

	return 1;
}

/* Commands */

CMD:fakeping(playerid, params[])
{
	new fakeping;
	if(sscanf(params, "d", fakeping)) return SendClientMessage(playerid, 0xFF0000AA, "USAGE: /fakeping <value> (-1 = disable)");

	if(fakeping == -1)
	{
		TogglePlayerFakePing(playerid, false);
	}
	else
	{
        TogglePlayerFakePing(playerid, true);
        SetPlayerFakePing(playerid, fakeping);
	}
	SendClientMessagef(playerid, -1, "fakeping = %d", fakeping);
	return 1;
}

CMD:whoisconnected(playerid, params[])
{
    new i;

	while(i < MAX_PLAYERS)
	{
	    if(IsPlayerConnected(i))
	    {
			SendClientMessagef(playerid, -1, "%s is connected.", Player[i][Name]);
	    }
		i++;
	}
	return 1;
}

CMD:trash(playerid, params[])
{
	new msg[128];
    if(sscanf(params, "s[128]", msg)) return 1;
    
    SendRPC(playerid, 14, BS_FLOAT, 0.0);

	return 1;
}

CMD:pause(playerid, params[])
{
    if(Player[playerid][Level] < 1) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Permission denied.");
    if(Current == -1) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Can't pause/unpause while no round is on-going!");
    
    if(RoundPaused == false)
    {
    
        PauseRound();
    
		SendClientMessageToAllf(ANN_ADMIN, "» Admin %s has paused the round.", Player[playerid][Name]);
    }
    else
    {
        if(RoundUnPausing == true) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Round is being unpaused!");
    
        RoundUnPauseTimer = 4;
		UnPauseRound();
    
        SendClientMessageToAllf(ANN_ADMIN, "» Admin %s has un-paused the round.", Player[playerid][Name]);
    }
    
	return 1;
}

CMD:warend(playerid, params[])
{
    if(Player[playerid][Level] < 1) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Permission denied.");
    if(Current != -1) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Can't end a war while a round is on going!");
    if(WarMode == false) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} War is not started! Use: /war");

    SetTimer("WarEnded", 5000, false);
    SendClientMessageToAllf(-1, "War-mode will be ended in 5 seconds.");
    
    SendClientMessageToAllf(ANN_ADMIN, "» Admin %s has ended war mode.", Player[playerid][Name]);

	return 1;
}


CMD:war(playerid, params[])
{
	new TeamAName[20], TeamBName[25], TotRounds;
	
    if(Player[playerid][Level] < 1) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Permission denied.");
    if(Current != -1) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Can't start a war while a round is on going!");
    if(WarMode == true) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} War already started! Use: /warend");
    if(sscanf(params, "s[20]s[20]d", TeamAName, TeamBName, TotRounds)) return SendClientMessage(playerid, -1, "{14EC00}USAGE:{FBFBFB} /war 1st Name 2nd Name totalrounds");
	if(TotRounds <= 0) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} You need to play at least 1 round.");
	
	WarMode = true;
	
	TeamScore[ATTACKER] = 0;
	TeamScore[DEFENDER] = 0;
	
	CurrentRound = 0;
	TotalRounds = TotRounds;
	
	format(TeamName[ATTACKER], 20, TeamAName);
	format(TeamName[ATTACKER_SUB], 20, "%s Sub", TeamName[ATTACKER]);
	format(TeamName[DEFENDER], 20, TeamBName);
	format(TeamName[DEFENDER_SUB], 20, "%s Sub", TeamName[DEFENDER]);
	
	foreach(new i : Player)
	{
	    Player[i][TotalDamages] = 0;
	    Player[i][TotalKills] = 0;
        Player[i][TotalDeaths] = 0;
	}
	
	format(fWarStats, sizeof(fWarStats), "~r~%s ~w~(~r~%d~w~) vs ~b~%s ~w~(~b~%d~w~)~n~Round %d/%d", TeamName[ATTACKER], TeamScore[ATTACKER], TeamName[DEFENDER], TeamScore[DEFENDER], CurrentRound, TotalRounds);

	TextDrawShowForAll(WarStats);
	TextDrawSetString(WarStats, fWarStats);
	
	if(TotalRounds > 1) SendClientMessageToAllf(ANN_ADMIN, "» Admin %s has enabled Match-Mode. %s vs %s. %d Rounds", Player[playerid][Name], TeamName[ATTACKER], TeamName[DEFENDER], TotRounds);
    else SendClientMessageToAllf(ANN_ADMIN, "» Admin %s has enabled Match-Mode. %s vs %s. %d Round", Player[playerid][Name], TeamName[ATTACKER], TeamName[DEFENDER], TotRounds);

	return 1;
}

CMD:remove(playerid, params[])
{
    new pID;

    if(Player[playerid][Level] < 1) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Permission denied.");
    if(Current == -1) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} There isn't a round on going!");
    if(sscanf(params, "d", pID)) return SendClientMessage(playerid, -1, "{14EC00}USAGE:{FBFBFB} /add [Player ID]");
    if(!IsPlayerConnected(pID)) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Player is not connected.");
	if(Player[pID][Playing] == false) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Player is not playing.");
	
	RemovePlayer(pID);

	SendClientMessageToAllf(ANN_ADMIN, "» Admin %s removed %s from the round.", Player[playerid][Name], Player[pID][Name]);
	
	return 1;
}

CMD:add(playerid, params[])
{
	new pID;
	
    if(Player[playerid][Level] < 1) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Permission denied.");
    if(Current == -1) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} There isn't a round on going!");
    if(sscanf(params, "d", pID)) return SendClientMessage(playerid, -1, "{14EC00}USAGE:{FBFBFB} /add [Player ID]");
    if(!IsPlayerConnected(pID)) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Player is not connected.");

	if(Player[pID][Team] == ATTACKER || Player[pID][Team] == DEFENDER)
	{
	    AddPlayer(pID);
	    SendClientMessageToAllf(ANN_ADMIN, "» Admin %s added %s to the round.", Player[playerid][Name], Player[pID][Name]);
	}
	else SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Player must be attacker/defender.");
    
	return 1;
}

CMD:gunmenu(playerid, params[])
{
    if(Current == -1) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Round is not on-going.");
    if(Player[playerid][Playing] == false) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} You're not in round.");
    
    if(ElapsedTime <= 30 && Player[playerid][Team] != REFEREE)
    {
        switch(GameType)
		{
			case ARENA: ShowArenaWeaponMenu(playerid, Player[playerid][Team]);
			case BASE: ShowPlayerWeaponMenu(playerid, Player[playerid][Team]);
	    }
        
        foreach(new i : Player)
		{
		    if(Player[playerid][Team] == ATTACKER)
			{
		        if(Player[i][Team] == ATTACKER)
				{
		            SendClientMessagef(i, -1, "%s has entered weapon menu.", Player[playerid][Name]);
				}
			}
			else if(Player[playerid][Team] == DEFENDER)
			{
			    if(Player[i][Team] == DEFENDER)
				{
			        SendClientMessagef(i, -1, "%s has entered weapon menu.", Player[playerid][Name]);
				}
			}
		}
    }
    else return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Too late to take new weapons.");
	
    
	return 1;
}

CMD:end(playerid, params[])
{
    if(Player[playerid][Level] < 1) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Permission denied.");
    if(Current == -1) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} There isn't a round on going!");
    if(AllowStartBase == false) SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Wait..");
    
    Current = -1;
   	BaseStarted = false;
   	ArenaStarted = false;
	FallProtection = false;

	TextDrawHideForAll(RoundStats[0]);
	TextDrawHideForAll(RoundStats[1]);

	PlayersInCP = 0;
    CurrentCPTime = 0;
	ElapsedTime = 0;

	TeamHP[ATTACKER] = 0;
	TeamHP[DEFENDER] = 0;

	PlayersAlive[ATTACKER] = 0;
	PlayersAlive[DEFENDER] = 0;

	for(new i; i < 6; i++)
    {
        TimesPicked[ATTACKER][i] = 0;
        TimesPicked[DEFENDER][i] = 0;
    }
    
    foreach(new i : Player)
	{
		SetPlayerVirtualWorld(i, 0);
		SetPlayerScore(i, 0);

		Player[i][RoundDamage] = 0.0;
		Player[i][RoundKills] = 0;
		Player[i][RoundDeaths] = 0;

		DisablePlayerCheckpoint(i);
		RemovePlayerMapIcon(i, 59);

		if(IsPlayerInAnyVehicle(i)) RemovePlayerFromVehicle(i);
		SetPlayerPos(i, 0, 0, 0);
		SpawnPlayer(i);

		Player[i][Playing] = false;
		Player[i][ToBeAdded] = false;
		Player[i][WasInBase] = false;
	}
	
	SendClientMessageToAllf(ANN_ADMIN, "» Admin %s has ended the current round.", Player[playerid][Name]);
    
	return 1;
}

CMD:givemenu(playerid, params[])
{
	new pID;
	
    if(Player[playerid][Level] < 1) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Permission denied.");
    if(Current == -1) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} There isn't a round on going!");
    if(sscanf(params, "d", pID)) return SendClientMessage(playerid, -1, "{14EC00}USAGE:{FBFBFB} /givemenu [Player ID]");
    if(!IsPlayerConnected(pID)) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Player is not connected.");
    if(Player[pID][Playing] == false) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Player is not playing.");

	switch(GameType)
	{
		case ARENA: ShowArenaWeaponMenu(pID, Player[pID][Team]);
		case BASE: ShowPlayerWeaponMenu(pID, Player[pID][Team]);
    }
    
    SendClientMessageToAllf(ANN_ADMIN, "» Admin %s has showed weapon menu for %s", Player[playerid][Name], Player[pID][Name]);
    
	return 1;
}

CMD:swap(playerid, params[])
{
    if(Player[playerid][Level] < 1) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Permission denied.");
    if(Current != -1) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} There's a round on going!");

    SwapTeams();

    SendClientMessageToAllf(ANN_ADMIN, "» Admin %s has swaped the teams.", Player[playerid][Name]);
    
	return 1;
}

CMD:balance(playerid, params[])
{
    if(Player[playerid][Level] < 1) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Permission denied.");
    if(Current != -1) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} There's a round on going!");
    
    BalanceTeams();
    
    SendClientMessageToAllf(ANN_ADMIN, "» Admin %s has balanced the teams.", Player[playerid][Name]);
    
	return 1;
}

CMD:switch(playerid, params)
{
	new iStr[256], CountAtt, CountAttSub, CountRef, CountDef, CountDefSub;
	
	if(Player[playerid][Playing] == true) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} You can't switch while you're playing.");
    
    foreach(new i : Player)
    {
        if(Player[i][Team] == ATTACKER)
			CountAtt ++;
		else if(Player[i][Team] == ATTACKER_SUB)
		    CountAttSub ++;
		else if(Player[i][Team] == REFEREE)
		    CountRef ++;
		else if(Player[i][Team] == DEFENDER_SUB)
		    CountDefSub ++;
  		else if(Player[i][Team] == DEFENDER)
		    CountDef ++;
    }
    
	format(iStr, sizeof(iStr),
	"ID\tName\tPlayers\n\
	%d\t%s\t%d\n\
	%d\t%s\t%d\n\
	%d\t%s\t%d\n\
	%d\t%s\t%d\n\
	%d\t%s\t%d", ATTACKER, TeamName[ATTACKER], CountAtt, DEFENDER, TeamName[DEFENDER], CountDef, ATTACKER_SUB, TeamName[ATTACKER_SUB], CountAttSub, DEFENDER_SUB, TeamName[DEFENDER_SUB], CountDefSub, REFEREE, TeamName[REFEREE], CountRef);
    
    ShowPlayerDialog(playerid, DIALOG_SWITCH_TEAM, DIALOG_STYLE_TABLIST_HEADERS, "Switch Team", iStr, "Select", "Cancel");
    
    return 1;
}

CMD:slap(playerid, params[])
{
	new pID = -1;
	
	if(Player[playerid][Level] < 1) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Permission denied.");
	if(sscanf(params, "d", pID)) return SendClientMessage(playerid, -1, "{14EC00}USAGE:{FBFBFB} /slap [Player ID]");
	if(!IsPlayerConnected(pID)) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Player is not connected.");
	if(Player[playerid][Level] <= Player[pID][Level] && pID != playerid) return SendClientMessage(playerid, -1, "{14EC00}USAGE:{FBFBFB} You can't slap a higher admin.");

	new Float:Pos[3];
	GetPlayerPos(pID, Pos[0], Pos[1], Pos[2]);
	SetPlayerPos(pID, Pos[0], Pos[1], Pos[2] + 10.0);
	
	SendClientMessageToAllf(ANN_ADMIN, "» Admin %s has slapped %s.", Player[playerid][Name], Player[pID][Name]);
	
	return 1;
}

CMD:asd(playerid, params[])
{
	SendClientMessage(playerid, -1, "TEST");
	return 1;
}


CMD:debug(playerid, params[])
{
	GivePlayerWeapon(playerid, 34, 9999);
	GivePlayerWeapon(playerid, 25, 9999);
	GivePlayerWeapon(playerid, 24, 9999);
	GivePlayerWeapon(playerid, 31, 9999);
	
	SendClientMessagef(playerid, -1,
	"PlayersInCP: %d, CurrentCPTime: %d, Team: %d, Netcheck: %d, Name: %s, Time: %d, Weather: %d, Playing: %d, Logged: %d",
	PlayersInCP, CurrentCPTime, Player[playerid][Team], Player[playerid][Netcheck], Player[playerid][Name], Player[playerid][Time], Player[playerid][Weather], Player[playerid][Playing],
	Player[playerid][Logged]);
	
	ShowArenaWeaponMenu(playerid, Player[playerid][Team]);
	
	SendClientMessagef(playerid, -1, "dmg: %.0f kills: %d deaths: %d, wasinbase: %d, tobeadded: %d, allow: %d, curr: %d", Player[playerid][RoundDamage], Player[playerid][RoundKills], Player[playerid][RoundDeaths], Player[playerid][WasInBase], Player[playerid][ToBeAdded], AllowStartBase, Current);
	
	SendClientMessagef(playerid, -1, "totaldmgs: %.0f, totkills: %d, totdeaths: %d, warmode %d, dmreadd: %d, indm: %d", Player[playerid][TotalDamages], Player[playerid][TotalKills], Player[playerid][TotalDeaths], WarMode, Player[playerid][DMReadd], Player[playerid][InDM]);
	
	return 1;
}

CMD:changename(playerid, params[])
{
	new NewName[20], pLocation[128];
	
	if(sscanf(params, "s[20]", NewName)) return SendClientMessage(playerid, -1, "{14EC00}USAGE:{FBFBFB} /changename [New Name]");
	if(strlen(NewName) >= 20) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Name too big.");
	if(!IsValidNickName(NewName)) return SendClientMessagef(playerid, -1, "{BF1616}ERROR:{FBFBFB} Your nickname: %s is not allowed.", NewName);
	if(Player[playerid][Logged] == false) return SendClientMessagef(playerid, -1, "{BF1616}ERROR:{FBFBFB} You need to be logged in.");

	format(pLocation, sizeof(pLocation), USER_PATH, NewName);
	
	if(dini_Exists(pLocation)) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Name already taken.");
	
	frename(PlayerPath(playerid), pLocation);
	SetPlayerName(playerid, NewName);
	
	SendClientMessagef(playerid, -1, "Your nickname has been changed from %s to %s.", Player[playerid][Name], NewName);
    format(Player[playerid][Name], 20, "%s", NewName);

	return 1;
}

CMD:allfs(playerid, params[])
{
	new fszName[52], fsName[52];
	for(new i = 0; i < GetFilterScriptCount(); i++)
	{
		if(GetFilterScriptName(i, fsName, sizeof(fsName)))
		{
		    format(fszName, 52, "%s, %s", fszName, fsName);
		}
	}
	strdel(fszName, 0, 2);
	SendClientMessage(playerid, -1, fszName);
	return 1;
}

CMD:car(playerid, params[])
{
	if(isnull(params)) return SendClientMessage(playerid, -1,"{14EC00}USAGE:{FBFBFB} /v [Vehicle Name]");

	new VehID = GetVehicleModelID(params);
    if(VehID < 400 || VehID > 611) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Invalid Vehicle");

	if(VehID == 432 || VehID == 447 || VehID == 407 || VehID == 430 || VehID == 435 || VehID == 441 || VehID == 447 || VehID == 449 || VehID == 450 || VehID == 464 || VehID == 465) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} You can't spawn this vehicle.");
	if(VehID == 472 || VehID == 476 || VehID == 501 || VehID == 512 || VehID == 537 || VehID == 538 || VehID == 544 || VehID == 553 || VehID == 564 || VehID == 569 || VehID == 570) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} You can't spawn this vehicle.");
	if(VehID == 577 || VehID == 584 || VehID == 590 || VehID == 591 || VehID == 594 || VehID == 595 || VehID == 601 || VehID == 606 || VehID == 607 || VehID == 608 || VehID == 610) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} You can't spawn this vehicle.");
	if(VehID == 611 || VehID == 520 || VehID == 425 || VehID == 476 || VehID == 592 || VehID == 577 || VehID == 592) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} You can't spawn this vehicle.");

	new Float:Pos[4];
	
	GetPlayerPos(playerid, Pos[0], Pos[1], Pos[2]);
	GetPlayerFacingAngle(playerid, Pos[3]);

	if(Player[playerid][Playing] == true)
	{
		if(Player[playerid][Team] == DEFENDER || Player[playerid][Team] == REFEREE) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Since when defenders are able to spawn vehicles?");

		if(BInterior[Current] != 0) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Vehicles in interior are not allowed.");
		if(Pos[0] > AttackerSpawn[Current][0] + 100 || Pos[0] < AttackerSpawn[Current][0] - 100 || Pos[1] > AttackerSpawn[Current][1] + 100 || Pos[1] < AttackerSpawn[Current][1] - 100)
		{
			return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} You're too far from attacker's spawn.");
		}
	}

	if(IsPlayerInAnyVehicle(playerid)) DestroyVehicle(GetPlayerVehicleID(playerid));

 	new MyVehicle = CreateVehicle(VehID, Pos[0], Pos[1], Pos[2], Pos[3], -1, -1, -1);
    LinkVehicleToInterior(MyVehicle, GetPlayerInterior(playerid)); 
	SetVehicleVirtualWorld(MyVehicle, GetPlayerVirtualWorld(playerid)); 
	PutPlayerInVehicle(playerid, MyVehicle, 0); 

	return 1;
}

CMD:v(playerid, params[])
{
	cmd_car(playerid, params);
	return 1;
}

CMD:setlevel(playerid, params[])
{
    new GiveID, LEVEL;
    
	if(Player[playerid][Level] < MAX_LEVELS && !IsPlayerAdmin(playerid)) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Permission denied.");
	if(sscanf(params, "id", GiveID, LEVEL)) return SendClientMessage(playerid, -1, "{14EC00}USAGE:{FBFBFB} /setlevel [Player ID][Level]");

	if(!IsPlayerConnected(GiveID)) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Player isn't connected.");
	if(Player[GiveID][Logged] == false) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Player isn't logged in.");
	if(LEVEL < 0 || LEVEL > MAX_LEVELS) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Invalid level.");
	if(Player[GiveID][Level] == LEVEL) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Player already has this level.");

	dini_IntSet(PlayerPath(GiveID), "Level", LEVEL);
	Player[GiveID][Level] = LEVEL;

	SendClientMessageToAllf(ANN_ADMIN, "» Admin %s has changed %s's level to: %d", Player[playerid][Name], Player[GiveID][Name], Player[GiveID][Level]);

	return 1;
}

CMD:startbase(playerid, params[])
{
    if(Player[playerid][Level] < 1) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Permission denied.");
	if(WaitSwap == true) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Wait..");
	if(Current != -1) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} There's already a round on going!");
    if(AllowStartBase == false) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Please wait.");
    if(isnull(params)) return SendClientMessage(playerid, -1, "{14EC00}USAGE:{FBFBFB} /startbase [Base ID]");
    if(!IsNumeric(params)) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} What are you trying to do?");

    new BaseID = strval(params);
    
    if(BaseID > MAX_BASES) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Invalid Base ID.");
    if(!BExist[BaseID]) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Invalid Base ID.");
    
	foreach(new i : Player)
	{
	    if(Player[i][Team] == ATTACKER || Player[i][Team] == DEFENDER)
		{
		    if(!IsPlayerPaused(i) && IsPlayerSpawned(i))
		    {
				Player[i][ToBeAdded] = true;
    			TogglePlayerControllable(i, false);
			}
		}
	}
	
	GameType = BASE;
	AllowStartBase = false;
	SetTimerEx("OnBaseStart", 4000, false, "i", BaseID);
	
	SendClientMessageToAllf(ANN_ADMIN, "» Admin %s has started Base ID: %d.", Player[playerid][Name], BaseID);

	return 1;
}

CMD:startarena(playerid, params[])
{
	if(Player[playerid][Level] < 1) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Permission denied.");
	if(WaitSwap == true) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Wait..");
	if(Current != -1) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} There's already a round on going!");
    if(AllowStartBase == false) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Please wait.");
    if(isnull(params)) return SendClientMessage(playerid, -1, "{14EC00}USAGE:{FBFBFB} /startarena [Arena ID]");
    if(!IsNumeric(params)) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} What are you trying to do?");

    new ArenaID = strval(params);

    if(ArenaID > MAX_ARENAS) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Invalid Base ID.");
    if(!AExist[ArenaID]) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Invalid Base ID.");

	foreach(new i : Player)
	{
	    if(Player[i][Team] == ATTACKER || Player[i][Team] == DEFENDER)
		{
		    if(!IsPlayerPaused(i) && IsPlayerSpawned(i))
		    {
				Player[i][ToBeAdded] = true;
    			TogglePlayerControllable(i, false);
			}
		}
	}

    GameType = ARENA;
	AllowStartBase = false;
	SetTimerEx("OnArenaStart", 4000, false, "i", ArenaID);

	SendClientMessageToAllf(ANN_ADMIN, "» Admin %s has started Arena ID: %d.", Player[playerid][Name], ArenaID);
	return 1;
}

CMD:dm(playerid, params[])
{
	if(isnull(params)) return SendClientMessage(playerid, -1, "{14EC00}USAGE:{FBFBFB} /dm [DeathMatch ID]");
	if(!IsNumeric(params)) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Invalid DM ID.");

	new DMID = strval(params);
	
	if(DMID >= MAX_DMS) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Invalid DM ID.");
	if(DMExist[DMID] == false) return SendClientMessage(playerid, -1, "{BF1616}ERROR:{FBFBFB} Invalid DM ID.");

	ResetPlayerWeapons(playerid); 
	SetPlayerVirtualWorld(playerid, 1);
	SetPlayerHealth(playerid, 100);
	SetPlayerArmour(playerid, 100);

	SetPlayerPos(playerid, DMSpawn[DMID][0], DMSpawn[DMID][1], DMSpawn[DMID][2]);
	
	GivePlayerWeapon(playerid, DMWeapons[DMID][0], 9999);
	GivePlayerWeapon(playerid, DMWeapons[DMID][1], 9999);
	GivePlayerWeapon(playerid, DMWeapons[DMID][2], 9999);
	
	SetPlayerInterior(playerid, DMInterior[DMID]);

	new iString[140];

    if(DMWeapons[DMID][1] == 0 && DMWeapons[DMID][2] == 0) format(iString, sizeof(iString), "%s has joined DeathMatch %d (%s).", Player[playerid][Name], DMID, WeaponNames[DMWeapons[DMID][0]]); // If the second and third weapons are punch or no weapons then it'll show you just one weapon instead of saying (Deagle - Punch - Punch)
	else if(DMWeapons[DMID][2] == 0) format(iString, sizeof(iString), "%s has joined DeathMatch %d (%s - %s).", Player[playerid][Name], DMID, WeaponNames[DMWeapons[DMID][0]], WeaponNames[DMWeapons[DMID][1]]); //If only the third weapons is punch then it'll show two weapons e.g. (Deagle - Shotgun) instead of (Deagle - Shotgun - Punch)
	else format(iString, sizeof(iString), "%s has joined DeathMatch %d (%s - %s - %s).", Player[playerid][Name], DMID, WeaponNames[DMWeapons[DMID][0]], WeaponNames[DMWeapons[DMID][1]], WeaponNames[DMWeapons[DMID][2]] ); //If all the weapons are known then it'll show u all three weapons e.g. (Deagle - Shotgun - Sniper)

	SendClientMessageToAll(-1, iString); 

	Player[playerid][InDM] = true;
	Player[playerid][DMReadd] = DMID;

	return 1;
}

CMD:leave(playerid, params[])
{
	QuitDM(playerid);
	return 1;

}

/* Forwards */

forward OnScriptUpdate();
public OnScriptUpdate()
{
    PlayersAlive[ATTACKER] = 0;
	PlayersAlive[DEFENDER] = 0;

	TeamHP[ATTACKER] = 0;
	TeamHP[DEFENDER] = 0;
	
	new iStr[256];
	
	foreach(new i : Player)
	{
	    GetPlayerHealth(i, Player[i][pHealth]);
		GetPlayerArmour(i, Player[i][pArmour]);
		ResetPlayerMoney(i);
		GivePlayerMoney(i, -floatround(Player[i][pHealth] + Player[i][pArmour]));
	    
	    GetPlayerFPS(i);
	    
	    new pPing = GetPlayerPing(i);
		new Float:pPacket = GetPlayerPacketLoss(i);
		
        if(FallProtection == false)
		{
			format(iStr, sizeof(iStr), "%.0f~n~~n~~n~%.0f", Player[i][pArmour], Player[i][pHealth]), PlayerTextDrawSetString(i, HPsArmour, iStr);
		}
		else
		{
			if(Player[i][Playing] == true) format(iStr, sizeof(iStr), "~n~~n~~n~PROT.", Player[i][pArmour]), PlayerTextDrawSetString(i, HPsArmour, iStr);
			else
			{
			    format(iStr, sizeof(iStr), "%.0f~n~~n~~n~%.0f", Player[i][pArmour], Player[i][pHealth]), PlayerTextDrawSetString(i, HPsArmour, iStr);
			}
		}
		PlayerTextDrawSetString(i, HPsArmour, iStr);


		format(iStr, sizeof(iStr), "~p~FPS: ~w~%d  ~p~Ping: ~w~%d  ~p~PacketLoss: ~w~%.1f%%", Player[i][FPS], pPing, pPacket);
		PlayerTextDrawSetString(i, FPSPingPacket, iStr);
	    
	    if(PlayersInCP > 0 && Current != -1 && RoundPaused == false) PlayerPlaySound(i, 1056, 0.0, 0.0, 0.0);
	    
	    if(Current != -1 && Player[i][Playing] == true && AllowStartBase == true)
		{
		    if(GameType == ARENA)
		    {
		        if(IsPlayerInArea(i, AMin[Current][0], AMax[Current][0], AMin[Current][1], AMax[Current][1]) != 1)
		        {
		            if(RoundPaused == false)
					{
						Player[i][OutOfArena]--;
					}
					
					if(Player[i][OutOfArena] <= 0)
					{
	    				RemovePlayer(i);
	    				SendClientMessageToAllf(-1, "%s has been removed from arena.", Player[i][Name]);

						Player[i][OutOfArena] = 10;
					}
				}
				else
				{
				    Player[i][OutOfArena] = 10;
				}
		    }
		
		    format(iStr, sizeof(iStr), "Kills ~r~%d~n~~w~Deaths ~r~%d~n~~w~Damages ~r~%.1f", Player[i][RoundKills], Player[i][RoundDeaths], Player[i][RoundDamage]);
			PlayerTextDrawSetString(i, KillsDeathsDamages, iStr);
		
		    switch(Player[i][Team])
			{
	  			case ATTACKER:
				{
	   				PlayersAlive[ATTACKER]++;
				    TeamHP[ATTACKER] = TeamHP[ATTACKER] + (Player[i][pHealth] + Player[i][pArmour]);
				}
				case DEFENDER:
				{
	   				PlayersAlive[DEFENDER]++;
	       			TeamHP[DEFENDER] = TeamHP[DEFENDER] + (Player[i][pHealth] + Player[i][pArmour]);
				}
			}
		}
		
		if(TakeDmgCD[0][i] > 0)
		{
			TakeDmgCD[0][i]++;
			if(TakeDmgCD[0][i] == 5)
			{
				Declared[0][i] = false;
				gLastHit[0][i] = -1;
				HPLost[0][i][H[0][i]] = 0;
				PlayerTextDrawSetString(i, DoingDamage[0][i], "_");
				TakeDmgCD[0][i] = 0;
			}
		}
		if(TakeDmgCD[1][i] > 0)
		{
			TakeDmgCD[1][i]++;
			if(TakeDmgCD[1][i] == 5)
			{
				Declared[1][i] = false;
				gLastHit[1][i] = -2;
				HPLost[0][i][H[1][i]] = 0;
                PlayerTextDrawSetString(i, DoingDamage[1][i], "_");
				TakeDmgCD[1][i] = 0;
			}
		}
		if(TakeDmgCD[2][i] > 0)
		{
			TakeDmgCD[2][i]++;
			if(TakeDmgCD[2][i] == 5)
			{
				HPLost[0][i][H[2][i]] = 0;
                PlayerTextDrawSetString(i, DoingDamage[2][i], "_");
				gLastHit[2][i] = -3;
				TakeDmgCD[2][i] = 0;
			}
		}
		if(TakeDmgCD[3][i] > 0)
		{
			TakeDmgCD[3][i]++;
			if(TakeDmgCD[3][i] == 5)
			{
				Declared[2][i] = false;
				gLastHit[3][i] = -1;
				HPLost[1][i][H[3][i]] = 0;
                PlayerTextDrawSetString(i, GettingDamaged[0][i], "_");
				TakeDmgCD[3][i] = 0;
			}
		}
		if(TakeDmgCD[4][i] > 0)
		{
			TakeDmgCD[4][i]++;
			if(TakeDmgCD[4][i] == 5)
			{
				Declared[3][i] = false;
				gLastHit[4][i] = -2;
				HPLost[1][i][H[4][i]] = 0;
                PlayerTextDrawSetString(i, GettingDamaged[1][i], "_");
				TakeDmgCD[4][i] = 0;
			}
		}
		if(TakeDmgCD[5][i] > 0)
		{
			TakeDmgCD[5][i]++;
			if(TakeDmgCD[5][i] == 5)
			{
				gLastHit[5][i] = -3;
				HPLost[1][i][H[5][i]] = 0;
                PlayerTextDrawSetString(i, GettingDamaged[2][i], "_");
				TakeDmgCD[5][i] = 0;
			}
		}
		if(TakeDmgCD[6][i] > 0)
		{
			TakeDmgCD[6][i]++;
			if(TakeDmgCD[6][i] == 5)
			{
				ILost[i] = 0;
                PlayerTextDrawSetString(i, GettingDamaged[0][i], "_");
				TakeDmgCD[6][i] = 0;
			}
		}
		if(TakeDmgCD[7][i] > 0)
		{
			TakeDmgCD[7][i]++;
			if(TakeDmgCD[7][i] == 5)
			{
                ILost[i] = 0;
                PlayerTextDrawSetString(i, GettingDamaged[1][i], "_");
				TakeDmgCD[7][i] = 0;
			}
		}
		if(TakeDmgCD[8][i] > 0)
		{
			TakeDmgCD[8][i]++;
			if(TakeDmgCD[8][i] == 5)
			{
                ILost[i] = 0;
				PlayerTextDrawSetString(i, GettingDamaged[2][i], "_");
				TakeDmgCD[8][i] = 0;
			}
		}
	    
	}

	if(BaseStarted == true)
	{
	    if(RoundPaused == false)
	    {
		    if(PlayersInCP > 0)
			{
	  			CurrentCPTime--;
	    		if(CurrentCPTime == 0) return EndRound(0);
			}

		    RoundSeconds--;
		    if(RoundSeconds < 0)
			{
	  			RoundSeconds = 59;
	     		RoundMints--;

				if(RoundMints < 0) return EndRound(1);
			}

	//	    if(PlayersAlive[ATTACKER] < 1) return EndRound(2);
//			else if(PlayersAlive[DEFENDER] < 1) return EndRound(3);
			
			ElapsedTime ++;
		}
		
		if(PlayersInCP <= 0) format(iStr, sizeof(iStr), "~r~%s~w~  (Alive: %d) (HPs: %.0f)                                 %d:%02d                                 ~b~%s~w~  (Alive: %d) (HPs: %.0f)", TeamName[ATTACKER], PlayersAlive[ATTACKER], TeamHP[ATTACKER], RoundMints, RoundSeconds, TeamName[DEFENDER], PlayersAlive[DEFENDER], TeamHP[DEFENDER]);
		else format(iStr, sizeof(iStr), "~r~%s~w~  (Alive: %d) (HPs: %.0f)                                CP: %d                                 ~b~%s~w~  (Alive: %d) (HPs: %.0f)", TeamName[ATTACKER], PlayersAlive[ATTACKER], TeamHP[ATTACKER], CurrentCPTime, TeamName[DEFENDER], PlayersAlive[DEFENDER], TeamHP[DEFENDER]);

		TextDrawSetString(RoundStats[1], iStr);
	}
	else if(ArenaStarted == true)
	{
	    if(RoundPaused == false)
	    {
		    RoundSeconds--;
		    if(RoundSeconds < 0)
			{
	  			RoundSeconds = 59;
	     		RoundMints--;

				if(RoundMints < 0)
				{
					if(TeamHP[ATTACKER] < TeamHP[DEFENDER]) EndRound(2);
					else if(TeamHP[DEFENDER] < TeamHP[ATTACKER]) EndRound(3);
					else if(floatround(TeamHP[ATTACKER]) == floatround(TeamHP[DEFENDER])) EndRound(4);
				}
			}

	//	    if(PlayersAlive[ATTACKER] < 1) return EndRound(2);
	//		else if(PlayersAlive[DEFENDER] < 1) return EndRound(3);

			ElapsedTime ++;
		}

		format(iStr, sizeof(iStr), "~r~%s~w~  (Alive: %d) (HPs: %.0f)                                 %d:%02d                                 ~b~%s~w~  (Alive: %d) (HPs: %.0f)", TeamName[ATTACKER], PlayersAlive[ATTACKER], TeamHP[ATTACKER], RoundMints, RoundSeconds, TeamName[DEFENDER], PlayersAlive[DEFENDER], TeamHP[DEFENDER]);

		TextDrawSetString(RoundStats[1], iStr);
	}

	return 1;
}

forward OnArenaStart(ArenaID);
public OnArenaStart(ArenaID)
{
    ClearKillList();
    DestroyAllVehicles();
	Current = ArenaID;
    ElapsedTime = 0;
    
    TeamHP[ATTACKER] = 0;
    TeamHP[DEFENDER] = 0;

    PlayersAlive[ATTACKER] = 0;
    PlayersAlive[DEFENDER] = 0;
    
    ViewArenaCamPos[0] = CPSpawn[Current][0];
	ViewArenaCamPos[1] = CPSpawn[Current][1];
	ViewArenaCamPos[2] = CPSpawn[Current][2];

	foreach(new i : Player)
	{
	    if(Player[i][ToBeAdded] == true)
		{
		    if(Player[i][InDM] == true)
			{
			    Player[i][InDM] = false;
    			Player[i][DMReadd] = 0;
			}

	        SetPlayerVirtualWorld(i, 2);
	        SetPlayerInterior(i, AInterior[Current]);
			TogglePlayerControllable(i, false);
			SetPlayerPos(i, ACPSpawn[Current][0], ACPSpawn[Current][1], ACPSpawn[Current][2]);
		}
	}
	
	ArenaZone = GangZoneCreate(AMin[Current][0], AMin[Current][1], AMax[Current][0], AMax[Current][1]);
	GangZoneShowForAll(ArenaZone, 0x95000099);

	ViewTimer = 9;
	ViewArenaForPlayers();
}

forward ViewArenaForPlayers();
public ViewArenaForPlayers()
{
	ViewTimer--;

	if(ViewTimer == 0)
	{
	    SpawnPlayersInArena();
	    return 1;
	}

	new bool:ViewArenaMoveCamera = false, Float:LastCamPos[3];

    foreach(new i : Player)
	{
		if(Player[i][ToBeAdded] == true)
		{
			PlayerPlaySound(i, 1149, 0.0, 0.0, 0.0);
		}
	}

	switch(ViewTimer)
	{
		case 8:
		{
            ViewArenaMoveCamera = true;

			LastCamPos[0] = ViewArenaCamPos[0];
			LastCamPos[1] = ViewArenaCamPos[1];
			LastCamPos[2] = ViewArenaCamPos[2];

			ViewArenaCamPos[0] = ACPSpawn[Current][0] + randomExInt(15, 25);
			ViewArenaCamPos[1] = ACPSpawn[Current][1] + randomExInt(15, 25);
			ViewArenaCamPos[2] = ACPSpawn[Current][2] + randomExInt(60, 70);
		}

		case 4:
		{
            ViewArenaMoveCamera = true;

			LastCamPos[0] = ViewArenaCamPos[0];
			LastCamPos[1] = ViewArenaCamPos[1];
			LastCamPos[2] = ViewArenaCamPos[2];

			ViewArenaCamPos[0] = ACPSpawn[Current][0] /*+ randomExInt(40, 50)*/;
			ViewArenaCamPos[1] = ACPSpawn[Current][1] /*+ randomExInt(40, 50)*/;
			ViewArenaCamPos[2] = ACPSpawn[Current][2] /*+ 5*/;
		}

	}

	switch(ViewArenaMoveCamera)
	{
		case true:
		{
			foreach(new i : Player)
			{
				if(Player[i][ToBeAdded] == true)
		        {
				    InterpolateCameraPos(i, LastCamPos[0], LastCamPos[1], LastCamPos[2], ViewArenaCamPos[0], ViewArenaCamPos[1], ViewArenaCamPos[2], 4000, CAMERA_MOVE);
				    InterpolateCameraLookAt(i, ACPSpawn[Current][0], ACPSpawn[Current][1], ACPSpawn[Current][2], ACPSpawn[Current][0], ACPSpawn[Current][1], ACPSpawn[Current][2], 4000, CAMERA_MOVE);
				}
			}
		}
	}

	return SetTimer("ViewArenaForPlayers", 1000, false);
}

forward OnBaseStart(BaseID);
public OnBaseStart(BaseID)
{
    ClearKillList(); 
    DestroyAllVehicles();
	Current = BaseID; 
	
    PlayersInCP = 0;
    CurrentCPTime = ConfigCPTime;
    ElapsedTime = 0;

    TeamHP[ATTACKER] = 0;
    TeamHP[DEFENDER] = 0;
    
    PlayersAlive[ATTACKER] = 0;
    PlayersAlive[DEFENDER] = 0;
    
    for(new i; i < 6; i++)
    {
        TimesPicked[ATTACKER][i] = 0;
        TimesPicked[DEFENDER][i] = 0;
    }

    ViewArenaCamPos[0] = CPSpawn[Current][0];
	ViewArenaCamPos[1] = CPSpawn[Current][1];
	ViewArenaCamPos[2] = CPSpawn[Current][2];

	foreach(new i : Player)
	{
	    if(Player[i][ToBeAdded] == true)
		{
		    if(Player[i][InDM] == true)
			{ 
			    Player[i][InDM] = false;
    			Player[i][DMReadd] = 0;
			}
			
	        SetPlayerVirtualWorld(i, 2);
	        SetPlayerInterior(i, BInterior[Current]);
			TogglePlayerControllable(i, false); 
			SetPlayerPos(i, CPSpawn[Current][0], CPSpawn[Current][1], CPSpawn[Current][2]);
			SetPlayerCheckpoint(i, CPSpawn[Current][0], CPSpawn[Current][1], CPSpawn[Current][2], CP_SIZE);
			
		}
	}

	ViewTimer = 9;
	ViewBaseForPlayers();
}

forward ViewBaseForPlayers();
public ViewBaseForPlayers()
{
	ViewTimer--;

	if(ViewTimer == 0)
	{
	    SpawnPlayersInBase();
	    return 1;
	}

	new bool:ViewArenaMoveCamera = false, Float:LastCamPos[3];

    foreach(new i : Player)
	{
		if(Player[i][ToBeAdded] == true)
		{
			PlayerPlaySound(i, 1149, 0.0, 0.0, 0.0);
		}
	}
	
	switch(ViewTimer)
	{
		case 8:
		{
            ViewArenaMoveCamera = true;

			LastCamPos[0] = ViewArenaCamPos[0];
			LastCamPos[1] = ViewArenaCamPos[1];
			LastCamPos[2] = ViewArenaCamPos[2];

			ViewArenaCamPos[0] = CPSpawn[Current][0] + randomExInt(15, 25);
			ViewArenaCamPos[1] = CPSpawn[Current][1] + randomExInt(15, 25);
			ViewArenaCamPos[2] = CPSpawn[Current][2] + randomExInt(60, 70);
		}

		case 4:
		{
            ViewArenaMoveCamera = true;
            
			LastCamPos[0] = ViewArenaCamPos[0];
			LastCamPos[1] = ViewArenaCamPos[1];
			LastCamPos[2] = ViewArenaCamPos[2];
			
			ViewArenaCamPos[0] = CPSpawn[Current][0] /*+ randomExInt(40, 50)*/;
			ViewArenaCamPos[1] = CPSpawn[Current][1] /*+ randomExInt(40, 50)*/;
			ViewArenaCamPos[2] = CPSpawn[Current][2] /*+ 5*/;
		}

	}

	switch(ViewArenaMoveCamera)
	{
		case true:
		{
			foreach(new i : Player)
			{
				if(Player[i][ToBeAdded] == true)
		        {
				    InterpolateCameraPos(i, LastCamPos[0], LastCamPos[1], LastCamPos[2], ViewArenaCamPos[0], ViewArenaCamPos[1], ViewArenaCamPos[2], 4000, CAMERA_MOVE);
				    InterpolateCameraLookAt(i, CPSpawn[Current][0], CPSpawn[Current][1], CPSpawn[Current][2], CPSpawn[Current][0], CPSpawn[Current][1], CPSpawn[Current][2], 4000, CAMERA_MOVE);
				}
			}
		}
	}

	return SetTimer("ViewBaseForPlayers", 1000, false);
}

forward WarEnded();
public WarEnded()
{
    ClearKillList();
    
    if(TeamScore[ATTACKER] > TeamScore[DEFENDER])
    {
    
    }
    else if(TeamScore[DEFENDER] > TeamScore[ATTACKER])
    {
    
    }
	
	TeamScore[ATTACKER] = 0;
    TeamScore[DEFENDER] = 0;
    
    CurrentRound = 0;
    WarMode = false;
    
    TextDrawHideForAll(WarStats);
    
    new MostStats[128], MostDamagesID, Float:DamagesStartValue = 0.0, MostKillsID, KillsStartValue = 0;

	for(new i = 0; i < MAX_PLAYERS; i++)
	{
	    if(!IsPlayerConnected(i)) continue;
	    if(!IsPlayerSpawned(i)) continue;

	    if(Player[i][TotalDamages] > 0)
	    {

			if(Player[i][TotalDamages] > DamagesStartValue) DamagesStartValue = Player[i][TotalDamages], MostDamagesID = i;
            if(Player[i][TotalKills] > KillsStartValue) KillsStartValue = Player[i][TotalKills], MostKillsID = i;

			if(Player[i][Team] == ATTACKER)
			{
	        	format(AttList, sizeof(AttList), "%s%s~n~", AttList, Player[i][Name]);
	        	format(AttKills, sizeof(AttKills), "%s%d~n~", AttKills, Player[i][TotalKills]);
	        	format(AttDeaths, sizeof(AttDeaths), "%s%d~n~", AttDeaths, Player[i][TotalDeaths]);
				format(AttDamages, sizeof(AttDamages), "%s%.0f~n~", AttDamages, Player[i][TotalDamages]);
			}
			else if(Player[i][Team] == DEFENDER)
			{
			    format(DefList, sizeof(DefList), "%s%s~n~", DefList, Player[i][Name]);
                format(DefKills, sizeof(DefKills), "%s%d~n~", DefKills, Player[i][TotalKills]);
                format(DefDeaths, sizeof(DefDeaths), "%s%d~n~", DefDeaths, Player[i][TotalDeaths]);
                format(DefDamages, sizeof(DefDamages), "%s%.0f~n~", DefDamages, Player[i][TotalDamages]);
			}
		}
	}

	if(DamagesStartValue <= 0) format(MostStats, sizeof(MostStats), "Base ID: N/D___Most Damages: None___Most Kills: None");
	else format(MostStats, sizeof(MostStats), "Base ID: N/D___Most Damages: %s___Most Kills: %s", Player[MostDamagesID][Name], Player[MostKillsID][Name]);
    
    foreach(new i : Player)
	{
		Player[i][TotalKills] = 0;
		Player[i][TotalDeaths] = 0;
		Player[i][TotalDamages] = 0;
		
		ToggleEndRoundTDs(i, true);
		SelectTextDraw(i, -1);
	}
	
	TextDrawSetString(EndRound_NamesA, AttList);
	TextDrawSetString(EndRound_NamesD, DefList);
	TextDrawSetString(EndRound_KillA, AttKills);
	TextDrawSetString(EndRound_KillD, DefKills);
	TextDrawSetString(EndRound_DeathsA, AttDeaths);
	TextDrawSetString(EndRound_DeathsD, DefDeaths);
	TextDrawSetString(EndRound_DamagesA, AttDamages);
	TextDrawSetString(EndRound_DamagesD, DefDamages);
	TextDrawSetString(EndRound_TDMost, MostStats);
	TextDrawSetString(EndRound_NameA, TeamName[ATTACKER]);
	TextDrawSetString(EndRound_NameD, TeamName[DEFENDER]);

    TeamName[ATTACKER] = "Attackers";
	TeamName[ATTACKER_SUB] = "Attackers Sub";
	TeamName[DEFENDER] = "Defenders";
	TeamName[DEFENDER_SUB] = "Defenders Sub";

	AttList = "";
    DefList = "";
    AttKills = "";
    DefKills = "";
    AttDeaths = "";
    DefDeaths = "";
    AttDamages = "";
    DefDamages = "";
}

forward UnPauseRound();
public UnPauseRound()
{
	RoundUnPausing = true;
	RoundUnPauseTimer --;
	
	foreach(new i : Player)
	{
	    PlayerPlaySound(i, 1056, 0.0, 0.0, 0.0);
	    
	    if(RoundUnPauseTimer <= 0)
	    {
	        PlayerPlaySound(i, 1149, 0.0, 0.0, 0.0);
	        
	        RoundPaused = false;
	        RoundUnPausing = false;
	        
			if(Player[i][Playing] == true) TogglePlayerControllable(i, true);
	    }
	}
	
	if(RoundUnPauseTimer > 0) SetTimer("UnPauseRound", 1000, 0);

	return 1;
}

forward m_tSwap();
public m_tSwap()
{
	WaitSwap = false;
	SwapTeams();
}

forward OnPlayerKicked(playerid);
public OnPlayerKicked(playerid)
{
	Kick(playerid);
	return 1;
}

forward SyncInProgress(playerid);
public SyncInProgress(playerid)
{
	Player[playerid][Syncing] = false;
}

forward ClearDefenderRequest();
public ClearDefenderRequest()
{
	TeamHelp[DEFENDER] = false;
	
	foreach(new i : Player)
	{
		if(Player[i][Team] == DEFENDER)
		{
			PlayerPlaySound(i, 0, 0.0, 0.0, 0.0);
		}
	}
}

forward ClearAttackerRequest();
public ClearAttackerRequest()
{
	TeamHelp[ATTACKER] = false;

	foreach(new i : Player)
	{
		if(Player[i][Team] == ATTACKER)
		{
			PlayerPlaySound(i, 0, 0.0, 0.0, 0.0);
		}
	}
}

/* Functions without stocks */

SpawnPlayersInBase()
{
	foreach(new i : Player)
	{
	    if(Player[i][ToBeAdded] == true)
	    {
	        Player[i][Playing] = true;
	        Player[i][WasInBase] = true;
	        
	        SetPlayerHealth(i, 100);
	        SetPlayerArmour(i, 100);
	        SetPlayerScore(i, 200);
	        
	        PlayerPlaySound(i, 1057, 0.0, 0.0, 0.0);
	        
	        SetCameraBehindPlayer(i);
	    }
	    
	    if(Player[i][ToBeAdded] == true)
	    {
		    switch(Player[i][Team])
			{
				case ATTACKER:
				{
					SetPlayerPos(i, AttackerSpawn[Current][0] + random(6), AttackerSpawn[Current][1] + random(6), AttackerSpawn[Current][2]);
	 				SetPlayerColor(i, ATTACKER_PLAYING);
					SetPlayerMapIcon(i, 59, AttackerSpawn[Current][0], AttackerSpawn[Current][1], AttackerSpawn[Current][2], 59, 0, MAPICON_GLOBAL);
					SetPlayerTeam(i, Player[i][Team]);
				}
				case DEFENDER:
				{
					SetPlayerPos(i, DefenderSpawn[Current][0] + random(6), DefenderSpawn[Current][1] + random(6), DefenderSpawn[Current][2]);
					SetPlayerColor(i, DEFENDER_PLAYING);
					SetPlayerTeam(i, Player[i][Team]);
				}
			}
			
			ShowPlayerWeaponMenu(i, Player[i][Team]);
		}
		TogglePlayerControllable(i, true);
	}
	
	ClearChat();
	
	RoundMints = ConfigRoundTime;
	RoundSeconds = 0;
	
	RadarFix();
	
	TextDrawShowForAll(RoundStats[0]);
	TextDrawShowForAll(RoundStats[1]);
	
	AllowStartBase = true;
	BaseStarted = true;
	FallProtection = true;
}

SpawnPlayersInArena()
{
	foreach(new i : Player)
	{
	    if(Player[i][ToBeAdded] == true)
	    {
	        Player[i][Playing] = true;
	        Player[i][WasInBase] = true;

	        SetPlayerHealth(i, 100);
	        SetPlayerArmour(i, 100);
	        SetPlayerScore(i, 200);

	        PlayerPlaySound(i, 1057, 0.0, 0.0, 0.0);

	        SetCameraBehindPlayer(i);
	    }

	    if(Player[i][ToBeAdded] == true)
	    {
		    switch(Player[i][Team])
			{
				case ATTACKER:
				{
					SetPlayerPos(i, AAttackerSpawn[Current][0] + random(6), AAttackerSpawn[Current][1] + random(6), AAttackerSpawn[Current][2]);
	 				SetPlayerColor(i, ATTACKER_PLAYING);
					SetPlayerTeam(i, Player[i][Team]);
				}
				case DEFENDER:
				{
					SetPlayerPos(i, ADefenderSpawn[Current][0] + random(6), ADefenderSpawn[Current][1] + random(6), ADefenderSpawn[Current][2]);
					SetPlayerColor(i, DEFENDER_PLAYING);
					SetPlayerTeam(i, Player[i][Team]);
				}
			}
			
			MenuID[i] = 1;
	        ShowArenaWeaponMenu(i, Player[i][Team]);
		}
		TogglePlayerControllable(i, true);
	}

	ClearChat();

	RoundMints = ConfigRoundTime;
	RoundSeconds = 0;

	RadarFix();

	TextDrawShowForAll(RoundStats[0]);
	TextDrawShowForAll(RoundStats[1]);

	AllowStartBase = true;
	ArenaStarted = true;
	FallProtection = false;
}

EndRound(WinID)
{
	new iString[256];
	
	switch(WinID)
	{
		case 0:
		{
			format(iString, sizeof(iString), "%s took control of the checkpoint.", TeamName[ATTACKER]);
			if(WarMode == true) TeamScore[ATTACKER]++;
		}
		case 1:
		{
			format(iString, sizeof(iString), "%s won the round!", TeamName[DEFENDER]);
			if(WarMode == true) TeamScore[DEFENDER]++;
		}
		case 2:
		{
			format(iString, sizeof(iString), "%s won the round!", TeamName[DEFENDER]);
			if(WarMode == true) TeamScore[DEFENDER]++;
		}
		case 3:
		{
			format(iString, sizeof(iString), "%s won the round!", TeamName[ATTACKER]);
			if(WarMode == true) TeamScore[ATTACKER]++;
		}
	}
	
	if(WarMode == true)
	    CurrentRound ++;
	
	format(fWarStats, sizeof(fWarStats), "~r~%s ~w~(~r~%d~w~) vs ~b~%s ~w~(~b~%d~w~)~n~Round %d/%d", TeamName[ATTACKER], TeamScore[ATTACKER], TeamName[DEFENDER], TeamScore[DEFENDER], CurrentRound, TotalRounds);
	TextDrawSetString(WarStats, fWarStats);
	
	BaseStarted = false;
	ArenaStarted = false;
	FallProtection = false;
	
	GangZoneDestroy(ArenaZone);
	
	TextDrawHideForAll(RoundStats[0]);
	TextDrawHideForAll(RoundStats[1]);
	
	PlayersInCP = 0;
    CurrentCPTime = 0;
	ElapsedTime = 0;
	
	TeamHP[ATTACKER] = 0;
	TeamHP[DEFENDER] = 0;
	
	PlayersAlive[ATTACKER] = 0;
	PlayersAlive[DEFENDER] = 0;
	
	for(new i; i < 6; i++)
    {
        TimesPicked[ATTACKER][i] = 0;
        TimesPicked[DEFENDER][i] = 0;
    }
	
	new MostStats[128], MostDamagesID, Float:DamagesStartValue = 0.0, MostKillsID, KillsStartValue = 0;
	
	for(new i = 0; i < MAX_PLAYERS; i++)
	{
	    if(!IsPlayerConnected(i)) continue;
	    if(!IsPlayerSpawned(i)) continue;
	    
	    if(Player[i][WasInBase] == true)
	    {
	    
			if(Player[i][RoundDamage] > DamagesStartValue) DamagesStartValue = Player[i][RoundDamage], MostDamagesID = i;
            if(Player[i][RoundKills] > KillsStartValue) KillsStartValue = Player[i][RoundKills], MostKillsID = i;
	    
			if(Player[i][Team] == ATTACKER)
			{
	        	format(AttList, sizeof(AttList), "%s%s~n~", AttList, Player[i][Name]);
	        	format(AttKills, sizeof(AttKills), "%s%d~n~", AttKills, Player[i][RoundKills]);
	        	format(AttDeaths, sizeof(AttDeaths), "%s%d~n~", AttDeaths, Player[i][RoundDeaths]);
				format(AttDamages, sizeof(AttDamages), "%s%.0f~n~", AttDamages, Player[i][RoundDamage]);
			}
			else if(Player[i][Team] == DEFENDER)
			{
			    format(DefList, sizeof(DefList), "%s%s~n~", DefList, Player[i][Name]);
                format(DefKills, sizeof(DefKills), "%s%d~n~", DefKills, Player[i][RoundKills]);
                format(DefDeaths, sizeof(DefDeaths), "%s%d~n~", DefDeaths, Player[i][RoundDeaths]);
                format(DefDamages, sizeof(DefDamages), "%s%.0f~n~", DefDamages, Player[i][RoundDamage]);
			}
		}
	}
	
	if(DamagesStartValue <= 0) format(MostStats, sizeof(MostStats), "Base ID: %d___Most Damages: None___Most Kills: None", Current);
	else format(MostStats, sizeof(MostStats), "Base ID: %d___Most Damages: %s___Most Kills: %s", Current, Player[MostDamagesID][Name], Player[MostKillsID][Name]);

	Current = -1;
	
	foreach(new i : Player)
	{
		SendClientMessage(i, -1, iString);
		SetPlayerVirtualWorld(i, 0);
		SetPlayerScore(i, 0);
		
		Player[i][RoundDamage] = 0.0;
		Player[i][RoundKills] = 0;
		Player[i][RoundDeaths] = 0;
		
		DisablePlayerCheckpoint(i);
		RemovePlayerMapIcon(i, 59);
		
		if(IsPlayerInAnyVehicle(i)) RemovePlayerFromVehicle(i);
		SetPlayerPos(i, 0, 0, 0);
		SpawnPlayer(i);
		
		Player[i][Playing] = false;
		Player[i][ToBeAdded] = false;
		Player[i][WasInBase] = false;
		
		SelectTextDraw(i, -1);
		ToggleEndRoundTDs(i, true);
	}
	
	TextDrawSetString(EndRound_NamesA, AttList);
	TextDrawSetString(EndRound_NamesD, DefList);
	TextDrawSetString(EndRound_KillA, AttKills);
	TextDrawSetString(EndRound_KillD, DefKills);
	TextDrawSetString(EndRound_DeathsA, AttDeaths);
	TextDrawSetString(EndRound_DeathsD, DefDeaths);
	TextDrawSetString(EndRound_DamagesA, AttDamages);
	TextDrawSetString(EndRound_DamagesD, DefDamages);
	TextDrawSetString(EndRound_TDMost, MostStats);
	TextDrawSetString(EndRound_NameA, TeamName[ATTACKER]);
	TextDrawSetString(EndRound_NameD, TeamName[DEFENDER]);
	
	AttList = "";
    DefList = "";
    AttKills = "";
    DefKills = "";
    AttDeaths = "";
    DefDeaths = "";
    AttDamages = "";
    DefDamages = "";
    
    WaitSwap = true;
	SetTimer("m_tSwap", 2500, false);
	
	if(CurrentRound >= TotalRounds && CurrentRound != 0)
	{
	    SendClientMessageToAllf(-1, "War ended. %s (%d) - %s (%d)", TeamName[ATTACKER], TeamScore[ATTACKER], TeamName[DEFENDER], TeamScore[DEFENDER]);
		SetTimer("WarEnded", 5000, false);
	}
	
	return 1;
}

BalanceTeams()
{
	new TotalAttackers;
	new TotalDefenders;

	foreach(new i : Player)
	{
		if(IsPlayerSpawned(i) && !IsPlayerPaused(i) && (Player[i][Team] == ATTACKER || Player[i][Team] == DEFENDER))
		{
			new tid = random(2);
			if (tid == 0)
			{
				Player[i][Team] = DEFENDER;
			    TotalDefenders++;
			}
			else if (tid == 1)
			{
		 		Player[i][Team] = ATTACKER;
			    TotalAttackers++;
			}

			ColorFix(i);
			SetPlayerSkin(i, Skin[Player[i][Team]]);

			ClearAnimations(i);
		}
	}

    new Divisor = floatround((TotalDefenders + TotalAttackers) / 2);

	foreach(new i : Player)
	{
		if(Player[i][Team] == ATTACKER || Player[i][Team] == DEFENDER)
		{
			new randomnum = random(2);
			switch(randomnum)
			{
				case 0:
				{
		    		if(TotalDefenders <= Divisor)
					{
		       	 		if(Player[i][Team] == ATTACKER) TotalAttackers--;
		       	 		
						Player[i][Team] = DEFENDER;
		        		TotalDefenders++;

					}
					else if(TotalAttackers <= Divisor)
					{
		        		if(Player[i][Team] == DEFENDER) TotalDefenders--;
		        		
					 	Player[i][Team] = ATTACKER;
						TotalAttackers++;
					}
				}
				case 1:
				{
			    	if(TotalAttackers <= Divisor)
					{
		        		if(Player[i][Team] == DEFENDER) TotalDefenders--;
		        		
					 	Player[i][Team] = ATTACKER;
						TotalAttackers++;

					}
					else if(TotalDefenders <= Divisor)
					{
		       	 		if(Player[i][Team] == ATTACKER) TotalAttackers--;
		       	 		
						Player[i][Team] = DEFENDER;
		        		TotalDefenders++;
		    		}
				}
			}
			
			if(TotalDefenders == TotalAttackers) break;

			ColorFix(i);
			SetPlayerSkin(i, Skin[Player[i][Team]]);

			ClearAnimations(i);
		}
	}
}

ShowPlayerWeaponMenu(playerid, team)
{
	ResetPlayerWeapons(playerid);

    if(Player[playerid][WeaponPicked] > 0)
	{
 		TimesPicked[Player[playerid][Team]][Player[playerid][WeaponPicked] - 1] --;
 		Player[playerid][WeaponPicked] = 0;
	}

	new WeapStr[256];
	
	switch(team)
	{
	    case ATTACKER:
		{
			format(WeapStr, sizeof(WeapStr), "Slot\tFirst Gun\tSecond Gun\tLimit \n1\tSniper\t\tShot\t\t%d \n2\tDeagle\t\tShot\t\t%d \n3\tM4\t\tShot\t\t%d \n4\tCombat\t\tRifle\t\t%d \n5\tDeagle\t\tRifle\t\t%d \n6\tDeagle\t\tMP5\t\t%d ", WeaponLimit[0] - TimesPicked[ATTACKER][0], WeaponLimit[1] - TimesPicked[ATTACKER][1],  WeaponLimit[2] - TimesPicked[ATTACKER][2],  WeaponLimit[3] - TimesPicked[ATTACKER][3],  WeaponLimit[4] - TimesPicked[ATTACKER][4],  WeaponLimit[5] - TimesPicked[ATTACKER][5]);
			ShowPlayerDialog(playerid, DIALOG_WEAPONS_TYPE, DIALOG_STYLE_LIST, "Select your slot!", WeapStr, "Select", "Exit");
		}
		case DEFENDER:
		{
			format(WeapStr, sizeof(WeapStr), "Slot\tFirst Gun\tSecond Gun\tLimit \n1\tSniper\t\tShot\t\t%d \n2\tDeagle\t\tShot\t\t%d \n3\tM4\t\tShot\t\t%d \n4\tCombat\t\tRifle\t\t%d \n5\tDeagle\t\tRifle\t\t%d \n6\tDeagle\t\tMP5\t\t%d ", WeaponLimit[0] - TimesPicked[ATTACKER][0], WeaponLimit[1] - TimesPicked[ATTACKER][1],  WeaponLimit[2] - TimesPicked[ATTACKER][2],  WeaponLimit[3] - TimesPicked[ATTACKER][3],  WeaponLimit[4] - TimesPicked[ATTACKER][4],  WeaponLimit[5] - TimesPicked[ATTACKER][5]);
			ShowPlayerDialog(playerid, DIALOG_WEAPONS_TYPE, DIALOG_STYLE_LIST, "Select your slot!", WeapStr, "Select", "Exit");
		}
	}
}

ShowArenaWeaponMenu(playerid, team)
{
	new iString[256], Title[60];

    ResetPlayerWeapons(playerid);

	switch(team)
	{
		case ATTACKER:
		{
		    if(MenuID[playerid] == 1) Title = "Primary Weapon";
		    else if(MenuID[playerid] == 2) Title = "Secondary Weapon";

			format(iString, sizeof(iString), "%s\nDeagle\nShot\nSniper\nM4\nMP5\nAK-47\nRifle", Title);
			ShowPlayerDialog(playerid, DIALOG_ARENA_GUNS, DIALOG_STYLE_LIST, "Select Weapons", iString, "Select", "Exit");

		}
		case DEFENDER:
		{

		    if(MenuID[playerid] == 1) Title = "Primary Weapon";
		    else if(MenuID[playerid] == 2) Title = "Secondary Weapon";

			format(iString, sizeof(iString), "%s\nDeagle\nShot\nSniper\nM4\nMP5\nAK-47\nRifle", Title);
			ShowPlayerDialog(playerid, DIALOG_ARENA_GUNS, DIALOG_STYLE_LIST, "Select Weapons", iString, "Select", "Exit");
		}
	}
}

RemovePlayer(playerid)
{
	Player[playerid][Playing] = false;
	
	if(Current != -1 && Player[playerid][WasInCP] == true)
	{
	    Player[playerid][WasInCP] = false;
	    PlayersInCP--;
		if(PlayersInCP <= 0)
		{
		    CurrentCPTime = ConfigCPTime;
		}
	}
	
	Player[playerid][WasInBase] = false;
	TogglePlayerControllable(playerid, true);
	RemovePlayerMapIcon(playerid, 59);
	DisablePlayerCheckpoint(playerid);
	SetPlayerScore(playerid, 0);
	
	if(Player[playerid][WeaponPicked] > 0)
	{
 		TimesPicked[Player[playerid][Team]][Player[playerid][WeaponPicked] - 1] --;
 		Player[playerid][WeaponPicked] = 0;
	}
	
	SpawnPlayer(playerid);
}

AddPlayer(playerid)
{
	Player[playerid][Playing] = true;
	Player[playerid][WasInBase] = true;
	
	Player[playerid][RoundKills] = 0;
	Player[playerid][RoundDeaths] = 0;
	Player[playerid][RoundDamage] = 0.0;
	
	SetCameraBehindPlayer(playerid);

	SetPlayerArmour(playerid, 100);
	SetPlayerHealth(playerid, 100);
	
	SetPlayerVirtualWorld(playerid, 2);
    SetPlayerInterior(playerid, BInterior[Current]);
    
    switch(Player[playerid][Team])
	{
	    case ATTACKER:
		{
		    SetPlayerPos(playerid, AttackerSpawn[Current][0] + random(6), AttackerSpawn[Current][1] + random(6), AttackerSpawn[Current][2]);
			SetPlayerColor(playerid, ATTACKER_PLAYING);
			SetPlayerMapIcon(playerid, 59, AttackerSpawn[Current][0], AttackerSpawn[Current][1], AttackerSpawn[Current][2], 59, 0, MAPICON_GLOBAL);
            SetPlayerCheckpoint(playerid, CPSpawn[Current][0], CPSpawn[Current][1], CPSpawn[Current][2], 2);
			SetPlayerTeam(playerid, ATTACKER);
		}
		case DEFENDER:
		{
            SetPlayerPos(playerid, DefenderSpawn[Current][0] + random(6), DefenderSpawn[Current][1] + random(6), DefenderSpawn[Current][2]);
			SetPlayerColor(playerid, DEFENDER_PLAYING);
			SetPlayerMapIcon(playerid, 59, DefenderSpawn[Current][0], DefenderSpawn[Current][1], DefenderSpawn[Current][2], 59, 0, MAPICON_GLOBAL);
            SetPlayerCheckpoint(playerid, CPSpawn[Current][0], CPSpawn[Current][1], CPSpawn[Current][2], 2);
			SetPlayerTeam(playerid, DEFENDER);
		}
		
	}
	
	ShowPlayerWeaponMenu(playerid, Player[playerid][Team]);
	
	foreach(new i : Player)
	{
	    OnPlayerStreamIn(i, playerid);
	    OnPlayerStreamIn(playerid, i);
	}
}

SpawnInDM(playerid, DMID)
{
	ResetPlayerWeapons(playerid); 
	SetPlayerVirtualWorld(playerid, 1); 
	SetPlayerHealth(playerid, 100);
	SetPlayerArmour(playerid, 100);

    SetPlayerPos(playerid, DMSpawn[DMID][0], DMSpawn[DMID][1], DMSpawn[DMID][2]);

	GivePlayerWeapon(playerid, DMWeapons[DMID][0], 9999);
	GivePlayerWeapon(playerid, DMWeapons[DMID][1], 9999);
	GivePlayerWeapon(playerid, DMWeapons[DMID][2], 9999);
	
	SetPlayerInterior(playerid, DMInterior[DMID]);

    Player[playerid][InDM] = true;
}

QuitDM(playerid)
{
    ResetPlayerWeapons(playerid);
    Player[playerid][InDM] = false;
    Player[playerid][DMReadd] = 0;
    SpawnPlayer(playerid);
}

randomExInt(min, max)
{
	return random(max - min) + min;
}

ToggleEndRoundTDs(playerid, bool:toggle)
{
	if(toggle)
	{
	    TextDrawShowForPlayer(playerid, EndRound_Box), TextDrawShowForPlayer(playerid, EndRound_BoxA), TextDrawShowForPlayer(playerid, EndRound_BoxD);
		TextDrawShowForPlayer(playerid, EndRound_NameA), TextDrawShowForPlayer(playerid, EndRound_NameD), TextDrawShowForPlayer(playerid, EndRound_ColTextA);
		TextDrawShowForPlayer(playerid, EndRound_ColTextD), TextDrawShowForPlayer(playerid, EndRound_NamesA), TextDrawShowForPlayer(playerid, EndRound_NamesD);
		TextDrawShowForPlayer(playerid, EndRound_KillA), TextDrawShowForPlayer(playerid, EndRound_KillD), TextDrawShowForPlayer(playerid, EndRound_DeathsA);
		TextDrawShowForPlayer(playerid, EndRound_DeathsD), TextDrawShowForPlayer(playerid, EndRound_DamagesA), TextDrawShowForPlayer(playerid, EndRound_DamagesD);
		TextDrawShowForPlayer(playerid, EndRound_BoxMost), TextDrawShowForPlayer(playerid, EndRound_TDMost), TextDrawShowForPlayer(playerid, EndRound_BoxHide);
		TextDrawShowForPlayer(playerid, EndRound_TDHide);
	}
	else if(!toggle)
	{
 		TextDrawHideForPlayer(playerid, EndRound_Box), TextDrawHideForPlayer(playerid, EndRound_BoxA), TextDrawHideForPlayer(playerid, EndRound_BoxD);
		TextDrawHideForPlayer(playerid, EndRound_NameA), TextDrawHideForPlayer(playerid, EndRound_NameD), TextDrawHideForPlayer(playerid, EndRound_ColTextA);
		TextDrawHideForPlayer(playerid, EndRound_ColTextD), TextDrawHideForPlayer(playerid, EndRound_NamesA), TextDrawHideForPlayer(playerid, EndRound_NamesD);
		TextDrawHideForPlayer(playerid, EndRound_KillA), TextDrawHideForPlayer(playerid, EndRound_KillD), TextDrawHideForPlayer(playerid, EndRound_DeathsA);
		TextDrawHideForPlayer(playerid, EndRound_DeathsD), TextDrawHideForPlayer(playerid, EndRound_DamagesA), TextDrawHideForPlayer(playerid, EndRound_DamagesD);
		TextDrawHideForPlayer(playerid, EndRound_BoxMost), TextDrawHideForPlayer(playerid, EndRound_TDMost), TextDrawHideForPlayer(playerid, EndRound_BoxHide);
		TextDrawHideForPlayer(playerid, EndRound_TDHide);
	}
}

SyncPlayer(playerid)
{
	if(Player[playerid][Syncing] == true) return 1;
	if(AllowStartBase == false) return 1;
	if(IsPlayerInAnyVehicle(playerid)) return 1;

	Player[playerid][Syncing] = true;
	SetTimerEx("SyncInProgress", 1000, false, "i", playerid);

	new Float:HP[2], Float:Pos[4], Int, VirtualWorld;
	
	GetPlayerHealth(playerid, HP[0]);
	GetPlayerArmour(playerid, HP[1]);

	GetPlayerPos(playerid, Pos[0], Pos[1], Pos[2]);
	GetPlayerFacingAngle(playerid, Pos[3]);

	Int = GetPlayerInterior(playerid);
	VirtualWorld = GetPlayerVirtualWorld(playerid);

	new Weapons[13][2];
	for(new i = 0; i < 13; i++)
	{
	    GetPlayerWeaponData(playerid, i, Weapons[i][0], Weapons[i][1]);
	}

	ClearAnimations(playerid);

	SetSpawnInfo(playerid, GetPlayerTeam(playerid), Skin[Player[playerid][Team]], Pos[0], Pos[1], Pos[2] - 0.4, Pos[3], 0, 0, 0, 0, 0, 0);
	SpawnPlayer(playerid);

	SetPlayerHealth(playerid, HP[0]);
	SetPlayerArmour(playerid, HP[1]);

	SetPlayerInterior(playerid, Int);
	SetPlayerVirtualWorld(playerid, VirtualWorld);

	for(new i = 0; i < 13; i++)
	{
	    GivePlayerWeapon(playerid, Weapons[i][0], Weapons[i][1]);
	}

	return 1;
}
/*
GetPlayerHitbox(playerid, &Float:X, &Float:Y, &Float:Z)
{
	#define rate 20
	new Float:Velocity[3];
	new Float:Position[3];
	GetPlayerVelocity(playerid, Velocity[0], Velocity[1], Velocity[2]);

	GetPlayerPos(playerid, Position[0], Position[1], Position[2]);

	Velocity[0] = Velocity[0] / 1000;
 	Velocity[1] = Velocity[1] / 1000;
  	Velocity[2] = Velocity[2] / 1000;


	new ping = GetPlayerPing(playerid);

	if(ping < 20) ping = 20;

	new Float:divisor = float(ping / rate);

	Velocity[0] = Velocity[0]  (ping / divisor)  ping * (rate / 3.5);
	Velocity[1] = Velocity[1]  (ping / divisor)  ping * (rate / 3.5);
	Velocity[2] = Velocity[2]  (ping / divisor)  ping * (rate / 3.5);


	X = floatadd(Position[0], Velocity[0]);
	Y = floatadd(Position[1], Velocity[1]);
	Z = floatadd(Position[2], Velocity[2]);

}
*/
LoadConfig()
{
    new iString[256];
    
	MainWeather = dini_Int(CONFIG_PATH, "ServerWeather");
	MainTime = dini_Int(CONFIG_PATH, "ServerTime");
    Skin[ATTACKER] = dini_Int(CONFIG_PATH, "AttackerSkin");
	Skin[DEFENDER] = dini_Int(CONFIG_PATH, "DefenderSkin");
	Skin[REFEREE] = dini_Int(CONFIG_PATH, "RefereeSkin");
	Skin[ATTACKER_SUB] = dini_Int(CONFIG_PATH, "AttackerSubSkin");
    Skin[DEFENDER_SUB] = dini_Int(CONFIG_PATH, "DefenderSubSkin");
	ConfigCPTime = dini_Int(CONFIG_PATH, "CPTime");
	ConfigRoundTime = dini_Int(CONFIG_PATH, "RoundTime");
	TotalRounds = dini_Int(CONFIG_PATH, "TotalRounds");
	
	iString = dini_Get(CONFIG_PATH, "WeaponLimits");
	sscanf(iString, "p<,>dddddd", WeaponLimit[0], WeaponLimit[1], WeaponLimit[2], WeaponLimit[3], WeaponLimit[4], WeaponLimit[5]);
	
	iString = dini_Get(CONFIG_PATH, "MainSpawn");
	sscanf(iString, "p<,>ffffd", MainSpawn[0], MainSpawn[1], MainSpawn[2], MainSpawn[3], MainInterior);

	printf("Config has been loaded.");
}

LoadBases()
{
	new iString[256], TotalBases;

	for(new i = 0; i < MAX_BASES; i++)
	{
		if(fexist(BaseFile(i)))
		{
		    BExist[i] = true;
			TotalBases++;

	    	iString = dini_Get(BaseFile(i), "AttSpawn");
		    sscanf(iString, "p<,>fff", AttackerSpawn[i][0], AttackerSpawn[i][1], AttackerSpawn[i][2]);

			iString = dini_Get(BaseFile(i), "DefSpawn");
			sscanf(iString, "p<,>fff", DefenderSpawn[i][0], DefenderSpawn[i][1], DefenderSpawn[i][2]);

			iString = dini_Get(BaseFile(i), "CPSpawn");
			sscanf(iString, "p<,>fff", CPSpawn[i][0], CPSpawn[i][1], CPSpawn[i][2]);

			iString = dini_Get(BaseFile(i), "Interior");
	    	BInterior[i] = strval(iString);

		    if(!dini_Isset(BaseFile(i), "Name"))
			{
				format(BName[i], 256, "No Name");
			}
			else
			{
				format(BName[i], 256, "%s", dini_Get(BaseFile(i), "Name"));
			}
			
			printf("Base ID: %d, CPSpawn: %.0f, %.0f, %.0f. Interior: %d, Name: %s", i, CPSpawn[i][0], CPSpawn[i][1], CPSpawn[i][2], BInterior[i], BName[i]);
		}
		else BExist[i] = false;
	}
	printf("Total Bases Loaded: %d", TotalBases);
	print("\n");
}

LoadArenas()
{
    new iString[256];

	TotalArenas = 0;
	
	for(new i = 0; i < MAX_ARENAS; i++)
	{
		if(fexist(ArenaFile(i)))
		{
		    AExist[i] = true;
			TotalArenas++;

	    	iString = dini_Get(ArenaFile(i),"AttSpawn");
		    sscanf(iString, "p<,>fff", AAttackerSpawn[i][0], AAttackerSpawn[i][1], AAttackerSpawn[i][2]);

			iString = dini_Get(ArenaFile(i),"DefSpawn");
			sscanf(iString, "p<,>fff", ADefenderSpawn[i][0], ADefenderSpawn[i][1], ADefenderSpawn[i][2]);

			iString = dini_Get(ArenaFile(i),"CenterCameraPos");
			sscanf(iString, "p<,>fff", ACPSpawn[i][0], ACPSpawn[i][1], ACPSpawn[i][2]);

			iString = dini_Get(ArenaFile(i),"ZMax");
			sscanf(iString, "p<,>ff", AMax[i][0], AMax[i][1]);

			iString = dini_Get(ArenaFile(i),"ZMin");
			sscanf(iString, "p<,>ff", AMin[i][0], AMin[i][1]);
			
			iString = dini_Get(ArenaFile(i),"Interior");
	    	AInterior[i] = strval(iString);

		    if(!dini_Isset(ArenaFile(i), "Name"))
			{
				format(AName[i], 256, "No Name");
			}
			else
			{
				format(AName[i], 256, "%s", dini_Get(ArenaFile(i), "Name"));
			}
			
			printf("Arena ID: %d, CenterCam: %.0f, %.0f, %.0f. Interior: %d, Name: %s", i, ACPSpawn[i][0], ACPSpawn[i][1], ACPSpawn[i][2], AInterior[i], AName[i]);
		}
		else AExist[i] = false;
	}
	printf("Loaded %d Arenas", TotalArenas);
	print("\n");
}

LoadDMs()
{
	new iString[256], TotalDMs;

	for(new i = 0; i < MAX_DMS; i++)
	{
	    if(fexist(DMFile(i)))
		{
	        DMExist[i] = true;
	        TotalDMs++;

	        iString = dini_Get(DMFile(i), "DMSpawn");
	        sscanf(iString, "p<,>ffff", DMSpawn[i][0], DMSpawn[i][1], DMSpawn[i][2], DMSpawn[i][3]);

			iString = dini_Get(DMFile(i), "DMInterior");
			DMInterior[i] = strval(iString);

			iString = dini_Get(DMFile(i), "Wep1");
			DMWeapons[i][0] = strval(iString);

			iString = dini_Get(DMFile(i), "Wep2");
			DMWeapons[i][1] = strval(iString);

			iString = dini_Get(DMFile(i), "Wep3");
			DMWeapons[i][2] = strval(iString);
		}
		else
		{
		    DMExist[i] = false;
		}
	}

	printf("Total DMs Loaded: %d", TotalDMs);
	print("\n");
}


LoadPlayerTextDraws(playerid)
{
    FPSPingPacket = CreatePlayerTextDraw(playerid, 510.000000, 1.000000, "_");
    PlayerTextDrawBackgroundColor(playerid, FPSPingPacket, 255);
    PlayerTextDrawFont(playerid, FPSPingPacket, 1);
    PlayerTextDrawLetterSize(playerid, FPSPingPacket, 0.189999, 0.899999);
    PlayerTextDrawColor(playerid, FPSPingPacket, -1);
    PlayerTextDrawSetOutline(playerid, FPSPingPacket, 0);
    PlayerTextDrawSetProportional(playerid, FPSPingPacket, 1);
    PlayerTextDrawSetShadow(playerid, FPSPingPacket, 1);
    PlayerTextDrawUseBox(playerid, FPSPingPacket, 1);
    PlayerTextDrawBoxColor(playerid, FPSPingPacket, 119);
    PlayerTextDrawTextSize(playerid, FPSPingPacket, 639.000000, -12.000000);
    
	KillsDeathsDamages = CreatePlayerTextDraw(playerid, 2.000000, 397.000000, "_");
	PlayerTextDrawBackgroundColor(playerid, KillsDeathsDamages, 255);
	PlayerTextDrawFont(playerid, KillsDeathsDamages, 1);
	PlayerTextDrawLetterSize(playerid, KillsDeathsDamages, 0.219999, 1.000000);
	PlayerTextDrawColor(playerid, KillsDeathsDamages, -1);
	PlayerTextDrawSetOutline(playerid, KillsDeathsDamages, 1);
	PlayerTextDrawSetProportional(playerid, KillsDeathsDamages, 1);
	PlayerTextDrawSetSelectable(playerid, KillsDeathsDamages, 0);
	
	HPsArmour = CreatePlayerTextDraw(playerid, 570.000000, 45.000000, "50~n~~n~~n~Fall Prot.");
	PlayerTextDrawBackgroundColor(playerid, HPsArmour, 255);
	PlayerTextDrawFont(playerid, HPsArmour, 1);
	PlayerTextDrawLetterSize(playerid, HPsArmour, 0.219999, 0.799998);
	PlayerTextDrawColor(playerid, HPsArmour, -1);
	PlayerTextDrawSetOutline(playerid, HPsArmour, 1);
	PlayerTextDrawSetProportional(playerid, HPsArmour, 1);
	PlayerTextDrawSetSelectable(playerid, HPsArmour, 0);
	
	DoingDamage[0][playerid] = CreatePlayerTextDraw(playerid,180.0,362.0,"_");
	PlayerTextDrawFont(playerid, DoingDamage[0][playerid], 1);
	PlayerTextDrawLetterSize(playerid, DoingDamage[0][playerid], 0.23000, 1.0);
	PlayerTextDrawBackgroundColor(playerid, DoingDamage[0][playerid],0x00000044);
	PlayerTextDrawColor(playerid, DoingDamage[0][playerid], 16727295);
	PlayerTextDrawSetProportional(playerid, DoingDamage[0][playerid], 1);
	PlayerTextDrawSetOutline(playerid, DoingDamage[0][playerid],1);
    PlayerTextDrawSetShadow(playerid, DoingDamage[0][playerid],0);

	DoingDamage[1][playerid] = CreatePlayerTextDraw(playerid,180.0,372.0,"_");
	PlayerTextDrawFont(playerid, DoingDamage[1][playerid], 1);
	PlayerTextDrawLetterSize(playerid, DoingDamage[1][playerid], 0.23000, 1.0);
	PlayerTextDrawBackgroundColor(playerid, DoingDamage[1][playerid],0x00000044);
	PlayerTextDrawColor(playerid, DoingDamage[1][playerid], 16727295);
	PlayerTextDrawSetProportional(playerid, DoingDamage[1][playerid], 1);
	PlayerTextDrawSetOutline(playerid, DoingDamage[1][playerid],1);
    PlayerTextDrawSetShadow(playerid, DoingDamage[1][playerid],0);

	DoingDamage[2][playerid] = CreatePlayerTextDraw(playerid,180.0,382.0,"_");
	PlayerTextDrawFont(playerid, DoingDamage[2][playerid], 1);
	PlayerTextDrawLetterSize(playerid, DoingDamage[2][playerid], 0.23000, 1.0);
	PlayerTextDrawBackgroundColor(playerid, DoingDamage[2][playerid],0x00000044);
	PlayerTextDrawColor(playerid, DoingDamage[2][playerid], 16727295);
	PlayerTextDrawSetProportional(playerid, DoingDamage[2][playerid], 1);
	PlayerTextDrawSetOutline(playerid, DoingDamage[2][playerid],1);
    PlayerTextDrawSetShadow(playerid, DoingDamage[2][playerid],0);

	GettingDamaged[0][playerid] = CreatePlayerTextDraw(playerid,400.0,362.0,"_");
	PlayerTextDrawFont(playerid, GettingDamaged[0][playerid], 1);
	PlayerTextDrawLetterSize(playerid, GettingDamaged[0][playerid], 0.23000, 1.0);
	PlayerTextDrawBackgroundColor(playerid, GettingDamaged[0][playerid],0x00000044);
	PlayerTextDrawColor(playerid, GettingDamaged[0][playerid], 16727295);
	PlayerTextDrawSetProportional(playerid, GettingDamaged[0][playerid], 1);
	PlayerTextDrawSetOutline(playerid, GettingDamaged[0][playerid],1);
	PlayerTextDrawSetShadow(playerid, GettingDamaged[0][playerid],0);

	GettingDamaged[1][playerid] = CreatePlayerTextDraw(playerid,400.0,372.0,"_");
	PlayerTextDrawFont(playerid, GettingDamaged[1][playerid], 1);
	PlayerTextDrawLetterSize(playerid, GettingDamaged[1][playerid], 0.23000, 1.0);
	PlayerTextDrawBackgroundColor(playerid, GettingDamaged[1][playerid],0x00000044);
	PlayerTextDrawColor(playerid, GettingDamaged[1][playerid], 16727295);
	PlayerTextDrawSetProportional(playerid, GettingDamaged[1][playerid], 1);
	PlayerTextDrawSetOutline(playerid, GettingDamaged[1][playerid],1);
	PlayerTextDrawSetShadow(playerid, GettingDamaged[1][playerid],0);

	GettingDamaged[2][playerid] = CreatePlayerTextDraw(playerid,400.0,382.0,"_");
	PlayerTextDrawFont(playerid, GettingDamaged[2][playerid], 1);
	PlayerTextDrawLetterSize(playerid, GettingDamaged[2][playerid], 0.23000, 1.0);
	PlayerTextDrawBackgroundColor(playerid, GettingDamaged[2][playerid],0x00000044);
	PlayerTextDrawColor(playerid, GettingDamaged[2][playerid], 16727295);
	PlayerTextDrawSetProportional(playerid, GettingDamaged[2][playerid], 1);
	PlayerTextDrawSetOutline(playerid, GettingDamaged[2][playerid],1);
	PlayerTextDrawSetShadow(playerid, GettingDamaged[2][playerid],0);
}

LoadTextDraws()
{
	WarStats = TextDrawCreate(559.000000, 104.000000, "~r~Alpha ~w~(~r~6~w~) vs ~b~Beta ~w~(~b~3~w~)~n~Round 1/9");
	TextDrawAlignment(WarStats, 2);
	TextDrawBackgroundColor(WarStats, 255);
	TextDrawFont(WarStats, 1);
	TextDrawLetterSize(WarStats, 0.269999, 1.700000);
	TextDrawColor(WarStats, -1);
	TextDrawSetOutline(WarStats, 1);
	TextDrawSetProportional(WarStats, 1);
	TextDrawSetSelectable(WarStats, 0);

	RoundStats[0] = TextDrawCreate(310.000000, 429.000000, "_");
	TextDrawAlignment(RoundStats[0], 2);
	TextDrawBackgroundColor(RoundStats[0], 255);
	TextDrawFont(RoundStats[0], 1);
	TextDrawLetterSize(RoundStats[0], 0.620000, 2.000000);
	TextDrawColor(RoundStats[0], -222);
	TextDrawSetOutline(RoundStats[0], 0);
	TextDrawSetProportional(RoundStats[0], 1);
	TextDrawSetShadow(RoundStats[0], 1);
	TextDrawUseBox(RoundStats[0], 1);
	TextDrawBoxColor(RoundStats[0], 102);
	TextDrawTextSize(RoundStats[0], 128.000000, -688.000000);
	TextDrawSetSelectable(RoundStats[0], 0);

	RoundStats[1] = TextDrawCreate(309.000000, 431.000000, "_");
	TextDrawAlignment(RoundStats[1], 2);
	TextDrawBackgroundColor(RoundStats[1], 255);
	TextDrawFont(RoundStats[1], 1);
	TextDrawLetterSize(RoundStats[1], 0.289999, 1.299999);
	TextDrawColor(RoundStats[1], -1);
	TextDrawSetOutline(RoundStats[1], 0);
	TextDrawSetProportional(RoundStats[1], 1);
	TextDrawSetShadow(RoundStats[1], 1);
	TextDrawSetSelectable(RoundStats[1], 0);

	Intro[0] = TextDrawCreate(318.000000, 131.000000, "_");
	TextDrawAlignment(Intro[0], 2);
	TextDrawBackgroundColor(Intro[0], 255);
	TextDrawFont(Intro[0], 0);
	TextDrawLetterSize(Intro[0], 0.570000, 22.899999);
	TextDrawColor(Intro[0], -1);
	TextDrawSetOutline(Intro[0], 0);
	TextDrawSetProportional(Intro[0], 1);
	TextDrawSetShadow(Intro[0], 1);
	TextDrawUseBox(Intro[0], 1);
	TextDrawBoxColor(Intro[0], 51);
	TextDrawTextSize(Intro[0], 240.000000, 281.000000);
	TextDrawSetSelectable(Intro[0], 0);

	Intro[1] = TextDrawCreate(318.000000, 128.000000, "_");
	TextDrawAlignment(Intro[1], 2);
	TextDrawBackgroundColor(Intro[1], 255);
	TextDrawFont(Intro[1], 0);
	TextDrawLetterSize(Intro[1], 0.639999, 23.600002);
	TextDrawColor(Intro[1], -1);
	TextDrawSetOutline(Intro[1], 0);
	TextDrawSetProportional(Intro[1], 1);
	TextDrawSetShadow(Intro[1], 1);
	TextDrawUseBox(Intro[1], 1);
	TextDrawBoxColor(Intro[1], 17);
	TextDrawTextSize(Intro[1], 241.000000, 286.000000);
	TextDrawSetSelectable(Intro[1], 0);

	Intro[2] = TextDrawCreate(162.000000, 130.000000, "_");
	TextDrawBackgroundColor(Intro[2], 0);
	TextDrawFont(Intro[2], 5);
	TextDrawLetterSize(Intro[2], 0.710000, 16.200000);
	TextDrawColor(Intro[2], -1);
	TextDrawSetOutline(Intro[2], 1);
	TextDrawSetProportional(Intro[2], 1);
	TextDrawUseBox(Intro[2], 1);
	TextDrawBoxColor(Intro[2], -256);
	TextDrawTextSize(Intro[2], 124.000000, 151.000000);
	TextDrawSetPreviewModel(Intro[2], Skin[ATTACKER]);
	TextDrawSetPreviewRot(Intro[2], 0.400000, 0.400000, 0.000000, 1.000000);
	TextDrawSetSelectable(Intro[2], 1);

	Intro[3] = TextDrawCreate(253.000000, 130.000000, "_");
	TextDrawBackgroundColor(Intro[3], 0);
	TextDrawFont(Intro[3], 5);
	TextDrawLetterSize(Intro[3], 0.710000, 16.200000);
	TextDrawColor(Intro[3], -1);
	TextDrawSetOutline(Intro[3], 1);
	TextDrawSetProportional(Intro[3], 1);
	TextDrawUseBox(Intro[3], 1);
	TextDrawBoxColor(Intro[3], -256);
	TextDrawTextSize(Intro[3], 124.000000, 151.000000);
	TextDrawSetPreviewModel(Intro[3], Skin[REFEREE]);
	TextDrawSetPreviewRot(Intro[3], 0.400000, 0.400000, 0.000000, 1.000000);
	TextDrawSetSelectable(Intro[3], 1);

	Intro[4] = TextDrawCreate(344.000000, 130.000000, "_");
	TextDrawBackgroundColor(Intro[4], 0);
	TextDrawFont(Intro[4], 5);
	TextDrawLetterSize(Intro[4], 0.710000, 16.200000);
	TextDrawColor(Intro[4], -1);
	TextDrawSetOutline(Intro[4], 1);
	TextDrawSetProportional(Intro[4], 1);
	TextDrawUseBox(Intro[4], 1);
	TextDrawBoxColor(Intro[4], -256);
	TextDrawTextSize(Intro[4], 124.000000, 151.000000);
	TextDrawSetPreviewModel(Intro[4], Skin[DEFENDER]);
	TextDrawSetPreviewRot(Intro[4], 0.400000, 0.400000, 0.000000, 1.000000);
	TextDrawSetSelectable(Intro[4], 1);

	Intro[5] = TextDrawCreate(190.000000, 276.000000, ".");
	TextDrawBackgroundColor(Intro[5], 255);
	TextDrawFont(Intro[5], 1);
	TextDrawLetterSize(Intro[5], 25.000000, 0.500000);
	TextDrawColor(Intro[5], -1);
	TextDrawSetOutline(Intro[5], 0);
	TextDrawSetProportional(Intro[5], 1);
	TextDrawSetShadow(Intro[5], 1);
	TextDrawSetSelectable(Intro[5], 0);

	Intro[6] = TextDrawCreate(190.000000, 304.000000, ".");
	TextDrawBackgroundColor(Intro[6], 255);
	TextDrawFont(Intro[6], 1);
	TextDrawLetterSize(Intro[6], 25.000000, 0.500000);
	TextDrawColor(Intro[6], -1);
	TextDrawSetOutline(Intro[6], 0);
	TextDrawSetProportional(Intro[6], 1);
	TextDrawSetShadow(Intro[6], 1);
	TextDrawSetSelectable(Intro[6], 0);

	Intro[7] = TextDrawCreate(221.000000, 286.000000, "SELECT YOUR TEAM");
	TextDrawBackgroundColor(Intro[7], 255);
	TextDrawFont(Intro[7], 3);
	TextDrawLetterSize(Intro[7], 0.600000, 1.799999);
	TextDrawColor(Intro[7], -1);
	TextDrawSetOutline(Intro[7], 1);
	TextDrawSetProportional(Intro[7], 1);
	TextDrawSetSelectable(Intro[7], 0);

    EndRound_Box = TextDrawCreate(316.000000, 146.000000, "_");
	TextDrawAlignment(EndRound_Box, 2);
	TextDrawBackgroundColor(EndRound_Box, 255);
	TextDrawFont(EndRound_Box, 1);
	TextDrawLetterSize(EndRound_Box, 0.500000, 24.000000);
	TextDrawColor(EndRound_Box, -1);
	TextDrawSetOutline(EndRound_Box, 0);
	TextDrawSetProportional(EndRound_Box, 1);
	TextDrawSetShadow(EndRound_Box, 1);
	TextDrawUseBox(EndRound_Box, 1);
	TextDrawBoxColor(EndRound_Box, 51);
	TextDrawTextSize(EndRound_Box, 43.000000, 332.000000);
	TextDrawSetSelectable(EndRound_Box, 0);

	EndRound_BoxA = TextDrawCreate(234.000000, 149.000000, "_");
	TextDrawAlignment(EndRound_BoxA, 2);
	TextDrawBackgroundColor(EndRound_BoxA, 255);
	TextDrawFont(EndRound_BoxA, 1);
	TextDrawLetterSize(EndRound_BoxA, 0.500000, 23.299997);
	TextDrawColor(EndRound_BoxA, -1);
	TextDrawSetOutline(EndRound_BoxA, 0);
	TextDrawSetProportional(EndRound_BoxA, 1);
	TextDrawSetShadow(EndRound_BoxA, 1);
	TextDrawUseBox(EndRound_BoxA, 1);
	TextDrawBoxColor(EndRound_BoxA, -12303275);
	TextDrawTextSize(EndRound_BoxA, 42.000000, 163.000000);
	TextDrawSetSelectable(EndRound_BoxA, 0);

	EndRound_BoxD = TextDrawCreate(401.000000, 149.000000, "_");
	TextDrawAlignment(EndRound_BoxD, 2);
	TextDrawBackgroundColor(EndRound_BoxD, 255);
	TextDrawFont(EndRound_BoxD, 1);
	TextDrawLetterSize(EndRound_BoxD, 0.500000, 23.299997);
	TextDrawColor(EndRound_BoxD, -1);
	TextDrawSetOutline(EndRound_BoxD, 0);
	TextDrawSetProportional(EndRound_BoxD, 1);
	TextDrawSetShadow(EndRound_BoxD, 1);
	TextDrawUseBox(EndRound_BoxD, 1);
	TextDrawBoxColor(EndRound_BoxD, 1145372501);
	TextDrawTextSize(EndRound_BoxD, 43.000000, 158.000000);
	TextDrawSetSelectable(EndRound_BoxD, 0);

	EndRound_NameA = TextDrawCreate(187.000000, 140.000000, "Arck");
	TextDrawBackgroundColor(EndRound_NameA, 255);
	TextDrawFont(EndRound_NameA, 3);
	TextDrawLetterSize(EndRound_NameA, 0.500000, 1.000000);
	TextDrawColor(EndRound_NameA, -1);
	TextDrawSetOutline(EndRound_NameA, 1);
	TextDrawSetProportional(EndRound_NameA, 1);
	TextDrawSetSelectable(EndRound_NameA, 0);

	EndRound_NameD = TextDrawCreate(447.000000, 140.000000, "heagab");
	TextDrawAlignment(EndRound_NameD, 3);
	TextDrawBackgroundColor(EndRound_NameD, 255);
	TextDrawFont(EndRound_NameD, 3);
	TextDrawLetterSize(EndRound_NameD, 0.500000, 1.000000);
	TextDrawColor(EndRound_NameD, -1);
	TextDrawSetOutline(EndRound_NameD, 1);
	TextDrawSetProportional(EndRound_NameD, 1);
	TextDrawSetSelectable(EndRound_NameD, 0);

	EndRound_ColTextA = TextDrawCreate(154.000000, 151.000000, "Name                 Kills   Deaths   Damages");
	TextDrawBackgroundColor(EndRound_ColTextA, 255);
	TextDrawFont(EndRound_ColTextA, 1);
	TextDrawLetterSize(EndRound_ColTextA, 0.200000, 1.000000);
	TextDrawColor(EndRound_ColTextA, -1);
	TextDrawSetOutline(EndRound_ColTextA, 1);
	TextDrawSetProportional(EndRound_ColTextA, 1);
	TextDrawSetSelectable(EndRound_ColTextA, 0);

	EndRound_ColTextD = TextDrawCreate(324.000000, 151.000000, "Name               Kills   Deaths   Damages");
	TextDrawBackgroundColor(EndRound_ColTextD, 255);
	TextDrawFont(EndRound_ColTextD, 1);
	TextDrawLetterSize(EndRound_ColTextD, 0.200000, 1.000000);
	TextDrawColor(EndRound_ColTextD, -1);
	TextDrawSetOutline(EndRound_ColTextD, 1);
	TextDrawSetProportional(EndRound_ColTextD, 1);
	TextDrawSetSelectable(EndRound_ColTextD, 0);

	EndRound_NamesA = TextDrawCreate(155.000000, 163.000000, "_");
	TextDrawBackgroundColor(EndRound_NamesA, 255);
	TextDrawFont(EndRound_NamesA, 1);
	TextDrawLetterSize(EndRound_NamesA, 0.180000, 0.899999);
	TextDrawColor(EndRound_NamesA, -1);
	TextDrawSetOutline(EndRound_NamesA, 1);
	TextDrawSetProportional(EndRound_NamesA, 1);
	TextDrawSetSelectable(EndRound_NamesA, 0);

	EndRound_NamesD = TextDrawCreate(325.000000, 163.000000, "_");
	TextDrawBackgroundColor(EndRound_NamesD, 255);
	TextDrawFont(EndRound_NamesD, 1);
	TextDrawLetterSize(EndRound_NamesD, 0.180000, 0.899999);
	TextDrawColor(EndRound_NamesD, -1);
	TextDrawSetOutline(EndRound_NamesD, 1);
	TextDrawSetProportional(EndRound_NamesD, 1);
	TextDrawSetSelectable(EndRound_NamesD, 0);

	EndRound_KillA = TextDrawCreate(232.000000, 165.000000, "8~n~5~n~3~n~10~n~0~n~2");
	TextDrawBackgroundColor(EndRound_KillA, 255);
	TextDrawFont(EndRound_KillA, 1);
	TextDrawLetterSize(EndRound_KillA, 0.180000, 0.899999);
	TextDrawColor(EndRound_KillA, -1);
	TextDrawSetOutline(EndRound_KillA, 1);
	TextDrawSetProportional(EndRound_KillA, 1);
	TextDrawSetSelectable(EndRound_KillA, 0);

	EndRound_KillD = TextDrawCreate(395.000000, 165.000000, "8~n~5~n~3~n~10~n~0~n~2");
	TextDrawBackgroundColor(EndRound_KillD, 255);
	TextDrawFont(EndRound_KillD, 1);
	TextDrawLetterSize(EndRound_KillD, 0.180000, 0.899999);
	TextDrawColor(EndRound_KillD, -1);
	TextDrawSetOutline(EndRound_KillD, 1);
	TextDrawSetProportional(EndRound_KillD, 1);
	TextDrawSetSelectable(EndRound_KillD, 0);

	EndRound_DeathsA = TextDrawCreate(260.000000, 165.000000, "1~n~4~n~6~n~9~n~9~n~1");
	TextDrawBackgroundColor(EndRound_DeathsA, 255);
	TextDrawFont(EndRound_DeathsA, 1);
	TextDrawLetterSize(EndRound_DeathsA, 0.180000, 0.899999);
	TextDrawColor(EndRound_DeathsA, -1);
	TextDrawSetOutline(EndRound_DeathsA, 1);
	TextDrawSetProportional(EndRound_DeathsA, 1);
	TextDrawSetSelectable(EndRound_DeathsA, 0);

	EndRound_DeathsD = TextDrawCreate(425.000000, 165.000000, "1~n~4~n~6~n~9~n~9~n~1");
	TextDrawBackgroundColor(EndRound_DeathsD, 255);
	TextDrawFont(EndRound_DeathsD, 1);
	TextDrawLetterSize(EndRound_DeathsD, 0.180000, 0.899999);
	TextDrawColor(EndRound_DeathsD, -1);
	TextDrawSetOutline(EndRound_DeathsD, 1);
	TextDrawSetProportional(EndRound_DeathsD, 1);
	TextDrawSetSelectable(EndRound_DeathsD, 0);

	EndRound_DamagesA = TextDrawCreate(291.000000, 165.000000, "500~n~1200~n~1200~n~1200~n~1200~n~1200~n~");
	TextDrawBackgroundColor(EndRound_DamagesA, 255);
	TextDrawFont(EndRound_DamagesA, 1);
	TextDrawLetterSize(EndRound_DamagesA, 0.180000, 0.899999);
	TextDrawColor(EndRound_DamagesA, -1);
	TextDrawSetOutline(EndRound_DamagesA, 1);
	TextDrawSetProportional(EndRound_DamagesA, 1);
	TextDrawSetSelectable(EndRound_DamagesA, 0);

	EndRound_DamagesD = TextDrawCreate(454.000000, 165.000000, "500~n~1200~n~1200~n~1200~n~1200~n~1200~n~");
	TextDrawBackgroundColor(EndRound_DamagesD, 255);
	TextDrawFont(EndRound_DamagesD, 1);
	TextDrawLetterSize(EndRound_DamagesD, 0.180000, 0.899999);
	TextDrawColor(EndRound_DamagesD, -1);
	TextDrawSetOutline(EndRound_DamagesD, 1);
	TextDrawSetProportional(EndRound_DamagesD, 1);
	TextDrawSetSelectable(EndRound_DamagesD, 0);

	EndRound_BoxMost = TextDrawCreate(319.500000, 366.500000, "_");
	TextDrawAlignment(EndRound_BoxMost, 2);
	TextDrawBackgroundColor(EndRound_BoxMost, 255);
	TextDrawFont(EndRound_BoxMost, 1);
	TextDrawLetterSize(EndRound_BoxMost, 0.500000, 2.300000);
	TextDrawColor(EndRound_BoxMost, -1);
	TextDrawSetOutline(EndRound_BoxMost, 0);
	TextDrawSetProportional(EndRound_BoxMost, 1);
	TextDrawSetShadow(EndRound_BoxMost, 1);
	TextDrawUseBox(EndRound_BoxMost, 1);
	TextDrawBoxColor(EndRound_BoxMost, 51);
	TextDrawTextSize(EndRound_BoxMost, 0.000000, 251.000000);
	TextDrawSetSelectable(EndRound_BoxMost, 0);

	EndRound_TDMost = TextDrawCreate(321.000000, 369.000000, "Base ID: 44___Most Damages: None___Most Kills: None");
	TextDrawAlignment(EndRound_TDMost, 2);
	TextDrawBackgroundColor(EndRound_TDMost, 255);
	TextDrawFont(EndRound_TDMost, 1);
	TextDrawLetterSize(EndRound_TDMost, 0.190000, 1.299999);
	TextDrawColor(EndRound_TDMost, -1);
	TextDrawSetOutline(EndRound_TDMost, 1);
	TextDrawSetProportional(EndRound_TDMost, 1);
	TextDrawSetSelectable(EndRound_TDMost, 0);

	EndRound_BoxHide = TextDrawCreate(317.500000, 129.500000, "_");
	TextDrawAlignment(EndRound_BoxHide, 2);
	TextDrawBackgroundColor(EndRound_BoxHide, 255);
	TextDrawFont(EndRound_BoxHide, 1);
	TextDrawLetterSize(EndRound_BoxHide, 0.500000, 1.299999);
	TextDrawColor(EndRound_BoxHide, -1);
	TextDrawSetOutline(EndRound_BoxHide, 0);
	TextDrawSetProportional(EndRound_BoxHide, 1);
	TextDrawSetShadow(EndRound_BoxHide, 1);
	TextDrawUseBox(EndRound_BoxHide, 1);
	TextDrawBoxColor(EndRound_BoxHide, 51);
	TextDrawTextSize(EndRound_BoxHide, 0.000000, 61.000000);
	TextDrawSetSelectable(EndRound_BoxHide, 0);

	EndRound_TDHide = TextDrawCreate(287.000000, 129.000000, "hide textdraws");
	TextDrawBackgroundColor(EndRound_TDHide, 255);
	TextDrawFont(EndRound_TDHide, 2);
	TextDrawLetterSize(EndRound_TDHide, 0.170000, 1.700000);
	TextDrawColor(EndRound_TDHide, -1);
	TextDrawSetOutline(EndRound_TDHide, 1);
	TextDrawSetProportional(EndRound_TDHide, 1);
	TextDrawSetSelectable(EndRound_TDHide, 1);

}

/* Functions with stocks */

stock IsPlayerInArea(playerid, Float:MinX, Float:MaxX, Float:MinY, Float:MaxY)
{
    new Float:Pos[3];
    GetPlayerPos(playerid, Pos[0], Pos[1], Pos[2]);
    
    if (Pos[0] > MinX && Pos[0] < MaxX && Pos[1] > MinY && Pos[1] < MaxY)
		return 1;
    
    return 0;
}


stock PauseRound()
{
	foreach(new i : Player)
	{
	    if(Player[i][Playing] == true)
	    {
	        TogglePlayerControllable(i, false);
	    }
	}
	
	RoundPaused = true;
}

stock SwapTeams()
{
	foreach(new i : Player)
	{
	    if(Player[i][Team] == ATTACKER) Player[i][Team] = DEFENDER;
		else if(Player[i][Team] == ATTACKER_SUB) Player[i][Team] = DEFENDER_SUB;
		else if(Player[i][Team] == DEFENDER) Player[i][Team] = ATTACKER;
        else if(Player[i][Team] == DEFENDER_SUB) Player[i][Team] = ATTACKER_SUB;
        
        ColorFix(i);
		SetPlayerSkin(i, Skin[Player[i][Team]]);

		ClearAnimations(i);
	}
	
	new TempScore;
	TempScore = TeamScore[ATTACKER];
	TeamScore[ATTACKER] = TeamScore[DEFENDER];
	TeamScore[DEFENDER] = TempScore;

	new TempName[24];
	TempName = TeamName[ATTACKER];
	TeamName[ATTACKER] = TeamName[DEFENDER];
	TeamName[DEFENDER] = TempName;
	TempName = TeamName[ATTACKER_SUB];
	TeamName[ATTACKER_SUB] = TeamName[DEFENDER_SUB];
	TeamName[DEFENDER_SUB] = TempName;
	
	format(fWarStats, sizeof(fWarStats), "~r~%s ~w~(~r~%d~w~) vs ~b~%s ~w~(~b~%d~w~)~n~Round %d/%d", TeamName[ATTACKER], TeamScore[ATTACKER], TeamName[DEFENDER], TeamScore[DEFENDER], CurrentRound, TotalRounds);
	TextDrawSetString(WarStats, fWarStats);
	
	SendClientMessageToAllf(-1, "Teams are swapped. Attackers are now defenders and viceversa.");
}

stock GetClosestPlayer(playerid)
{
	new Float:dist = 1000.0;
    new targetid = INVALID_PLAYER_ID;
    new Float:x1,Float:y1,Float:z1;
    new Float:x2,Float:y2,Float:z2;
    new Float:tmpdis;

    GetPlayerPos(playerid,x1,y1,z1);

    for(new i = 0;i < MAX_PLAYERS; i++)
    {
        if(i == playerid) continue;

        GetPlayerPos(i,x2,y2,z2);
        tmpdis = floatsqroot(floatpower(floatabs(floatsub(x2,x1)),2)+floatpower(floatabs(floatsub(y2,y1)),2)+floatpower(floatabs(floatsub(z2,z1)),2));

		if(tmpdis < dist)
        {
            dist = tmpdis;
            targetid = i;
        }
    }
    return targetid;
}

stock RadarFix()
{
    foreach(new i : Player)
	{
		foreach(new x : Player)
		{
			if(Player[i][Playing] == true && Player[x][Playing] == true)
			{
		        if(Player[i][Team] != Player[x][Team])
				{
					SetPlayerMarkerForPlayer(x, i, GetPlayerColor(i) & 0xFFFFFF00);
	            }
				else
				{
					SetPlayerMarkerForPlayer(x, i, GetPlayerColor(i) | 0x00000055);
				}
			}
			else if(Player[i][Playing] == true && Player[x][Playing] == false)
			{
				if(Player[i][Team] != Player[x][Team])
				{
					SetPlayerMarkerForPlayer(x, i, GetPlayerColor(i) & 0xFFFFFF00);
	            }
				else
				{
					SetPlayerMarkerForPlayer(x, i, GetPlayerColor(i) | 0x00000055);
				}
			}
		}
    }
    return 1;
}

stock ColorFix(playerid)
{
	if(Player[playerid][Playing] == true)
	{
	    switch(Player[playerid][Team])
		{
	        case ATTACKER: SetPlayerColor(playerid, ATTACKER_PLAYING);
	        case DEFENDER: SetPlayerColor(playerid, DEFENDER_PLAYING);
	        case REFEREE: SetPlayerColor(playerid, REFEREE_COLOR);
		}
	}
	else
	{
	    switch(Player[playerid][Team])
		{
	        case ATTACKER: SetPlayerColor(playerid, ATTACKER_NOT_PLAYING);
	        case DEFENDER: SetPlayerColor(playerid, DEFENDER_NOT_PLAYING);
	        case REFEREE: SetPlayerColor(playerid, REFEREE_COLOR);
	        case ATTACKER_SUB: SetPlayerColor(playerid, ATTACKER_SUB_COLOR);
	        case DEFENDER_SUB: SetPlayerColor(playerid, DEFENDER_SUB_COLOR);
		}
	}
}

stock ClearChat()
{
	for(new i = 0; i <= 10; i++)
	{
	    SendClientMessageToAll(-1, " ");
	}
}

stock GetVehicleModelID(vehiclename[])
{
	for(new i = 0; i < 211; i++)
	{
		if(strfind(aVehicleNames[i], vehiclename, true) != -1) return i + 400;
    }
	return -1;
}

stock Float:GetDistanceBetweenPlayers(playerid, toplayerid)
{
	if(!IsPlayerConnected(playerid) || !IsPlayerConnected(toplayerid)) return -1.00;

	new Float:Pos[2][3];
	GetPlayerPos(playerid, Pos[0][0], Pos[0][1], Pos[0][2]);
	GetPlayerPos(toplayerid, Pos[1][0], Pos[1][1], Pos[1][2]);

	return floatsqroot(floatpower(floatabs(floatsub(Pos[1][0], Pos[0][0])), 2) + floatpower(floatabs(floatsub(Pos[1][1], Pos[0][1])),2) + floatpower(floatabs(floatsub(Pos[1][2], Pos[0][2])),2));
}

stock ClearKillList()
{
	for(new i = 0; i < 5; i++)
	{
	    SendDeathMessage(255, 50, 255);
	}
}

stock DestroyAllVehicles()
{
	for(new i = 0; i < MAX_VEHICLES; i++)
	{
	    DestroyVehicle(i);
	}
}

stock IsNumeric(string[])
{
	for (new i = 0, j = strlen(string); i < j; i++)
	{
		if(string[i] > '9' || string[i] < '0') return 0;
	}
	return 1;
}

stock Float:GetPlayerPacketLoss(playerid)
{
    new stats[401], stringstats[70];
    GetPlayerNetworkStats(playerid, stats, sizeof(stats));
    new len = strfind(stats, "Packetloss: ");
    new Float:packetloss = 0.0;
    if(len != -1)
	{
		strmid(stringstats, stats, len, strlen(stats));
        new len2 = strfind(stringstats, "%");
        if(len != -1)
		{
            strdel(stats, 0, strlen(stats));
            strmid(stats, stringstats, len2 - 3, len2);
            packetloss = floatstr(stats);
		}
    }
    return packetloss;
}


stock GetPlayerFPS(playerid)
{
	new drunk2 = GetPlayerDrunkLevel(playerid);
	
	if(drunk2 < 100)
	{
	    SetPlayerDrunkLevel(playerid, 2000);
	}
	else
	{
		if(Player[playerid][DLlast] != drunk2)
		{
  			new fps = Player[playerid][DLlast] - drunk2;
  			
	        if((fps > 0) && (fps < 200))

			Player[playerid][FPS] = fps;
			Player[playerid][DLlast] = drunk2;
		}
	}
}

stock ArenaFile(arenaid)
{
	new iString[128];
	format(iString, sizeof(iString), ARENA_PATH, arenaid);
	return iString;
}


stock BaseFile(baseid)
{
	new iString[128];
	format(iString, sizeof(iString), BASE_PATH, baseid);
	return iString;
}

DMFile(dmid)
{
	new iString[128];
	format(iString, sizeof(iString), DM_PATH, dmid);
	return iString;
}

stock PlayerPath(playerid)
{
	new iStr[128];
	format(iStr, sizeof(iStr), USER_PATH, Player[playerid][Name]);
	return iStr;
}

