/*
    One-Life Challenge
    by Soulcloset
*/

const bool mapAccess = Permissions::PlayLocalMap(); //can the current login load arbitrary maps?

bool ClassicActive = false; //formerly PowerSwitch, marks whether classic mode is active
bool ProgressiveActive = false; //marks whether progressive mode is active

bool HandledRun = false;
int curTime = -1;
int tempPoints = 0; //0 is an incomplete map
int totalPoints = 0; //current run's running point total
int PBPoints = 0; //session PB
int curAuthor = -1;
int curSkips = 0;
int classicPBSource = ClassicBest;
bool SettingsModified = false; //used to check if the settings have been modified from defaults in the current run

string curMap = "";
bool spawnLatch = false;
bool resetProtection = false;

//gameplay variables
int SkipTokens = 0; //Progressive Mode number of free skips available
int mapCounter = 0; //counts how many maps have been played this run
int skipReason = 0; //0 = longer than threshold, 1 = skip token should be used
int progMessageCounter = 0;
int curLevel = 0; //level counter for progressive mode
string progStatus = "Complete your first map!";

//ui variables
vec4 warningColor = vec4(0.9, 0.1, 0.1, 0.8); //red
vec4 successColor = vec4(0.1, 0.9, 0.1, 0.8); //green


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
        MXRandom::LoadRandomMap(allowCustom);
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
    int goldTime = -1;
    int silverTime = -1;
    int bronzeTime = -1;
    int time = -1;

    //set function vars for each medal time whenever a map is loaded
    if(map!is null){
    curAuthor = map.TMObjective_AuthorTime;
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
                if(time <= curAuthor) {
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
        if(PBPoints > ClassicBest){
            ClassicBest = PBPoints;
            PBPoints = 0;
            Meta::SaveSettings();
            UI::ShowNotification("One-Life Challenge", "GG! Your new Personal Best is " + ClassicBest + ".", successColor,  10000);
            if(verboseMode){print("New Classic Mode Best: " + ClassicBest);}
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
        if (ClassicActive){
            PBSkips = curSkips;
        }
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
    classicPBSource = ClassicBest;
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
    if(AnySkip != false || skipThreshold != 180000 || (MXRandom::get_WithCustomParameters() && allowCustom)){
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
    if (level >= 21){
        val = 230 + ((level - 20) * 14);
        return val;
        
    }
    else if (level >= 11){
        val = 100 + ((level - 10) * 13);
        return val;
    }
    for (int i = 2; i <= level; i++) {
        val += diff;
        if(i < 10){
            diff += 1;
        }
    }
    return val;
}

int GetSkipCost(int count){
    int val = 5 * (count + 1);
    return val;
}