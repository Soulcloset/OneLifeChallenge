[Setting hidden]
bool WindowVisible = true;

[Setting hidden]
bool AnySkip = false;

[Setting hidden]
uint skipThreshold = 180000; //3 minutes is 180000

[Setting hidden]
bool allowCustom = false; //determines whether to allow custom parameters to affect 1LC map selections

[Setting hidden]
bool debugMode = false;

[Setting hidden]
bool verboseMode = false; //debug mode for testing;

[Setting hidden]
int ClassicBest = 0; //personal best from Classic Mode, saved to settings

[Setting hidden]
int PBSkips = 0; //number of skips that have been used in the ClassicBest run in Classic Mode

[Setting hidden]
int ProgressiveBest = 0; //personal best from Progressive Mode, saved to settings

[SettingsTab name="Gameplay" order="0" icon="Gamepad"]
void RenderGameplayTab(){
    if(UI::Button("Reset to default")){
        AnySkip = false;
        skipThreshold = 180000; 
        allowCustom = false;
    }
    UI::SameLine();
    WindowVisible = UI::Checkbox("Show/Hide Window", WindowVisible);
    UI::Separator();
    AnySkip = UI::Checkbox("Unrestricted Skips", AnySkip);
    if(!AnySkip){
        //UI::Text("Minimum map length that can be skipped for free (and without using a Skip Token if available):");
        skipThreshold = UI::InputInt("Skip Threshold", skipThreshold, 1);
        UI::TextWrapped("You may skip maps with an Author time of " + (Time::Format(skipThreshold, true, true, false, true)) + " or longer without using a Skip Token.");
    }
    allowCustom = UI::Checkbox("Allow Custom RMC Parameters", allowCustom);
    if(allowCustom && MXRandom::get_WithCustomParameters()){
        UI::TextWrapped("You are currently using custom search parameters. Visit ManiaExchange Random Map Picker's settings to change or disable.");
    }
}

[SettingsTab name="Developers" order="1" icon="Code"]
void RenderDevelopersTab(){
    if(UI::Button("Reset to default")){
        debugMode = false;
        verboseMode = false;
    }
    UI::Separator();
    debugMode = UI::Checkbox("Debug Mode", debugMode);
    verboseMode = UI::Checkbox("Verbose Logging", verboseMode);
}