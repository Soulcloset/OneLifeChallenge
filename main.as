/*
    One-Life Challenge
    by Soulcloset

    TODO:
    - Move skip settings to Developers tab & make skipThreshold conditional on AnySkip being false
        - learn how to display text in settings menu?
*/

[Setting category="General" name="Show/Hide Window" description="When checked, the 1LC window will be visible."]
bool WindowVisible = true;

[Setting category="Gameplay" name="Unrestricted Skips" description="When checked, all maps can be skipped without penalty. When unchecked, you may only skip maps that are longer than the skip threshold."]
bool AnySkip = false;

[Setting category="Gameplay" name="Skip Threshold" description="Minimum length a map must have to be skippable without penalty. Default is 3 minutes, time in milliseconds. (ex. 60000 = 1 minute, 180000 = 3 minutes, 300000 = 5 minutes, etc.)" min=1000]
uint skipThreshold = 180000; //3 minutes is 180000

[Setting category="Developers" name="Debug Mode" description="Enable/disable debug mode for 1LC. This will show the debug options in the Openplanet Plugins menu, including the ability to reset your personal best permanently."]
bool debugMode = false;

[Setting category="Developers" name="Verbose Mode" description="Enable/disable verbose logging to the Openplanet console. (Warning: this will spam the console)"]
bool verboseMode = false; //debug mode for testing;

[Setting hidden]
int AllTimeBest = 0; //personal best from Classic Mode, saved to settings

[Setting hidden]
int PBSkips = 0; //number of skips that have been used in the AllTimeBest run in Classic Mode

[Setting hidden]
int ProgressiveBest = 0; //personal best from Progressive Mode, saved to settings

const bool mapAccess = Permissions::PlayLocalMap(); //can the current login load arbitrary maps?

bool ClassicActive = false; //formerly PowerSwitch, marks whether classic mode is active
bool ProgressiveActive = false; //marks whether progressive mode is active

bool HandledRun = false;
int curTime = -1;
int tempPoints = 0; //0 is an incomplete map
int LastRun = -1;
int totalPoints = 0; //current run's running point total
int PBPoints = 0; //session PB
int curAuthor = -1;
int curSkips = 0;
string medalMessage = "";
string PBSkipString = " skips)";
bool SettingsModified = false; //used to check if the settings have been modified from defaults in the current run

string curMap = "";
bool spawnLatch = false;
bool resetProtection = false;

//progressive mode variables
int SkipTokens = 0; //Progressive Mode number of free skips available
int mapCounter = 0; //counts how many maps have been played this run
int skipReason = 0; //0 = longer than threshold, 1 = skip token should be used
int progMessageCounter = 0;
int curLevel = 0; //level counter for progressive mode
string progStatus = "Complete your first map!";

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
    if(!mapAccess){
        UI::ShowNotification("One-Life Challenge", "Club Access is required to play One-Life Challenge!", warningColor,  10000);
        return;
    }
    else{
        if(verboseMode){print("Verified that the user has Standard or Club Access, enabled plugin.");}
    }
    
    print("Loaded 1LC - One-Life Challenge!");
    CTrackMania@ app = cast<CTrackMania>(GetApp());

    //define the map as the current map
    auto map = app.RootMap;
    
    while(true){
        if(ClassicActive){
            ProgressiveActive = false;
            tempPoints = GetMedalEarned();
            if(tempPoints > 0 && !RespawnTracker()){
                totalPoints += tempPoints;
                medalNotification(tempPoints);
                if(verboseMode){print("Total points: " + totalPoints);}
                NextMap();
                tempPoints = 0;
            }
        }
        if(ProgressiveActive){
            ClassicActive = false;
            tempPoints = GetMedalEarned();
            if(tempPoints > 0 && !RespawnTracker()){
                totalPoints += tempPoints;
                medalNotification(tempPoints);
                progMessageCounter--;
                if(verboseMode){print("Total points: " + totalPoints);}
                mapCounter++;
                if(verboseMode){print("Map count incremented: " + mapCounter);}
                updateProgressiveStatus();
                if(verboseMode){print("progStatus: " + progStatus);}
                NextMap();
                tempPoints = 0;
            }
        }
        yield();
    }


}

void NextMap(){
    //called any time a random map is needed, to consolidate permissions checking
    if(!mapAccess){return;}
    else{
        MXRandom::LoadRandomMap();
        SessionPBUpdate();
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
                if(time <= authorTime) {
                    medal = 5;
                    if(ProgressiveActive){
                        SkipTokens++;
                        if(verboseMode){print("Skip token added! Total: " + SkipTokens);}
                    }
                }
                else if(time <= goldTime) {
                    medal = 4;
                    if(ProgressiveActive){
                        SkipTokens++;
                        if(verboseMode){print("Skip token added! Total: " + SkipTokens);}
                    }
                }
                else if(time <= silverTime) {medal = 3;}
                else if(time <= bronzeTime) {medal = 2;}
                else medal = 1;

                HandledRun = true;
                LastRun = time;

                //NextMap();
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
        if(ProgressiveActive){UI::ShowNotification("One-Life Challenge", "You earned a Gold Medal and 1 Skip Token!", successColor,  5000); return;}
        UI::ShowNotification("One-Life Challenge", "You earned a Gold Medal!", successColor,  5000);
    }
    else if (medal == 5){
        if(ProgressiveActive){UI::ShowNotification("One-Life Challenge", "You earned an Author Medal and 1 Skip Token!", successColor,  5000); return;}
        UI::ShowNotification("One-Life Challenge", "You earned an Author Medal!", successColor,  5000);
    }
    else{
        return;
    }
    return;
}

void ResetPoints(){
    //check if current point value is your session PB
    SessionPBUpdate();
    if(ClassicActive){
        if(PBPoints > AllTimeBest){
            AllTimeBest = PBPoints;
            PBPoints = 0;
            PBSkips = curSkips;
            Meta::SaveSettings();
            UI::ShowNotification("One-Life Challenge", "GG! Your new Personal Best is " + AllTimeBest + ".", successColor,  10000);
            if(verboseMode){print("New Classic Mode Best: " + AllTimeBest);}
        }
        ClassicInit();
    }
    else if(ProgressiveActive){
        if(PBPoints > ProgressiveBest){
            ProgressiveBest = PBPoints;
            PBPoints = 0;
            Meta::SaveSettings();
            UI::ShowNotification("One-Life Challenge", "GG! Your new Personal Best is " + ProgressiveBest + ".", successColor,  10000);
            if(verboseMode){print("New Progressive Mode Best: " + ProgressiveBest);}
        }
        ProgressiveInit();
    }
    ClassicActive = false;
    ProgressiveActive = false;
    SettingsModified = false;
    if(verboseMode){print("Points reset to 0");}
}

void SessionPBUpdate(){
    if (totalPoints > PBPoints){
        PBPoints = totalPoints;
        if(verboseMode){print("New Session PB saved: " + PBPoints);}
    }
}

void ProgressiveInit(){
    totalPoints = 0;
    curSkips = 0;
    SkipTokens = 0;
    progMessageCounter = 0;
    mapCounter = 0;
    curLevel = 0;
    progStatus = "Complete your first map!";
    PBPoints = 0;
}

void ClassicInit(){
    totalPoints = 0;
    curSkips = 0;
    SkipTokens = 1;
    mapCounter = 0;
    PBPoints = 0;
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
            //ClassicActive = false;
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
            //if(verboseMode){print("SkipCheck: Skippable due to threshold");}
            skipReason = 0;
            return true; //map is longer than threshold, can be skipped
        }
        else if(SkipTokens > 0){
            //if(verboseMode){print("SkipCheck: Skippable due to Skip Tokens");}
            skipReason = 1;
            return true; //map is skippable due to skip tokens present
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

bool SettingsCheck(){
    //checks if settings have been modified from defaults
    //false = not modified, true = modified
    if(AnySkip != false || skipThreshold != 180000){
        SettingsModified = true;
        return true;
    }
    else{
        return false;
    }
}

void updateProgressiveStatus(){
    if(mapCounter < 3){
        if(mapCounter == 1){
            progMessageCounter = 3;
        }
        progStatus = "Complete " + progMessageCounter + " more map(s) to reveal your next challenge!";
        return;
    }
    else if(mapCounter == 3){
        curLevel = 1;
        progStatus = "Complete " + progMessageCounter + " more map(s) to reveal your next challenge!";
        return;
    }

    /*
    if(verboseMode){print("curLevel: " + curLevel + ", reqArray.length: " + reqArray.Length);}
    if (curLevel >= reqArray.Length) {
        progStatus = "Congratulations! You've completed all challenges. Keep playing for a high score!";
        return;
    }

    int requiredPoints = reqArray[curLevel];
    */
    int requiredPoints = GetPointReq(curLevel);
    int startMap = curLevel * 3 + 1;
    int endMap = startMap + 2;

    if (mapCounter >= startMap && mapCounter <= endMap) {
        if (totalPoints < requiredPoints) {
            progStatus = "Reach " + requiredPoints + " points in the next " + (endMap - mapCounter + 1) + " maps!";
        } 
        else {
            progStatus = "Challenge completed! Keep playing to reveal your next challenge!";
            mapCounter = endMap; // Progress the game after completing the challenge
            curLevel++;
        }
        return;
    }
    else if(mapCounter > endMap){
        if(totalPoints < requiredPoints){
            //you died
            UI::ShowNotification("One-Life Challenge", "Level " + curLevel + " got the best of you! You finished with " + totalPoints + " points.", warningColor,  5000);
            ResetPoints();
        }
        curLevel++;
        updateProgressiveStatus();
    }
}

int GetPointReq(int level) {
    if (level <= 0) return 0;
    if (level == 1) return 10;
    int val = 10;
    int diff = 6;
    for (int i = 2; i <= level; i++) {
        val += diff;
        if(i < 10){
            diff += 1;
        }
    }
    return val;
}

void Render(){
    if(!mapAccess){return;}
    auto app = cast<CTrackMania>(GetApp());
    auto map = app.RootMap;
    auto RaceData = MLFeed::GetRaceData_V4();

    if (WindowVisible) {
        UI::Begin("One-Life Challenge", UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoScrollbar | UI::WindowFlags::NoCollapse | UI::WindowFlags::NoResize);
        
        if(SettingsModified){
            UI::Text(Icons::Times + "Settings Modified");
        }

        if(ClassicActive || ProgressiveActive){
            UI::Text("Total Points: " + totalPoints);
        }
        else {
            UI::Text("Choose a Mode:");
            if(PBSkips > 0){
                UI::Text("Classic PB: " + AllTimeBest + " (" + PBSkips + PBSkipString);
            }
            else {
                UI::Text("Classic PB: " + AllTimeBest);
            }
            UI::Text("Challenge PB: " + ProgressiveBest);
        }
        if(ClassicActive){
            if(SkipTokens > 0){
                UI::Text("1 Free Skip Available");
            }
        }
        if(ProgressiveActive){
            UI::Text("Skip Tokens: " + SkipTokens);
        }

        
        
        if(!ClassicActive && !ProgressiveActive){
            //challenge stopped
            if(UI::ButtonColored("Classic", enabledHue , enabledSat, enabledVal, scale)){
                try{
                    auto player = cast<MLFeed::PlayerCpInfo_V4>(RaceData.SortedPlayers_Race[0]);
                    MLFeed::SpawnStatus currentSpawnStatus = player.SpawnStatus;
                    if(currentSpawnStatus == MLFeed::SpawnStatus::Spawning){
                        UI::ShowNotification("One-Life Challenge", "You cannot start the challenge while spawning! Try again.", warningColor,  5000);
                        if(verboseMode){print("Attempted to start while spawning!");}
                        UI::End();
                        return;
                    }
                    else{
                        NextMap();
                        if(verboseMode){print("Classic started!");}
                        ClassicInit();
                        ClassicActive = true;
                        UI::End();
                        return;
                    }
                }
                catch{
                    NextMap();
                    if(verboseMode){print("Classic started!");}
                    ClassicActive = true;
                    UI::End();
                    return;                
                }
                
            }

            if(UI::ButtonColored("Challenge", enabledHue , enabledSat, enabledVal, scale)){
                try{
                    auto player = cast<MLFeed::PlayerCpInfo_V4>(RaceData.SortedPlayers_Race[0]);
                    MLFeed::SpawnStatus currentSpawnStatus = player.SpawnStatus;
                    if(currentSpawnStatus == MLFeed::SpawnStatus::Spawning){
                        UI::ShowNotification("One-Life Challenge", "You cannot start the challenge while spawning! Try again.", warningColor,  5000);
                        if(verboseMode){print("Attempted to start while spawning!");}
                        UI::End();
                        return;
                    }
                    else{
                        NextMap();
                        if(verboseMode){print("Progressive started!");}
                        ProgressiveInit();
                        ProgressiveActive = true;
                        UI::End();
                        return;
                    }
                }
                catch{
                    NextMap();
                    if(verboseMode){print("Progressive started!");}
                    ProgressiveActive = true;
                    UI::End();
                    return;                
                }
                
            }
            
        }
        else if(ClassicActive) {
            //Classic started
            //UI::ButtonColored("Start", disabledHue , disabledSat, disabledVal, scale);
            SettingsCheck();
            if(PBPoints > AllTimeBest){
                if (curSkips > 0){
                    UI::Text("Classic PB: " + PBPoints + " (" + curSkips + PBSkipString);
                }
                else{
                    UI::Text("Classic PB: " + PBPoints);
                }
            }
            else if(PBSkips > 0){
                UI::Text("Classic PB: " + AllTimeBest + " (" + PBSkips + PBSkipString);
            }
            else {
                UI::Text("Classic PB: " + AllTimeBest);
            }

            if(UI::ButtonColored("Stop", enabledHue , enabledSat, enabledVal, scale)){
                ResetPoints();
                UI::End();
                return;
            }
            if(SkipCheck()){
                if (UI::ButtonColored("Free Skip", enabledHue , enabledSat, enabledVal, scale)){
                    if(verboseMode){print("Attempted to free skip, map time: " + curAuthor + " , Skip Tokens: " + SkipTokens);}
                    if(skipReason == 1){
                        SkipTokens--;
                        if(verboseMode){print("Skip token used! Total: " + SkipTokens);}
                        UI::ShowNotification("One-Life Challenge", "Map skipped!", warningColor,  5000);
                    }
                    NextMap();
                }
            }
            else {
                UI::ButtonColored("Free Skip", disabledHue , disabledSat, disabledVal, scale);
            }

            if(totalPoints > 5) {
                if (UI::ButtonColored("5-Point Skip", enabledHue , enabledSat, enabledVal, scale)){
                    if(verboseMode){print("Attempted to 5-point skip, map time: " + curAuthor);}
                    //SessionPBUpdate();
                    curSkips += 1;
                    totalPoints -= 5;
                    NextMap();
                }
            }
            else {
                UI::ButtonColored("5-Point Skip", disabledHue , disabledSat, disabledVal, scale);
            }

            
        }
        else{
            //Progressive started
            SettingsCheck();
            if(PBPoints > ProgressiveBest){
                UI::Text("Challenge PB: " + PBPoints);
            }
            else {
                UI::Text("Challenge PB: " + ProgressiveBest);
            }
            
            UI::Text("Level " + curLevel);
            UI::PushTextWrapPos(150.0);
            UI::Text(progStatus);
            UI::PopTextWrapPos();

            if(UI::ButtonColored("Stop", enabledHue , enabledSat, enabledVal, scale)){
                ResetPoints();
                UI::End();
                return;
            }
            //add skip token logic
            if(SkipCheck()){
                if (UI::ButtonColored("Free Skip", enabledHue , enabledSat, enabledVal, scale)){
                    if(verboseMode){print("Attempted to free skip, map time: " + curAuthor + " , Skip Tokens: " + SkipTokens);}
                    if(skipReason == 1){
                        SkipTokens--;
                        if(verboseMode){print("Skip token used! Total: " + SkipTokens);}
                        UI::ShowNotification("One-Life Challenge", "Map skipped!", warningColor,  5000);
                    }
                    NextMap();
                }
            }
            else {
                UI::ButtonColored("Free Skip", disabledHue , disabledSat, disabledVal, scale);
            }

            if(totalPoints > 5) {
                if (UI::ButtonColored("5-Point Skip", enabledHue , enabledSat, enabledVal, scale)){
                    if(verboseMode){print("Attempted to 5-point skip, map time: " + curAuthor);}
                    //SessionPBUpdate();
                    curSkips += 1;
                    totalPoints -= 5;
                    NextMap();
                }
            }
            else {
                UI::ButtonColored("5-Point Skip", disabledHue , disabledSat, disabledVal, scale);
            }
        }

        
        UI::End();
    }
}

void RenderMenu()
{
    CTrackMania@ app = cast<CTrackMania>(GetApp());
    auto map = app.RootMap;
    if(!mapAccess){
        if (UI::BeginMenu(Icons::Heart + " 1LC - One-Life Challenge")) {
        UI::Text("Warning: Club Required");
        UI::TextWrapped("Sorry, this plugin won't work because you don't have club access :(");
        UI::EndMenu();
        }
    }

    if(mapAccess){if(UI::BeginMenu(Icons::Heart + " 1LC - One-Life Challenge")){
        
        if(WindowVisible){
            if(UI::MenuItem("Window Visible? " + Icons::Check )){
                WindowVisible = !WindowVisible;
            }
        }
        else {
            if(UI::MenuItem("Window Visible? " + Icons::Times )){
                WindowVisible = !WindowVisible;
            }
        }
        if (UI::MenuItem("1LC - Reset Classic Mode PB (PERMANENT!)")){
            if(verboseMode){print("Personal Best was " + AllTimeBest + ", reset to 0");}
            UI::ShowNotification("One-Life Challenge", "Your Personal Best was " + AllTimeBest + ". It has now been reset to 0.", warningColor,  5000);
            AllTimeBest = 0;
            PBSkips = 0;
            PBPoints = 0;
            Meta::SaveSettings();
        }

        if (UI::MenuItem("1LC - Reset Progressive Mode PB (PERMANENT!)")){
            if(verboseMode){print("Personal Best was " + ProgressiveBest + ", reset to 0");}
            UI::ShowNotification("One-Life Challenge", "Your Personal Best was " + ProgressiveBest + ". It has now been reset to 0.", warningColor,  5000);
            ProgressiveBest = 0;
            PBPoints = 0;
            Meta::SaveSettings();
        }

        if(debugMode){
            if (UI::MenuItem("1LC - Clear Next Progressive Mode Level DEBUG")){
                if(verboseMode){print("Cleared level using debug feature. totalPoints before = " + totalPoints);}
                totalPoints = GetPointReq(curLevel);
                if(verboseMode){print("totalPoints after = " + totalPoints);}
                SettingsModified = true;
            }

            if (UI::MenuItem("1LC - Add 100 Skip Tokens DEBUG")) {
                SkipTokens += 100;
                SettingsModified = true;
            }

            if (UI::MenuItem("1LC - Check Map Access DEBUG")) {
                if(verboseMode){print(mapAccess);}
                UI::ShowNotification("One-Life Challenge", "This login can load arbitrary maps? " + mapAccess, warningColor,  5000);
            }
        }
        UI::EndMenu();
    }}
}