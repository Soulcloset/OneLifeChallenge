/*
    One-Life Challenge
    TODO:
    - Get current finish time, add points based on medal achieved ✅
    - Reset points to 0 on respawn/give up ✅
    - Settings menu enable/disable ✅❌
        - Buttons on UI to start/stop, rather than in settings menu. Start button should reset points to 0 
    - Random map picking ✅
        - Add automatic random map picking, rather than a manual button
    - Skip button
    - Add UI to show points (always shown when enabled)
    - Start/stop functionality (in UI)
    - In UI, indicate when points are added with fancy text for medal name

*/

[Setting category="General" name="Show/Hide Window" description="When checked, the 1LC window will be visible."]
bool WindowVisible;

//[Setting category="General" name="start challenge?" description="When checked, the 1LC window will be visible."]
bool PowerSwitch = false; //this is used to enable/disable the challenge, the commented line above is used to make it part of the settings

[Setting category="Developers" name="Debug Mode" description="Enable/disable debug mode for 1LC. This will show the debug options in the Openplanet Plugins menu, including the ability to reset your personal best permanently."]
bool debugMode = false;

[Setting category="Developers" name="Verbose Mode" description="Enable/disable verbose logging to the Openplanet console (Warning: this will spam the console)"]
bool verboseMode = false; //debug mode for testing;

[Setting hidden]
int AllTimeBest = 0;


bool HandledRun = false;
int curTime = -1;
int tempPoints = 0; //0 is an incomplete map
int LastRun = -1;
int totalPoints = 0;
int PBPoints = 0; //session PB

string curMap = "";
//int LastStart = -1; this was used in an old version of GiveUpTracker()
//bool GaveUp = false; this was used in an old version of GiveUpTracker()
bool spawnLatch = false;
bool resetProtection = false;

//ui variables
vec2 scale = vec2(100, 40);
vec4 warningColor = vec4(1, 0.1, 0.1, 1.0); //red
float disabledHue = 336.0;
float disabledSat = 0.98;
float disabledVal = 0.31;
float enabledHue = 336.0;
float enabledSat = 0.95;
float enabledVal = 0.80;

void Main()
{
    print("Loaded 1LC - One-Life Challenge!");
    CTrackMania@ app = cast<CTrackMania>(GetApp());

    //define the map as the current map
    auto map = app.RootMap;
    while(true){
        //print("WindowVisible: "+ WindowVisible);
        if(PowerSwitch){
        tempPoints = GetMedalEarned();
        if(tempPoints > 0 && !RespawnTracker()){
            totalPoints += tempPoints;;
            if(verboseMode){print("Total points: " + totalPoints);}
            tempPoints = 0;
        }
        }
        yield();
    }


}

int GetMedalEarned(){
    auto app = cast<CTrackMania>(GetApp());
    CGamePlayground@ playground = cast<CGamePlayground>(app.CurrentPlayground);
    CSmArenaRulesMode@ script = cast<CSmArenaRulesMode>(app.PlaygroundScript);
    auto map = app.RootMap;
    int medal = 0;
    int authorTime = -1;
    int goldTime = -1;
    int silverTime = -1;
    int bronzeTime = -1;
    int time = -1;

    //set function vars for each medal time whenever a map is loaded
    if(map!is null){
    authorTime = map.TMObjective_AuthorTime;
    goldTime = map.TMObjective_GoldTime;
    silverTime = map.TMObjective_SilverTime;
    bronzeTime = map.TMObjective_BronzeTime;
    }

    //if a map is finished, get the completion time & set time = completion time
    if (playground !is null && script !is null && playground.GameTerminals.Length > 0) {
            CSmPlayer@ player = cast<CSmPlayer>(playground.GameTerminals[0].ControlledPlayer);
            GiveUpTracker();

            if (player !is null) {
                auto UISequence = playground.GameTerminals[0].UISequence_Current;
                bool finished = UISequence == SGamePlaygroundUIConfig::EUISequence::Finish;

                if (HandledRun && !finished) {
                    HandledRun = false;
                } else if (!HandledRun && finished) {
                    CSmScriptPlayer@ playerScriptAPI = cast<CSmScriptPlayer>(player.ScriptAPI);
                    auto ghost = script.Ghost_RetrieveFromPlayer(playerScriptAPI);

                    if (ghost !is null) {
                        if (ghost.Result.Time > 0 && ghost.Result.Time < uint(-1)) time = ghost.Result.Time;
                        script.DataFileMgr.Ghost_Release(ghost.Id);
                    }
                }
            }
    }

    if (HandledRun || resetProtection) {
                return 0;
    } else if (time != -1) {
                // run finished, points: nomedal = 1, bronze = 2, silver = 3, gold = 4, author = 5
                if(time <= authorTime) medal = 5;
                else if(time <= goldTime) medal = 4;
                else if(time <= silverTime) medal = 3;
                else if(time <= bronzeTime) medal = 2;
                else medal = 1;

                HandledRun = true;
                LastRun = time;
                //if (GaveUp){
                //    return 0;
                //}
                MXRandom::LoadRandomMap();
                return medal;
    }
    return 0;
}

void ResetPoints(){
    //check if current point value is your session PB
    if (totalPoints > PBPoints){
        PBPoints = totalPoints;
        if(verboseMode){print("New Session PB: " + PBPoints);}
        if(PBPoints > AllTimeBest){
            AllTimeBest = PBPoints;
            if(verboseMode){print("New All Time Best: " + AllTimeBest);}
        }
    }
    totalPoints = 0;
    if(verboseMode){print("Points reset to 0");}
}

bool RespawnTracker(){
    auto app = cast<CTrackMania>(GetApp());
    CGamePlayground@ playground = cast<CGamePlayground>(app.CurrentPlayground);
    CSmArenaRulesMode@ script = cast<CSmArenaRulesMode>(app.PlaygroundScript);
    CSmPlayer@ player = cast<CSmPlayer>(playground.GameTerminals[0].ControlledPlayer);
    CSmScriptPlayer@ playerScriptAPI = cast<CSmScriptPlayer>(player.ScriptAPI);
    CSmArenaScore@ playerScore = cast<CSmArenaScore>(playerScriptAPI.Score);


    auto map = app.RootMap;
    if (map is null){
        return false;
    }
    else {
        int CPRespawns = playerScore.NbRespawnsRequested;
        if (CPRespawns > 0){
            if(verboseMode){print("Respawns: " + CPRespawns + ", calling ResetPoints()");}
            ResetPoints();
        }
        else {
            return false;
        }
    }
    return true;
}

void GiveUpTracker(){
    auto app = cast<CTrackMania>(GetApp());
    auto map = app.RootMap;
    auto RaceData = MLFeed::GetRaceData_V4();
    try{
    auto player = cast<MLFeed::PlayerCpInfo_V4>(RaceData.SortedPlayers_Race[0]);
        MLFeed::SpawnStatus currentSpawnStatus = player.SpawnStatus;

        // If the player is in spawning state, check if there was a map change. If so, set the latch to true.
        if (currentSpawnStatus == MLFeed::SpawnStatus::Spawning && map.MapInfo.MapUid != curMap) {
            spawnLatch = true;
            resetProtection = false;
            curMap = map.MapInfo.MapUid;
            if(verboseMode){print("Map changed, latch set.");}
        }
        // If there was NOT a map change, the player IS in spawning state, AND the latch is true, return nothing.
        else if (currentSpawnStatus == MLFeed::SpawnStatus::Spawning && spawnLatch) {
            if(verboseMode){print("Player is spawning, latch is true. Returning.");}
            return;
        }
        // If the latch is true, check if the player is NOT in the spawning state. If so, set the latch to false.
        else if (spawnLatch && currentSpawnStatus != MLFeed::SpawnStatus::Spawning) {
            spawnLatch = false;
            if(verboseMode){print("Player is no longer spawning, latch reset.");}
        }
        // If the latch is false AND the player is in spawning state, reset points.
        else if (!spawnLatch && currentSpawnStatus == MLFeed::SpawnStatus::Spawning) {
            ResetPoints();
            resetProtection = true;
            if(verboseMode){print("Player is spawning, latch is false. Points reset.");}
        }
    }
    catch{
        return;
    }
}

/*
void GiveUpTracker(){
    auto app = cast<CTrackMania>(GetApp());
    auto map = app.RootMap;
    int CurStart = -1;

    CGamePlayground@ playground = cast<CGamePlayground>(app.CurrentPlayground);
    CSmArenaRulesMode@ script = cast<CSmArenaRulesMode>(app.PlaygroundScript);
    auto UISequence = playground.GameTerminals[0].UISequence_Current;

    //loadlatch is used to prevent the script from running before the map is loaded
    //auto loadProgress = GetApp().LoadProgress;
    if (UISequence != SGamePlaygroundUIConfig::EUISequence::Playing){
        loadLatch = true;
        print("latch set, UISequence = " + UISequence);
    }

    //print(UISequence);

    CSmPlayer@ player = cast<CSmPlayer>(playground.GameTerminals[0].ControlledPlayer);
    try{
    CSmScriptPlayer@ playerScriptAPI = cast<CSmScriptPlayer>(player.ScriptAPI);
        CurStart = playerScriptAPI.StartTime;
        string mapid = map.MapInfo.MapUid;
    
        if(mapid != curMap && UISequence == SGamePlaygroundUIConfig::EUISequence::Playing){
            //process map change
            if (CurStart == LastStart){
                return;
            }
            if (CurStart != -1 && loadLatch){
                    GaveUp = false;
                    loadLatch = false;
                    curMap = mapid;
                    LastStart = CurStart;
                    print(UISequence);
                    print("Map ID: " + mapid);
                    print("Map changed, LastStart: " + LastStart);
            } 
            else {
                return;
            }
        }
        else if(mapid == curMap) {
            //if the map is the same, check if the start time is different
            print("Scenario 1");
            if(CurStart != LastStart && UISequence == SGamePlaygroundUIConfig::EUISequence::Playing){
                //if the start time is different, reset points
                    ResetPoints();
                    print("CurStart: " + CurStart + ", LastStart: " + LastStart);
                    print("Gave up, calling ResetPoints()");
                    print(UISequence);
               GaveUp = true;
            }
        } //the below is for testing!
        else {
            print("We escaped somehow.");
            return;
        }
    }
    catch {
        return;
    }
    
    return;
    //print (playerScriptAPI.StartTime);
}
*/

void Render(){
    if (WindowVisible) {
        UI::Begin("1LC", UI::WindowFlags::AlwaysAutoResize);
        UI::Text("Total Points: " + totalPoints);
        UI::Text("Personal Best: " + AllTimeBest);

        if(!PowerSwitch){
            //challenge stopped
            if(UI::ButtonColored("Start", enabledHue , enabledSat, enabledVal, scale)){
                MXRandom::LoadRandomMap();
                PowerSwitch = true;
                UI::End();
                return;
            }
            UI::ButtonColored("Stop", disabledHue , disabledSat, disabledVal, scale);
            UI::ButtonColored("Skip Map", disabledHue , disabledSat, disabledVal, scale);
        }
        else {
            //challenge started
            UI::ButtonColored("Start", disabledHue , disabledSat, disabledVal, scale);
            if(UI::ButtonColored("Stop", enabledHue , enabledSat, enabledVal, scale)){
                ResetPoints();
                PowerSwitch = false;
                UI::End();
                return;
            }
            if (UI::Button("Skip Map", scale)){
                MXRandom::LoadRandomMap();
            }
        }

        
        UI::End();
    }
}

void RenderMenu()
{
    CTrackMania@ app = cast<CTrackMania>(GetApp());
    auto map = app.RootMap;

    if(debugMode){if(UI::BeginMenu(Icons::Heart + "1LC - One-Life Challenge")){
        
        if (UI::MenuItem("1LC - Reset Run DEBUG")) {
            ResetPoints();
        }

        if (UI::MenuItem("1LC - Reset PB (PERMANENT!)")){
            if(verboseMode){print("Personal Best was " + AllTimeBest + ", reset to 0");}
            UI::ShowNotification("One-Life Challenge", "Your Personal Best was " + AllTimeBest + ". It has now been reset to 0.", warningColor,  5000);
            AllTimeBest = 0;
        }

        if (UI::MenuItem("1LC - Next Random Map DEBUG")) {
            MXRandom::LoadRandomMap();
        }
        UI::EndMenu();
    }}
}