#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\gametypes_zm\_hud_message;

init()
{
    level.highRoundOnePlayer = 0;
    level.highRoundTwoPlayers = 0;
    level.highRoundThreePlayers = 0;
    level.highRoundFourPlayers = 0;
    level.highRoundPlayersOne = "None";
    level.highRoundPlayersTwo = "None";
    level.highRoundPlayersThree = "None";
    level.highRoundPlayersFour = "None";
    
    level thread high_round_tracker();
    level thread onPlayerConnect();
}

onPlayerConnect()
{
    for(;;)
    {
        level waittill("connected", player);
        player thread high_round_info();
    }
}

high_round_tracker()
{
	thread high_round_info_giver();
	gamemode = gamemodeName( getDvar( "ui_gametype" ) );
	map = mapName( level.script );
	if( level.script == "zm_transit" && getDvar( "ui_gametype" ) == "zsurvival" )
		map = startLocationName( getDvar( "ui_zm_mapstartlocation" ) );
	
	//file handling//
	level.basepath = getDvar("fs_homepath") + "/";
	path = level.basepath + "/logs/" + map + gamemode + "HighRound.txt";
	file = fopen(path, "r");
	text = fread(file);
	fclose(file);
	//end file handling//

	highroundinfo = strToK( text, ";" );
	if ( highroundinfo.size >= 8 )
	{
		level.highRoundOnePlayer = int( highroundinfo[ 0 ] );
		level.highRoundTwoPlayers = int( highroundinfo[ 1 ] );
		level.highRoundThreePlayers = int( highroundinfo[ 2 ] );
		level.highRoundFourPlayers = int( highroundinfo[ 3 ] );
		
		// Stores ID:Name blocks (e.g., "5:PlayerOne,6:PlayerTwo")
		level.highRoundPlayersOne = highroundinfo[ 4 ];
		level.highRoundPlayersTwo = highroundinfo[ 5 ];
		level.highRoundPlayersThree = highroundinfo[ 6 ];
		level.highRoundPlayersFour = highroundinfo[ 7 ];
	}
	else
	{
		level.highRoundOnePlayer = 0;
		level.highRoundTwoPlayers = 0;
		level.highRoundThreePlayers = 0;
		level.highRoundFourPlayers = 0;
		level.highRoundPlayersOne = "None";
		level.highRoundPlayersTwo = "None";
		level.highRoundPlayersThree = "None";
		level.highRoundPlayersFour = "None";
	}

	for ( ;; )
	{
		level waittill ( "end_game" );
		players = get_players();
		numPlayers = players.size;
		
		if ( numPlayers == 1 && level.round_number > level.highRoundOnePlayer )
			updateHighRoundRecord(1, players);
		else if ( numPlayers == 2 && level.round_number > level.highRoundTwoPlayers )
			updateHighRoundRecord(2, players);
		else if ( numPlayers == 3 && level.round_number > level.highRoundThreePlayers )
			updateHighRoundRecord(3, players);
		else if ( numPlayers == 4 && level.round_number > level.highRoundFourPlayers )
			updateHighRoundRecord(4, players);
	}
}

// Dynamically decodes the "ID:Name" blocks and checks live statuses
get_current_names_from_ids( data_string )
{
	if( data_string == "None" || data_string == "" )
		return "None";

	player_blocks = strToK( data_string, "," );
	current_players = get_players();
	resolved_names = "";

	for( i = 0; i < player_blocks.size; i++ )
	{
		block = player_blocks[i];
		split_block = strToK( block, ":" );
		
		if( split_block.size < 2 )
			continue;

		target_id = split_block[0];
		saved_name = split_block[1];
		found_name = ""; 

		// Step 1: Scan online players for a matching live IW4MAdmin ID
		foreach( player in current_players )
		{
			if( isDefined( player.persistentClientId ) && ( "" + player.persistentClientId ) == target_id )
			{
				found_name = player.name; // Use their live, updated name
				break;
			}
		}

		// Step 2: Fallback to the saved name if the player is offline
		if( found_name == "" )
		{
			found_name = saved_name; 
		}

		if( resolved_names == "" )
			resolved_names = found_name;
		else
			resolved_names = resolved_names + ", " + found_name;
	}

	return resolved_names;
}

updateHighRoundRecord( numPlayers, players )
{
	level.highRoundPlayers = "";
	for ( i = 0; i < players.size; i++ )
	{
		player_id = "";
		if ( isDefined( players[i].persistentClientId ) )
			player_id = "" + players[i].persistentClientId;
		else
			player_id = "" + players[i] getGuid();

		// Clean names to prevent string parsing errors (removes colons/commas from names)
		clean_name = players[i].name;
		clean_name = colons_and_commas_remover(clean_name);

		// Format saved as ID:Name
		data_block = player_id + ":" + clean_name;

		if( level.highRoundPlayers == "" )
			level.highRoundPlayers = data_block;
		else
			level.highRoundPlayers = level.highRoundPlayers + "," + data_block;
	}

	if( numPlayers == 1 )
	{
		level.highRoundOnePlayer = level.round_number;
		level.highRoundPlayersOne = level.highRoundPlayers;
	}
	else if( numPlayers == 2 )
	{
		level.highRoundTwoPlayers = level.round_number;
		level.highRoundPlayersTwo = level.highRoundPlayers;
	}
	else if( numPlayers == 3 )
	{
		level.highRoundThreePlayers = level.round_number;
		level.highRoundPlayersThree = level.highRoundPlayers;
	}
	else if( numPlayers == 4 )
	{
		level.highRoundFourPlayers = level.round_number;
		level.highRoundPlayersFour = level.highRoundPlayers;
	}

	// Announce new record, updating names if online, falling back to file names if offline
	foreach( player in level.players )
	{
		player tell( "^1NEW RECORD!" );
		wait 2;

		if( numPlayers == 1 )
			player tell( "^21 Player: ^1" + level.highRoundOnePlayer + " ^7(" + get_current_names_from_ids(level.highRoundPlayersOne) + ")" );
		else if( numPlayers == 2 ) 
			player tell( "^32 Players: ^1" + level.highRoundTwoPlayers + " ^7(" + get_current_names_from_ids(level.highRoundPlayersTwo) + ")" );
		else if( numPlayers == 3 ) 
			player tell( "^53 Players: ^1" + level.highRoundThreePlayers + " ^7(" + get_current_names_from_ids(level.highRoundPlayersThree) + ")" );
		else if( numPlayers == 4 ) 
			player tell( "^64 Players: ^1" + level.highRoundFourPlayers + " ^7(" + get_current_names_from_ids(level.highRoundPlayersFour) + ")" );
	}

	log_highround_record( 
		level.highRoundOnePlayer + ";" + 
		level.highRoundTwoPlayers + ";" + 
		level.highRoundThreePlayers + ";" + 
		level.highRoundFourPlayers + ";" + 
		level.highRoundPlayersOne + ";" + 
		level.highRoundPlayersTwo + ";" + 
		level.highRoundPlayersThree + ";" + 
		level.highRoundPlayersFour 
	);
}

colons_and_commas_remover( name_string )
{
	output = "";
	for( i = 0; i < name_string.size; i++ )
	{
		if( name_string[i] != ":" && name_string[i] != "," && name_string[i] != ";" )
		{
			output += name_string[i];
		}
	}
	if( output == "" ) 
		return "Player";
	return output;
}

log_highround_record( newRecord )
{
	gamemode = gamemodeName( getDvar( "ui_gametype" ) );
	map = mapName( level.script );
	if( level.script == "zm_transit" && getDvar( "ui_gametype" ) == "zsurvival" )
		map = startLocationName( getDvar( "ui_zm_mapstartlocation" ) );
	level.basepath = getDvar("fs_homepath") + "/";
	path = level.basepath + "/logs/" + map + gamemode + "HighRound.txt";
	file = fopen( path, "w" );
	fwrite( file, newRecord );
	fclose( file );
}

startLocationName( location )
{
	if( location == "cornfield" )
		return "Cornfield";
	else if( location == "diner" )
		return "Diner";
	else if( location == "farm" )
		return "Farm";
	else if( location == "power" )
		return "Power";
	else if( location == "town" )
		return "Town";
	else if( location == "transit" )
		return "BusDepot";
	else if( location == "tunnel" )
		return "Tunnel";
}

mapName( map )
{
	if( map == "zm_buried" )
		return "Buried";
	else if( map == "zm_highrise" )
		return "DieRise";
	else if( map == "zm_prison" )
		return "Motd";
	else if( map == "zm_nuked" )
		return "Nuketown";
	else if( map == "zm_tomb" )
		return "Origins";
	else if( map == "zm_transit" )
		return "Tranzit";
	return "NA";
}

gamemodeName( gamemode )
{
	if( gamemode == "zstandard" )
		return "Standard";
	else if( gamemode == "zclassic" )
		return "Classic";
	else if( gamemode == "zsurvival" )
		return "Survival";
	else if( gamemode == "zgrief" )
		return "Grief";
	else if( gamemode == "zcleansed" )
		return "Turned";
	return "NA";
}

high_round_info_giver()
{
	highroundinfo = 1;
	roundmultiplier = 5;
	level endon( "end_game" );

	while( 1 )
	{	
		level waittill( "start_of_round" );

		if( level.round_number == ( highroundinfo * roundmultiplier ))
		{
			highroundinfo++;
			players = get_players();
			numPlayers = players.size;

			foreach( player in players )
			{
				player tell( "^7Current High Round Record:" );
				wait 2;

				if( numPlayers == 1 )
					player tell( "^21 Player: ^1" + level.highRoundOnePlayer + " ^7(" + get_current_names_from_ids(level.highRoundPlayersOne) + ")" );
				else if( numPlayers == 2 )
					player tell( "^32 Players: ^1" + level.highRoundTwoPlayers + " ^7(" + get_current_names_from_ids(level.highRoundPlayersTwo) + ")" );
				else if( numPlayers == 3 )
					player tell( "^53 Players: ^1" + level.highRoundThreePlayers + " ^7(" + get_current_names_from_ids(level.highRoundPlayersThree) + ")" );
				else if( numPlayers == 4 )
					player tell( "^64 Players: ^1" + level.highRoundFourPlayers + " ^7(" + get_current_names_from_ids(level.highRoundPlayersFour) + ")" );
			}
		}
	}
}

high_round_info()
{
	wait 6;
	self tell( "^7High Round Records:" );
	wait 2;
	self tell( "^21 Player: ^1" + level.highRoundOnePlayer + " ^7(" + get_current_names_from_ids(level.highRoundPlayersOne) + ")" );
	wait 2;
	self tell( "^32 Players: ^1" + level.highRoundTwoPlayers + " ^7(" + get_current_names_from_ids(level.highRoundPlayersTwo) + ")" );
	wait 2;
	self tell( "^53 Players: ^1" + level.highRoundThreePlayers + " ^7(" + get_current_names_from_ids(level.highRoundPlayersThree) + ")" );
	wait 2;
	self tell( "^64 Players: ^1" + level.highRoundFourPlayers + " ^7(" + get_current_names_from_ids(level.highRoundPlayersFour) + ")" );
}