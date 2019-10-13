/*
COMPILE OPTIONS
*/

#pragma semicolon 1
#pragma newdecls required

/*
INCLUDES
*/

#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <morecolors>
#include <lololib>

/*
PLUGIN INFO
*/

public Plugin myinfo = 
{
	name			= "Point distance",
	author			= "Flexlolo",
	description		= "Show distance between two points",
	version			= "1.0.0",
	url				= "github.com/Flexlolo/"
}

/*
GLOBAL VARIABLES
*/

// Chat
#define CHAT_DIST "\x01[PD]"
#define CHAT_TEXT "\x01"
#define CHAT_VALUE "\x01"

// Beam
#define BEAM_DRAW_INTERVAL 		0.1

#define BEAM_HALO 				"materials/sprites/halo01.vmt"
#define BEAM_TEXTURE_VMT 		"materials/vgui/white.vmt"
#define BEAM_TEXTURE_VTF 		"materials/vgui/white.vtf"

#define SNAP_HALO 				"materials/sprites/halo01.vmt"
#define SNAP_TEXTURE_VMT 		"materials/vgui/white.vmt"
#define SNAP_TEXTURE_VTF 		"materials/vgui/white.vtf"

int g_iBeam_Halo;
int g_iBeam_Model;

int	g_iSnap_Halo;
int g_iSnap_Model;

// Client
bool g_bPoints[MAXPLAYERS + 1][2];
float g_fPoints[MAXPLAYERS + 1][2][3];

bool g_bSnap[MAXPLAYERS + 1];
int g_iSnap[MAXPLAYERS + 1];
int g_iSnap_Steps[] = {1, 2, 4, 8, 16, 32, 64};

int g_bMenu[MAXPLAYERS + 1];

/*
NATIVES AND FORWARDS
*/

public void OnPluginStart()
{
	RegConsoleCmd("sm_dist", 		Command_Distance, "Point distance");
	RegConsoleCmd("sm_distance", 	Command_Distance, "Point distance");
}

public void OnClientPutInServer(int client)
{
	Point_Reset(client, 1);
	Point_Reset(client, 2);

	g_bSnap[client] = true;
	g_iSnap[client] = 0;

	g_bMenu[client] = false;
}

/*
COMMANDS
*/


public Action Command_Distance(int client, int args)
{
	if (lolo_IsClientValid(client))
	{
		if (!args)
		{
			Menu_Distance(client);
		}
	}

	return Plugin_Handled;
}

public void Menu_Distance(int client)
{
	g_bMenu[client] = false;

	if (!lolo_IsClientValid(client))
	{
		return;
	}

	Menu menu = new Menu(Menu_Distance_Handler, MenuAction_Select | MenuAction_DisplayItem | MenuAction_Cancel);
	menu.SetTitle("Point distance measure:\n \n");

	menu.AddItem("1", "1");
	menu.AddItem("2", "2");

	if (g_bPoints[client][0] && g_bPoints[client][1])
	{
		menu.AddItem("Print", "Print");
	}
	else
	{
		menu.AddItem("Print", "Print", ITEMDRAW_DISABLED);
	}

	if (g_bPoints[client][0] || g_bPoints[client][1])
	{
		menu.AddItem("Reset", "Reset");
	}
	else
	{
		menu.AddItem("Reset", "Reset", ITEMDRAW_DISABLED);
	}


	menu.AddItem("Snap", "Snap");
	menu.AddItem("Snap_Step", "Snap_Step");

	g_bMenu[client] = true;

	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Distance_Handler(Handle menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			int client = param1;

			char item[64];
			GetMenuItem(menu, param2, item, sizeof(item));
			
			if (StrEqual(item, "1"))
			{
				Point_Set(client, 1);
			}
			else if (StrEqual(item, "Reset"))
			{
				Point_Reset(client, 1);
				Point_Reset(client, 2);
			}
			else if (StrEqual(item, "2"))
			{
				Point_Set(client, 2);
			}
			else if (StrEqual(item, "Print"))
			{
				Distance_Print(client);
			}
			else if (StrEqual(item, "Snap"))
			{
				g_bSnap[client] = !g_bSnap[client];
			}
			else if (StrEqual(item, "Snap_Step"))
			{
				if (++g_iSnap[client] >= sizeof(g_iSnap_Steps))
				{
					g_iSnap[client] = 0;
				}
			}

			Menu_Distance(client);
		}

		case MenuAction_Cancel:
		{
			int client = param1;
			g_bMenu[client] = false;
		}

		case MenuAction_DisplayItem:
		{
			int client = param1;

			char item[64];
			GetMenuItem(menu, param2, item, sizeof(item));

			char translation[64];

			if (StrEqual(item, "1"))
			{
				if (g_bPoints[client][0])
				{
					Format(translation, sizeof(translation), "Update Point 1");
				}
				else
				{
					Format(translation, sizeof(translation), "Set Point 1");
				}
			}
			else if (StrEqual(item, "2"))
			{
				if (g_bPoints[client][1])
				{
					Format(translation, sizeof(translation), "Update Point 2\n ");
				}
				else
				{
					Format(translation, sizeof(translation), "Set Point 2\n ");
				}
			}
			else if (StrEqual(item, "Print"))
			{
				Format(translation, sizeof(translation), "Print distance\n ");
			}
			else if (StrEqual(item, "Reset"))
			{
				Format(translation, sizeof(translation), "Reset Points\n ");
			}
			else if (StrEqual(item, "Snap"))
			{
				Format(translation, sizeof(translation), "Snapping %s", g_bSnap[client] ? "[On]" : "[Off]");
			}
			else if (StrEqual(item, "Snap_Step"))
			{
				Format(translation, sizeof(translation), "Snap step: %d", g_iSnap_Steps[g_iSnap[client]]);
			}

			return RedrawMenuItem(translation);
		}
	}

	return 0;
}

/*
Points
*/

stock void Point_Reset(int client, int point_num)
{
	g_bPoints[client][point_num-1] = false;

	for (int i; i < 3; i++)
	{
		g_fPoints[client][point_num-1][i] = 0.0;
	}
}



stock void Point_Set(int client, int point_num)
{
	float point[3];

	if (Point_Get_Aim(client, point))
	{
		if (g_bSnap[client])
		{
			Point_Snap(client, point);
		}

		g_bPoints[client][point_num-1] = true;

		for (int i; i < 3; i++)
		{
			g_fPoints[client][point_num-1][i] = point[i];
		}
	}
}

stock bool Point_Get_Aim(int client, float point[3])
{
	float angles[3];
	GetClientEyeAngles(client, angles);

	return Point_Get_Trace(client, angles, point);
}

stock bool Point_Get_Trace(int client, float angles[3], float point[3])
{
	float origin[3];
	GetClientEyePosition(client, origin);

	TR_TraceRayFilter(origin, angles, MASK_PLAYERSOLID, RayType_Infinite, Point_Trace_Filter, client);

	if (TR_DidHit())
	{
		TR_GetEndPosition(point);

		return true;
	}

	return false;
}

public bool Point_Trace_Filter(int entity, int mask, any data)
{
	return entity != data && !(0 < entity <= MaxClients);
}

stock void Point_Snap(int client, float point[3])
{
	int snap = g_iSnap_Steps[g_iSnap[client]];

	for (int i; i < 2; i++)
	{
		point[i] = float(RoundFloat(point[i] / float(snap)) * snap);
	}
}

public void Distance_Print(int client)
{
	if (g_bPoints[client][0] && g_bPoints[client][1])
	{
		float d[3];

		for (int i; i < 3; i++)
		{
			d[i] = g_fPoints[client][1][i] - g_fPoints[client][0][i];
		}

		float dxy = SquareRoot(Pow(d[0], 2.0) + Pow(d[1], 2.0));

		CPrintToChat(client, "%s %sΔx: %s%.1f %s| Δy: %s%.1f %s| Δz: %s%.1f %s| Δxy: %s%.1f", 	CHAT_DIST, CHAT_TEXT, 
																								CHAT_VALUE, d[0], CHAT_TEXT, 
																								CHAT_VALUE, d[1], CHAT_TEXT, 
																								CHAT_VALUE, d[2], CHAT_TEXT, 
																								CHAT_VALUE, dxy);
	}
}

/*
Beam Drawing
*/

public void OnMapStart()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		OnClientPutInServer(client);
	}

	Beam_Update_Model();
	Beam_Update_Halo();

	CreateTimer(BEAM_DRAW_INTERVAL, Beam_Draw_Timer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void Beam_Update_Model()
{
	g_iBeam_Model = PrecacheModel(BEAM_TEXTURE_VMT);
	AddFileToDownloadsTable(BEAM_TEXTURE_VMT);
	AddFileToDownloadsTable(BEAM_TEXTURE_VTF);

	g_iSnap_Model = PrecacheModel(SNAP_TEXTURE_VMT);
	AddFileToDownloadsTable(SNAP_TEXTURE_VMT);
	AddFileToDownloadsTable(SNAP_TEXTURE_VTF);
}

public void Beam_Update_Halo()
{
	g_iBeam_Halo = PrecacheModel(BEAM_HALO);
	g_iSnap_Halo = PrecacheModel(SNAP_HALO);
}




public Action Beam_Draw_Timer(Handle timer, any data)
{
	Beam_Draw();
}

public void Beam_Draw()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (lolo_IsClientValid(client))
		{
			Beam_Draw_Snap(client);
			Beam_Draw_Beam(client);
		}
	}
}

public void Beam_Draw_Snap(int client)
{
	if (g_bMenu[client] && g_bSnap[client])
	{
		float point[3];

		if (Point_Get_Aim(client, point))
		{
			float point_snap[3];

			for (int i; i < 3; i++)
			{
				point_snap[i] = point[i];
			}

			Point_Snap(client, point_snap);

			TE_SetupBeamPoints(point, point_snap, g_iSnap_Model, g_iSnap_Halo, 0, 0, BEAM_DRAW_INTERVAL, 0.25, 0.25, 0, 0.0, {255, 255, 255, 255}, 0);
			TE_SendToClient(client);
		}
	}
}

public void Beam_Draw_Beam(int client)
{
	if (g_bPoints[client][0] && g_bPoints[client][1])
	{
		TE_SetupBeamPoints(g_fPoints[client][0], g_fPoints[client][1], g_iBeam_Model, g_iBeam_Halo, 0, 0, BEAM_DRAW_INTERVAL, 0.25, 0.25, 0, 0.0, {255, 255, 255, 255}, 0);
		TE_SendToClient(client);
	}
}