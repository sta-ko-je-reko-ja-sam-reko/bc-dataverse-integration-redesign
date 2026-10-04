namespace DataverseIntegration.Core;

using System.Environment.Configuration;

codeunit 80002 "DVI App Area Subscriber"
{
    Access = Internal;
    SingleInstance = true;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Application Area Mgmt. Facade", OnGetEssentialExperienceAppAreas, '', true, true)]
    local procedure SetAppAreasOnGetEssentialExperienceAppAreas(var TempApplicationAreaSetup: Record "Application Area Setup" temporary)
    var
        FeatureMgt: Codeunit "DVI Feature Mgt.";
    begin
        TempApplicationAreaSetup."DVI Redesign" := FeatureMgt.IsEnabled();
    end;
}
