package;
#if html
import js.html.FileSystem;
#end
import openfl.utils.Future;
import openfl.media.Sound;
import flixel.system.FlxSound;
#if sys
import sys.FileSystem;
import sys.io.File;
#end
import Song.SwagSong;
import flixel.input.gamepad.FlxGamepad;
import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.utils.Assets;


#if windows
import Discord.DiscordClient;
#end

using StringTools;

class FreeplayState extends MusicBeatState
{
	public static var songs:Array<SongMetadata> = [];

	public static var currentSelected:Int = 0;
	public static var currentDifficulty:Int = 1;

	public static var rate:Float = 1.0;

	var scoreText:FlxText;
	var comboText:FlxText;
	var diffText:FlxText;
	var instruct:FlxText;
	var previewtext:FlxText;

	var lerpScore:Int = 0;
	var intendedScore:Int = 0;

	var combo:String = '';
	
	var bg:FlxSprite;

	
	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var curPlaying:Bool = false;

	private var iconArray:Array<HealthIcon> = [];

	public static var openedPreview = false;

	public static var songData:Map<String,Array<SwagSong>> = [];

	public static function loadDiff(diff:Int, format:String, name:String, array:Array<SwagSong>)
	{
		try 
		{
			var fart = Utility.difficultyArray[diff];
			
			array.push(Song.loadFromJson(name,fart.toLowerCase()));
		}
		catch(ex)
		{
			trace("Error: " + ex);
		}
	}

	override function create()
	{
		var isDebug:Bool = false;
		persistentUpdate = true;
		songData = [];
		songs = [];
		
		
		#if debug
		isDebug = true;
		#end

		#if windows
		DiscordClient.changePresence("In the Songs Menu", null);
		#end

		#if sys
		var initSonglist = sys.FileSystem.readDirectory("assets/songs");//Utility.coolTextFile(Paths.txt('data/freeplaySonglist'));
		#else
		var initSonglist = Utility.coolTextFile(Paths.txt('data/freeplaySonglist'));
		#end

		for (i in 0...initSonglist.length)
		{
			var data:Array<String> = initSonglist[i].split(':');
			var meta = new SongMetadata(data[0], Std.parseInt(data[2]), data[1]);

			songs.push(meta);
			trace(meta);
			
			var format = StringTools.replace(meta.songName, " ", "-");
			format = Utility.songLowercase(format);

			var diffs = [];
			FreeplayState.loadDiff(0,format,meta.songName,diffs); // Easy
			FreeplayState.loadDiff(1,format,meta.songName,diffs); // Normal
			FreeplayState.loadDiff(2,format,meta.songName,diffs); // Hard
			FreeplayState.loadDiff(3,format,meta.songName,diffs); // Insane
			FreeplayState.loadDiff(4,format,meta.songName,diffs); // Expert
			FreeplayState.songData.set(meta.songName,diffs);
			
			trace('Difficulties Loaded for ' + meta.songName);
		}


		bg = new FlxSprite().loadGraphic(Paths.image('ui/Backgrounds/BackgroundFreeplay', 'preload'));
		add(bg);

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		var loadedSongs:Int = 0;


		for (i in 0...songs.length)
		{
			var songText:Alphabet = new Alphabet(0, (70 * i) + 30, songs[i].songName, true, false, true);
			songText.isMenuItem = true;
			songText.targetY = i;
			grpSongs.add(songText);

			var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
			icon.sprTracker = songText;

			iconArray.push(icon);
			add(icon);

			loadedSongs++;
		}
		
		var newSongMeta = new SongMetadata("create new song",0,null);
		songs.push(newSongMeta);
		var newSongText:Alphabet = new Alphabet(0, (70 * loadedSongs) + 30, "create new song", true, false, true);
		newSongText.isMenuItem = true;
		newSongText.targetY = loadedSongs;
		grpSongs.add(newSongText);

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);

		var scoreBG:FlxSprite = new FlxSprite(scoreText.x - 6, 0).makeGraphic(Std.int(FlxG.width * 0.35), 105, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
		diffText.font = scoreText.font;
		add(diffText);

		instruct = new FlxText(scoreText.x, scoreText.y + 650, 0, "Left click to play\nRight click to edit", 24);
		instruct.font = scoreText.font;
		add(instruct);

		comboText = new FlxText(diffText.x + 100, diffText.y, 0, "", 24);
		comboText.font = diffText.font;
		add(comboText);

		add(scoreText);
	
		super.create();
		
		changeSelection();
		changeDiff();
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String)
	{
		songs.push(new SongMetadata(songName, weekNum, songCharacter));
	}

	public function addWeek(songs:Array<String>, weekNum:Int, ?songCharacters:Array<String>)
	{
		if (songCharacters == null)
			songCharacters = ['dad'];

		var num:Int = 0;
		for (song in songs)
		{
			addSong(song, weekNum, songCharacters[num]);

			if (songCharacters.length != 1)
				num++;
		}
	}
	
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (FlxG.sound.music.volume < 0.7)
		{
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
		}

		lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, 0.4));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;

		scoreText.text = "PERSONAL BEST:" + lerpScore;
		comboText.text = combo + '\n';

		if (FlxG.sound.music.volume > 0.8)
		{
			FlxG.sound.music.volume -= 0.5 * FlxG.elapsed;
		}

		var upP = FlxG.keys.justPressed.UP;
		var downP = FlxG.keys.justPressed.DOWN;
		var accepted = FlxG.mouse.pressed;
		var right = FlxG.mouse.pressedRight;

		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;

		if (gamepad != null)
		{

			if (gamepad.justPressed.DPAD_UP)
			{
				changeSelection(-1);
			}
			if (gamepad.justPressed.DPAD_DOWN)
			{
				changeSelection(1);
			}
			if (gamepad.justPressed.DPAD_LEFT)
			{
				changeDiff(-1);
			}
			if (gamepad.justPressed.DPAD_RIGHT)
			{
				changeDiff(1);
			}
;
		}

		if (upP)
		{
			changeSelection(-1);
		}
		if (downP)
		{
			changeSelection(1);
		}



		if (FlxG.keys.justPressed.LEFT)
			changeDiff(-1);
		if (FlxG.keys.justPressed.RIGHT)
			changeDiff(1);

		if (controls.BACK)
		{
			FlxG.switchState(new MainMenuState());
		}

		if (accepted)
		{
			if (songs[currentSelected].songName == "create new song")
			{
				trace("Song Creation Selected");
				FlxG.switchState(new NewSongState());
			}
			else
			{
				var songFormat = StringTools.replace(songs[currentSelected].songName, " ", "-");
				songFormat = Utility.songLowercase(songFormat);
				

				var songRef;
				try
				{
					var fart = Utility.difficultyArray[currentDifficulty];
					songRef = Song.loadFromJson(songs[currentSelected].songName,fart.toLowerCase()); // 
					if (Song == null)
					{
						FlxG.sound.play(Paths.sound('cancelMenu'), 0.4);
						trace("ERROR: Song returned null");
						return;
					}
						
				}
				catch(ex)
				{
					FlxG.sound.play(Paths.sound('cancelMenu'), 0.4);
					trace("ERROR: Song returned null");
					return;
				}


				PlayState.SONG = songRef;
				PlayState.isStoryMode = false;
				PlayState.storyDifficulty = currentDifficulty;
				PlayState.storyWeek = songs[currentSelected].week;
				trace('Current Week: ' + PlayState.storyWeek);
				LoadingState.loadAndSwitchState(new PlayState());
			}
		}

		if (right)
		{
			// adjusting the song name to be compatible
			var songFormat = StringTools.replace(songs[currentSelected].songName, " ", "-");
			songFormat = Utility.songLowercase(songFormat);

			var hmm = songData.get(songs[currentSelected].songName)[currentDifficulty];
	
			PlayState.SONG = hmm;
			ChartingState.fromSongMenu = true;
			FlxG.switchState(new ChartingState());
		}
	}

	function changeDiff(change:Int = 0)
	{
		currentDifficulty += change;

		if (currentDifficulty < 0)
			currentDifficulty = 4;
		if (currentDifficulty > 4)
			currentDifficulty = 0;
		
		GlobalData.latestDiff = currentDifficulty;

		// adjusting the highscore song name to be compatible (changeDiff)
		var songHighscore = StringTools.replace(songs[currentSelected].songName, " ", "-");
		songHighscore = Utility.songLowercase(songHighscore);
		
		#if !switch
		intendedScore = Highscore.getScore(songHighscore, currentDifficulty);
		combo = Highscore.getCombo(songHighscore, currentDifficulty);
		#end
		diffText.text = Utility.difficultyFromInt(currentDifficulty).toUpperCase();
	}

	function changeSelection(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);



		currentSelected += change;

		if (currentSelected < 0)
			currentSelected = songs.length - 1;
		if (currentSelected >= songs.length)
			currentSelected = 0;


		var songHighscore = StringTools.replace(songs[currentSelected].songName, " ", "-");
		songHighscore = Utility.songLowercase(songHighscore);

		#if !switch
		intendedScore = Highscore.getScore(songHighscore, currentDifficulty);
		combo = Highscore.getCombo(songHighscore, currentDifficulty);
		// lerpScore = 0;
		#end

		var bullShit:Int = 0;

		for (i in 0...iconArray.length)
		{
			iconArray[i].alpha = 0.6;
		}

		if (songs[currentSelected].songName != "create new song")
		{
			iconArray[currentSelected].alpha = 1;
		}
		

		for (item in grpSongs.members)
		{
			item.targetY = bullShit - currentSelected;
			bullShit++;

			item.alpha = 0.6;
			// item.setGraphicSize(Std.int(item.width * 0.8));

			if (item.targetY == 0)
			{
				item.alpha = 1;
				// item.setGraphicSize(Std.int(item.width));
			}
		}

		try 
		{
			bg.color = Stage.getStageColors(songData.get(songs[currentSelected].songName)[currentDifficulty].stage);
		}
		catch(ex)
		{
			trace("Background Color: Null Object Refrence");
		}
	}
}
