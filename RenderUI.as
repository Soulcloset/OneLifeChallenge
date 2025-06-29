//ui variables
vec2 scale = vec2(100, 40);
vec2 bigScale = vec2(210,40);
float[] disabledColor = {336.0, 0.98, 0.31}; //hue, saturation, value
float[] enabledColor = {0.9472f, 0.87f, 0.86f};
float[] skippableColor = {0.33f, 0.6f, 0.6f};
float[] unskippableColor = {0.2677f, 0.98f, 0.17f};

void Render(){
    if(!mapAccess){return;}
    auto app = cast<CTrackMania>(GetApp());
    auto map = app.RootMap;
    auto RaceData = MLFeed::GetRaceData_V4();

    if (WindowVisible) {

        UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(10, 10));
        UI::PushStyleVar(UI::StyleVar::WindowRounding, 10.0);
        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(10, 6));
        UI::PushStyleVar(UI::StyleVar::WindowTitleAlign, vec2(.5, .5));

        UI::Begin("One-Life Challenge", UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoScrollbar | UI::WindowFlags::NoCollapse | UI::WindowFlags::NoResize);
        
        if(SettingsModified){
            UI::Text(Icons::Times + "Settings Modified");
        }
        if(curLevel > 20){
            UI::Text(Icons::ThermometerFull + "Endless Mode");
        }
        else if(curLevel > 10){
            UI::Text(Icons::LongArrowUp + "Endless Mode");
        }

        if(ClassicActive || ProgressiveActive){
            UI::Text("Total Points: " + totalPoints);
        }
        else {
            UI::Text("Choose a Mode:");
            if(PBSkips > 0){
                UI::Text("Classic PB: " + ClassicBest + " (" + PBSkips + " skips)");
            }
            else {
                UI::Text("Classic PB: " + ClassicBest);
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
            if(UI::ButtonColored("Classic", enabledColor[0], enabledColor[1], enabledColor[2], scale)){
                try{
                    auto player = cast<MLFeed::PlayerCpInfo_V4>(RaceData.SortedPlayers_Race[0]);
                    MLFeed::SpawnStatus currentSpawnStatus = player.SpawnStatus;

                    if(MXRandom::get_WithCustomParameters() && allowCustom){
                        UI::ShowNotification("One-Life Challenge", "You have custom RMC search parameters enabled. This will affect your One-Life Challenge map selections.", warningColor,  5000);
                    }

                    if(currentSpawnStatus == MLFeed::SpawnStatus::Spawning){
                        UI::ShowNotification("One-Life Challenge", "You cannot start the challenge while spawning! Try again.", warningColor,  5000);
                        if(verboseMode){print("Attempted to start while spawning!");}
                        EndUI();
                        return;
                    }
                    else{
                        NextMap();
                        if(verboseMode){print("Classic started!");}
                        ClassicInit();
                        ClassicActive = true;
                        EndUI();
                        return;
                    }
                }
                catch{
                    NextMap();
                    if(verboseMode){print("Classic started! (scenario 2)");}
                    ClassicInit();
                    ClassicActive = true;
                    EndUI();
                    return;                
                }
                
            }
            UI::SameLine();
            if(UI::ButtonColored("Challenge", enabledColor[0] , enabledColor[1], enabledColor[2], scale)){
                try{
                    auto player = cast<MLFeed::PlayerCpInfo_V4>(RaceData.SortedPlayers_Race[0]);
                    MLFeed::SpawnStatus currentSpawnStatus = player.SpawnStatus;

                    if(MXRandom::get_WithCustomParameters() && allowCustom){
                        UI::ShowNotification("One-Life Challenge", "You have custom RMC search parameters enabled. This will affect your One-Life Challenge map selections.", warningColor,  10000);
                    }

                    if(currentSpawnStatus == MLFeed::SpawnStatus::Spawning){
                        UI::ShowNotification("One-Life Challenge", "You cannot start the challenge while spawning! Try again.", warningColor,  10000);
                        if(verboseMode){print("Attempted to start while spawning!");}
                        EndUI();
                        return;
                    }
                    else{
                        NextMap();
                        if(verboseMode){print("Progressive started!");}
                        ProgressiveInit();
                        ProgressiveActive = true;
                        EndUI();
                        return;
                    }
                }
                catch{
                    NextMap();
                    if(verboseMode){print("Progressive started! (scenario 2)");}
                    ProgressiveInit();
                    ProgressiveActive = true;
                    EndUI();
                    return;                
                }
                
            }
            
        }
        else if(ClassicActive) {
            //Classic started
            SettingsCheck();
            if(PBPoints > ClassicBest){
                classicPBSource = PBPoints;
            }
            else {
                classicPBSource = ClassicBest;
            }
            
            if (PBSkips > 0){
                    UI::Text("Classic PB: " + classicPBSource + " (" + PBSkips + " skips)");
            }
            else{
                    UI::Text("Classic PB: " + classicPBSource);
            }

            if(UI::ButtonColored("Stop", enabledColor[0] , enabledColor[1], enabledColor[2], bigScale)){
                ResetPoints();
                EndUI();
                return;
            }
            if(SkipCheck()){
                if (UI::ButtonColored("Free Skip", skippableColor[0] , skippableColor[1], skippableColor[2], scale)){
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
                UI::ButtonColored("Free Skip", unskippableColor[0] , unskippableColor[1], unskippableColor[2], scale);
            }
            UI::SameLine();
            if(totalPoints > GetSkipCost(curSkips)) {
                if (UI::ButtonColored(GetSkipCost(curSkips) + "-Point Skip", skippableColor[0] , skippableColor[1], skippableColor[2], scale)){
                    if(verboseMode){print("Attempted to 5-point skip, map time: " + curAuthor);}
                    totalPoints -= GetSkipCost(curSkips);
                    curSkips += 1;
                    NextMap();
                }
            }
            else {
                UI::ButtonColored(GetSkipCost(curSkips) + "-Point Skip", unskippableColor[0] , unskippableColor[1], unskippableColor[2], scale);
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
            
            UI::SeparatorTextOpenplanet("Level " + curLevel);
            UI::PushTextWrapPos(215.0);
            UI::Text(progStatus);
            UI::PopTextWrapPos();

            if(UI::ButtonColored("Stop", enabledColor[0] , enabledColor[1], enabledColor[2], bigScale)){
                ResetPoints();
                EndUI();
                return;
            }
            //add skip token logic
            if(SkipCheck()){
                if (UI::ButtonColored("Free Skip", skippableColor[0] , skippableColor[1], skippableColor[2], scale)){
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
                UI::ButtonColored("Free Skip", unskippableColor[0] , unskippableColor[1], unskippableColor[2], scale);
            }
            UI::SameLine();
            if(totalPoints > 5) {
                if (UI::ButtonColored("5-Point Skip", skippableColor[0] , skippableColor[1], skippableColor[2], scale)){
                    if(verboseMode){print("Attempted to 5-point skip, map time: " + curAuthor);}
                    curSkips += 1;
                    totalPoints -= 5;
                    NextMap();
                }
            }
            else {
                UI::ButtonColored("5-Point Skip", unskippableColor[0] , unskippableColor[1], unskippableColor[2], scale);
            }
        }
        EndUI();
    }
}

void EndUI(){
    UI::End();
    UI::PopStyleVar(4);
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
            if(verboseMode){print("Personal Best was " + ClassicBest + ", reset to 0");}
            UI::ShowNotification("One-Life Challenge", "Your Personal Best was " + ClassicBest + ". It has now been reset to 0.", warningColor,  5000);
            ClassicBest = 0;
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