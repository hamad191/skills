-- Sound effects and music. Sounds are listed in Config.SOUNDS and Config.MUSIC; volumes come
-- from the player's settings. Each sound has a minimum gap so a swarm of hits doesn't turn into
-- noise, and positioned sounds play in 3D at the spot they happen.
local RS = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))

local Sounds = {}
local volume = { music = 0.5, sfx = 0.8 }
local lastPlayed = {}

local sfxGroup = Instance.new("SoundGroup")
sfxGroup.Name = "Effects"
sfxGroup.Parent = SoundService
local musicGroup = Instance.new("SoundGroup")
musicGroup.Name = "Music"
musicGroup.Parent = SoundService

-- Plays a sound by name. opts: pos (Vector3 for 3D sound), volume (multiplier), pitch (exact).
function Sounds.play(name, opts)
	local def = Config.SOUNDS[name]
	if not def or def.id == "" or volume.sfx <= 0 then
		return
	end
	local now = os.clock()
	if now - (lastPlayed[name] or 0) < (def.gap or 0) then
		return
	end
	lastPlayed[name] = now
	opts = opts or {}
	local sound = Instance.new("Sound")
	sound.SoundId = def.id
	sound.Volume = def.volume * (opts.volume or 1)
	local pitch = def.pitch
	sound.PlaybackSpeed = opts.pitch or (pitch and pitch[1] + math.random() * (pitch[2] - pitch[1])) or 1
	sound.SoundGroup = sfxGroup
	if opts.pos then
		-- a 3D sound at the spot: louder close by, fading out with distance
		local spot = Instance.new("Attachment")
		spot.WorldPosition = opts.pos
		spot.Parent = workspace.Terrain
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 20
		sound.RollOffMaxDistance = 220
		sound.Parent = spot
		Debris:AddItem(spot, 4)
	else
		sound.Parent = SoundService
		Debris:AddItem(sound, 4)
	end
	sound:Play()
end

-- Music ---------------------------------------------------------------------------------------

local tracks = {} -- [name] = Sound
local current

-- Crossfades to a music track ("Lobby", "Battle", "Boss"); tracks without an id are silent.
function Sounds.music(name)
	if current == name then
		return
	end
	current = name
	for trackName, sound in tracks do
		if trackName ~= name then
			TweenService:Create(sound, TweenInfo.new(1.5), { Volume = 0 }):Play()
		end
	end
	local id = Config.MUSIC[name]
	if not id or id == "" then
		return
	end
	local sound = tracks[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = id
		sound.Looped = true
		sound.Volume = 0
		sound.SoundGroup = musicGroup
		sound.Parent = SoundService
		tracks[name] = sound
	end
	if not sound.IsPlaying then
		sound:Play()
	end
	TweenService:Create(sound, TweenInfo.new(1.5), { Volume = 0.6 }):Play()
end

-- Applies the volume settings (0 to 1 each).
function Sounds.setVolume(music, sfx)
	volume.music, volume.sfx = music, sfx
	musicGroup.Volume = music
	sfxGroup.Volume = sfx
end

return Sounds
