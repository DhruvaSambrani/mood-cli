using InteractiveUtils
using TerminalMenus
using Dates
using JSON
using OrderedCollections

clear() = println("\33[2J")

include("./config.jl")

function rating()
  response = request("How are you feeling today? ", RadioMenu(collect(values(rating_emoji_map))))
  OrderedCollections.OrderedSet(keys(rating_emoji_map))[response]
end

emotion_grid = "
EMOTIONS:
+-----------------------------------------+---------------------------------------+
|                                     ENERGIZED                                   |
|         +-------------------------------|------------------------------+        |
|         | tense    (-2 2) nervous(-1 2) | excited (1 2)    lively(2 2) |        |
|         | irritated(-2 1) annoyed(-1 1) | happy   (1 1)  cheerful(2 1) |        |
|UNPLEASANT-------------------------------+------------------------------PLEASANT |
|         | bored   (-2 -1) weary (-1 -1) | carefree(1 -1) relaxed(2 -1) |        |
|         | gloomy  (-2 -2) sad   (-1 -2) | calm    (1 -1)  serene(2 -2) |        |
|         +-------------------------------|------------------------------+        | |                                        CALM                                     |
+-----------------------------------------+---------------------------------------+

Where are you on this grid today? {-2:2 2:2}
"

function emotions()
  println(emotion_grid)
  return Tuple(parse.(Int, split(readline())))
end

function journal()
  path = joinpath(MOOD_JOURNAL_DIR, string(today()))
  edit(path)
  return path
end

function photos()
  photo_paths = String[]
  while true
    _inp = readline()
    _inp == "" && break
    push!(photo_paths, _inp)
  end
  return photo_paths
end

function activities()
  selection = collect(request(MultiSelectMenu(activity_list)))
  return activity_list[selection]
end

function time_selector()
  print("[HHMM] ")
  return Time(readline(), "HHMM")
end

function location_weather()
  print("Where are you today? ")
  loca = readline()
  api_call(loca)
end

struct SleepData
  sleeptime::Time
  waketime::Time
  rested::Int64
  tags::Vector{String}
end
SleepData(d::Dict) = SleepData(Time(d["sleeptime"]), Time(d["waketime"]), d["rested"], d["tags"])

function sleep()
  print("When did you sleep?")
  sleeptime = time_selector()
  print("When did you wake up?")
  waketime = time_selector()
  rested = request("How well rested are you?", RadioMenu(string.(1:5)))
  tags = collect(request("Tags:", MultiSelectMenu(sleep_tags)))
  return SleepData(sleeptime, waketime, rested, sleep_tags[tags])
end

struct LocationData
  location::String
  min_temp::Float64
  max_temp::Float64
  rain::Bool
end

LocationData(d::Dict) = LocationData(d["location"], d["min_temp"], d["max_temp"], d["rain"])

function api_call(location)
  geolink = "api.openweathermap.org/geo/1.0/direct?q=$location&appid=$API_KEY"
  georesult = JSON.parse(read(download(geolink), String))
  lat, lon = georesult["lat"], georesult["lon"]
  link = "api.openweathermap.org/data/2.5/onecall?lat=$lat&lon=$lon&appid=$API_KEY"
  result = JSON.parse(read(download(link), String))
  return LocationData(location, result["daily"]["temp"]["min"], result["daily"]["temp"]["min"], true)
end

struct PhysicalActivity
  vigourous::Time
  moderate::Time
  tags::Vector{String}
end

PhysicalActivity(d::Dict) = PhysicalActivity(Time(d["vigourous"]), Time(d["moderate"]), d["tags"])

function physical_activity()
  print("Vigourous Activity")
  vigorous = time_selector()
  print("Moderate Activity")
  moderate = time_selector()
  tags = collect(request("Tags:", MultiSelectMenu(workout_tags)))
  return PhysicalActivity(vigorous, moderate, workout_tags[tags])
end

medication() = println("Not implemented yet")

social_interactions() = println("Not implemented yet")

symptoms() = println("Not implemented yet")

mutable struct Data
  rating::Int64
  emotions::Tuple{Int64,Int64}
  journal::String
  photos::Vector{String}
  activities::Vector{String}
  sleep::SleepData
  location_weather::LocationData
  physical_activity::PhysicalActivity
  #medication::Medications
  #social_interactions::SocialInteractions
  symptoms::Vector{Pair{String,Int64}}
  function Data()
    new(
      1, (1, 1), "none", String[], String[],
      SleepData(now(), now(), 1, String[]), LocationData("nowhere", 0.0, 0.0, false),
      PhysicalActivity(now(), now(), String[]),
      Pair{String,Int64}[]
    )
  end
  function Data(dict)
    new(
      dict["rating"], Tuple(dict["emotions"]), dict["journal"],
      dict["photos"], dict["activities"], SleepData(dict["sleep"]),
      LocationData(dict["location_weather"]), PhysicalActivity(dict["physical_activity"]),
      dict["symptoms"]
    )
  end
end
save(data::Data) = write(string(today()) * ".json", JSON.json(data))

function get_today()
  if isfile(string(today()) * ".json")
    return Data(JSON.parse(read(string(today()) * ".json", String)))
  else
    return Data()
  end
end


function main()
  actions = [
    rating,
    emotions,
    journal,
    photos,
    activities,
    sleep,
    location_weather,
    physical_activity,
    medication,
    social_interactions,
    symptoms
  ]
  d = get_today()
  while true
    clear()
    println(JSON.json(d, 4))
    inp = request(
      "What do you want to do?",
      RadioMenu(string.(actions), pagesize = length(actions))
    )
    if inp == -1
      break
    end
    act = actions[inp]
    setproperty!(d, Symbol(string(act)), act())
    save(d)
  end
end

main()

