namespace DataverseIntegration.Core;

permissionset 80000 "DVI Full"
{
    Assignable = true;
    Caption = 'Dataverse Integration Redesign - Full', Locked = true;

    Permissions =
        tabledata "DVI Setup" = RIMD,
        table "DVI Setup" = X,
        tabledata "DVI Follow-up Buffer" = RIMD,
        table "DVI Follow-up Buffer" = X,
        tabledata "DVI Option Value" = RIMD,
        table "DVI Option Value" = X,
        tabledata "DVI Mapping Assignment" = RIMD,
        table "DVI Mapping Assignment" = X,
        page "DVI Setup" = X,
        page "DVI Mapping Assignments" = X,
        codeunit "DVI Service Locator" = X,
        codeunit "DVI Feature Mgt." = X,
        codeunit "DVI App Area Subscriber" = X,
        codeunit "DVI Sync Context" = X,
        codeunit "DVI Runner Events" = X,
        codeunit "DVI Runner Dispatch" = X,
        codeunit "DVI Table Synch." = X,
        codeunit "DVI Record Synch." = X,
        codeunit "DVI Field Transfer" = X,
        codeunit "DVI Synch. Job Log" = X,
        codeunit "DVI Generic Handler" = X,
        codeunit "DVI Mapping Conflict Policy" = X,
        codeunit "DVI Dataverse Connection" = X,
        codeunit "DVI Mapping Logic" = X,
        codeunit "DVI Option Synch." = X,
        codeunit "DVI Coupling Runner" = X,
        codeunit "DVI Coupling Action" = X,
        codeunit "DVI Sales Connection" = X,
        codeunit "DVI Field Service Connection" = X,
        codeunit "DVI Mapping Resolver" = X,
        codeunit "DVI Coupling Store" = X,
        codeunit "DVI Config. Template Applier" = X,
        codeunit "DVI Integration Record Reader" = X,
        codeunit "DVI Follow-up Processor" = X,
        codeunit "DVI Standard Option Source" = X,
        codeunit "DVI Option Record Synch." = X,
        codeunit "DVI Option Coupling Store" = X,
        codeunit "DVI Default Assignment" = X;
}
