#NoEnv
#WinActivateForce
#SingleInstance force
SendMode Input
SetWorkingDir %A_ScriptDir%
SetTitleMatchMode, 2

#Persistent
OnExit, ExitSub

; Init Vars
global Artist, Track
settings_file := "settings.ini"
now_playing_file := "output\NowPlaying.txt"
album_art := "output\Cover.png"
temp_json_file := "tmp\temp.json"
artist_json_file := "tmp\artist.json"
was_playing := ""
debug := 0

If FileExist(settings_file)
{
	path := ini_load(ini, settings_file)
	lastfm_user := ini_getValue(ini, Settings, "User")
	api_key := ini_getValue(ini, Settings, "API_Key")
}
Else
{
	Msgbox, Config ini not found!
	ExitApp
}

SetTimer, CheckSong, 500
Return

CheckSong:
	WinGetTitle, playing, ahk_class SpotifyMainWindow
	StringTrimLeft, playing, playing, 10
	if (was_playing != playing)
	{
		; Save playing song to check for changes
		was_playing := playing
		; Remove Spotify's pesky Original Mix suffix
		if InStr(playing, "- Original Mix")
			playing := RegExReplace(playing, "- Original Mix", "")
		; Prepend whitespace for scrolling	
		playing_formatted := "      " . playing
		FileDelete %now_playing_file%
		FileAppend, %playing_formatted%, %now_playing_file%, UTF-8
		Sleep, 3000
		GoSub, GetSongInfo
		Menu, Tray, Tip, %Artist% - %Track%
	}
	Return

GetSongInfo:
	; Retrieve song's json info from last.fm api
	Url := "http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user=" lastfm_user "&api_key=" api_key "&format=json"
	URLDownloadToFile, % Url, % temp_json_file
	FileRead, j, % temp_json_file
	Artist := UnJson(json(j, "recenttracks.track[0].artist.#text"))
	Track := UnJson(json(j, "recenttracks.track[0].name"))
	album_art_url := UnJson(json(j, "recenttracks.track[0].image[3].#text"))

	; If no album art found for song, try to retrieve from artist
	If StrLen(album_art_url) < 1
	{
		Url_Artist := "http://ws.audioscrobbler.com/2.0/?method=artist.getInfo&artist=" Artist "&api_key=" api_key "&format=json"
		URLDownloadToFile, % Url_Artist , % artist_json_file
		FileRead, a, % artist_json_file
		album_art_url := UnJson(json(a, "artist.image[3].#text"))
		If StrLen(album_art_url) < 1
		{
			URLDownloadToFile, % album_art_url, % album_art
			source := "Source: Top Artist Albums"
		}
		Else
		{
			FileCopy, img\Unknown.png, % album_art, 1
		}
	}
	Else
	{
		source := "Source: Recent Tracks"
		URLDownloadToFile, % album_art_url, % album_art
	}
	Notify(Artist . " - " . Track, source,-4,"Style=Fast Image=" album_art)
	if debug
		Gosub, Debug
	Return

UnJson(string)
{
	return % RegExReplace(string, "\\/", "/")
}

Debug:
	Run % album_art
	Traytip, Now Playing, %Artist% - %Track%, 1
	clipboard := album_art_url
	Return

ExitSub:
	FileDelete % album_art
	FileDelete % now_playing_file
	FileDelete % temp_json_file
	FileDelete % artist_json_file
	ExitApp
	Return

#Include %A_ScriptDir%\lib\json.ahk
#Include %A_ScriptDir%\lib\ini.ahk
#Include %A_ScriptDir%\lib\Notify.ahk