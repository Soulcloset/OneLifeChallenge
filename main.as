/*
    One-Life Challenge
    by Soulcloset
*/

[Setting category="General" name="Show/Hide Window" description="When checked, the 1LC window will be visible."]
bool WindowVisible = true;

[Setting category="Gameplay" name="Unrestricted Skips" description="When checked, all maps can be skipped without penalty. When unchecked, you may only skip maps that are longer than the skip threshold."]
bool AnySkip = false;

[Setting category="Gameplay" name="Skip Threshold" description="Minimum length a map must have to be skippable without penalty. Default is 3 minutes, times are expressed as hh:mm:ss.mmm without symbols or leading zeroes (ex. 3m45s678ms is 345678)." min=1000]
uint skipThreshold = 300000; //3 minutes is 300000

[Setting category="Developers" name="Debug Mode" description="Enable/disable debug mode for 1LC. This will show the debug options in the Openplanet Plugins menu, including the ability to reset your personal best permanently."]
bool debugMode = false;

[Setting category="Developers" name="Verbose Mode" description="Enable/disable verbose logging to the Openplanet console (Warning: this will spam the console)"]
bool verboseMode = false; //debug mode for testing;

[Setting hidden]
int AllTimeBest = 0;

[Setting hidden]
int PBSkips = 0; //number of skips that have been used in the AllTimeBest run

bool PowerSwitch = false;
bool HandledRun = false;
int curTime = -1;
int tempPoints = 0; //0 is an incomplete map
int LastRun = -1;
int totalPoints = 0;
int PBPoints = 0; //session PB
int curAuthor = -1;
int curSkips = 0;
string medalMessage = "";
string PBSkipString = " skips)";

string curMap = "";
bool spawnLatch = false;
bool resetProtection = false;

//ui variables
vec2 scale = vec2(100, 40);
vec4 warningColor = vec4(0.9, 0.1, 0.1, 0.8); //red
vec4 successColor = vec4(0.1, 0.9, 0.1, 0.8); //green
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
        if(PowerSwitch){
        tempPoints = GetMedalEarned();
        if(tempPoints > 0 && !RespawnTracker()){
            totalPoints += tempPoints;
            medalNotification(totalPoints);
            if(verboseMode){print("Total points: " + totalPoints);}
            tempPoints = 0;
        }
        }
        yield();
    }


}

int GetMedalEarned(){
    //portion of this function is taken from MXRandom, with permission from Fort (ty!)
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
    curAuthor = authorTime;
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
                if(time <= authorTime) {medal = 5;}
                else if(time <= goldTime) {medal = 4;}
                else if(time <= silverTime) {medal = 3;}
                else if(time <= bronzeTime) {medal = 2;}
                else medal = 1;

                HandledRun = true;
                LastRun = time;

                MXRandom::LoadRandomMap();
                return medal;
    }
    return 0;
}

void medalNotification(int medal){
    //this function will be used to show a notification when a medal is earned
    if (medal == 1){
        UI::ShowNotification("One-Life Challenge", "You finished the map!", successColor,  5000);
    }
    else if (medal == 2){
        UI::ShowNotification("One-Life Challenge", "You earned a Bronze Medal!", successColor,  5000);
    }
    else if (medal == 3){
        UI::ShowNotification("One-Life Challenge", "You earned a Silver Medal!", successColor,  5000);
    }
    else if (medal == 4){
        UI::ShowNotification("One-Life Challenge", "You earned a Gold Medal!", successColor,  5000);
    }
    else if (medal == 5){
        UI::ShowNotification("One-Life Challenge", "You earned an Author Medal!", successColor,  5000);
    }
    else{
        return;
    }
    return;
}

void ResetPoints(){
    //check if current point value is your session PB
    if (totalPoints > PBPoints){
        PBPoints = totalPoints;
        if(verboseMode){print("New Session PB: " + PBPoints);}
        if(PBPoints > AllTimeBest){
            AllTimeBest = PBPoints;
            PBSkips = curSkips;
            Meta::SaveSettings();
            UI::ShowNotification("One-Life Challenge", "GG! Your new Personal Best is " + AllTimeBest + ".", successColor,  10000);
            if(verboseMode){print("New All Time Best: " + AllTimeBest);}
        }
    }
    totalPoints = 0;
    curSkips = 0;
    PowerSwitch = false;
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
            UI::ShowNotification("One-Life Challenge", "You respawned! Your run has ended with " + totalPoints + " points.", warningColor,  10000);
            ResetPoints();
            //PowerSwitch = false;
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
            UI::ShowNotification("One-Life Challenge", "You respawned! Your run has ended with " + totalPoints + " points.", warningColor,  10000);
            ResetPoints();
            resetProtection = true;
            if(verboseMode){print("Player is spawning, latch is false. Points reset.");}
        }
    }
    catch{
        return;
    }
}

bool SkipCheck(){
    //this function will be used to check whether the current map can be skipped without penalty. True = it can, False = it cannot.
    if(AnySkip){
        return true;
    }
    CTrackMania@ app = cast<CTrackMania>(GetApp());
    auto map = app.RootMap;
    if(map !is null){
        if(map.TMObjective_AuthorTime > skipThreshold){
            //if(verboseMode){print("SkipCheck Scenario 1");}
            return true; //map is longer than threshold, can be skipped
        }
        else {
            //if(verboseMode){print("SkipCheck Scenario 2");}
            return false; //map is shorter than threshold, cannot be skipped
        }
    }
    else {
        //if(verboseMode){print("SkipCheck Scenario 3");}
        return false; //no map loaded, cannot be skipped
    }
}

void Render(){
    if (WindowVisible) {
        UI::Begin("1LC", UI::WindowFlags::AlwaysAutoResize);
        UI::Text("Total Points: " + totalPoints);
        if(PBSkips > 0){
            UI::Text("Personal Best: " + AllTimeBest + " (" + PBSkips + PBSkipString);
        }
        else {
            UI::Text("Personal Best: " + AllTimeBest);
        }

        if(!PowerSwitch){
            //challenge stopped
            if(UI::ButtonColored("Start", enabledHue , enabledSat, enabledVal, scale)){
                MXRandom::LoadRandomMap();
                if(verboseMode){print("Challenge started!");}
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
                UI::End();
                return;
            }
            if(SkipCheck()){
                if (UI::ButtonColored("Skip Map", enabledHue , enabledSat, enabledVal, scale)){
                    if(verboseMode){print("Attempted to skip, map time: " + curAuthor);}
                    curSkips += 1;
                    MXRandom::LoadRandomMap();
                }
            }
            else {
                UI::ButtonColored("Skip Map", disabledHue , disabledSat, disabledVal, scale);
            }

            
        }

        
        UI::End();
    }
}

void RenderMenu()
{
    CTrackMania@ app = cast<CTrackMania>(GetApp());
    auto map = app.RootMap;

    if(debugMode){if(UI::BeginMenu(Icons::Heart + " 1LC - One-Life Challenge")){
        
        if (UI::MenuItem("1LC - Reset Run DEBUG")) {
            ResetPoints();
        }

        if (UI::MenuItem("1LC - Reset PB (PERMANENT!)")){
            if(verboseMode){print("Personal Best was " + AllTimeBest + ", reset to 0");}
            UI::ShowNotification("One-Life Challenge", "Your Personal Best was " + AllTimeBest + ". It has now been reset to 0.", warningColor,  5000);
            AllTimeBest = 0;
            Meta::SaveSettings();
        }

        if (UI::MenuItem("1LC - Next Random Map DEBUG")) {
            MXRandom::LoadRandomMap();
        }
        UI::EndMenu();
    }}
}