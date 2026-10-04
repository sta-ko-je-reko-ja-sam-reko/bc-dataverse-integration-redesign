namespace DataverseIntegration.Test;

using DataverseIntegration.Core;
using System.TestLibraries.Utilities;

codeunit 84011 "DVI Sync Context Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure FollowUpsAreQueuedCopiedAndCleared()
    var
        TempFollowUpBuffer: Record "DVI Follow-up Buffer" temporary;
        Context: Codeunit "DVI Sync Context";
        FirstId: Guid;
        SecondId: Guid;
    begin
        // [GIVEN] Two follow-ups queued on the context
        FirstId := CreateGuid();
        SecondId := CreateGuid();
        Context.AddFollowUp('SALESLINES', FirstId, true);
        Context.AddFollowUp('INVLINES', SecondId, false);

        // [WHEN] They are taken and then cleared
        Context.GetFollowUps(TempFollowUpBuffer);
        Context.ClearFollowUps();

        // [THEN] The copy keeps both, in order, and clearing the context does not empty the copy
        Assert.RecordCount(TempFollowUpBuffer, 2);
        TempFollowUpBuffer.FindFirst();
        Assert.AreEqual('SALESLINES', TempFollowUpBuffer."Mapping Name", 'First follow-up mapping');
        Assert.AreEqual(FirstId, TempFollowUpBuffer."Source System Id", 'First follow-up record');
        Assert.IsTrue(TempFollowUpBuffer."To Integration Table", 'First follow-up direction');
        TempFollowUpBuffer.Reset();
        Clear(TempFollowUpBuffer);
        Context.GetFollowUps(TempFollowUpBuffer);
        Assert.RecordIsEmpty(TempFollowUpBuffer);
    end;

    [Test]
    procedure DirectionAndInsertFlagsAreKept()
    var
        Context: Codeunit "DVI Sync Context";
        JobId: Guid;
    begin
        // [GIVEN] / [WHEN] The pipeline sets the job, direction and insert flag
        JobId := CreateGuid();
        Context.SetJobId(JobId);
        Context.SetToIntegrationTable(true);
        Context.SetDestinationInserted(true);

        // [THEN] Steps read them back
        Assert.AreEqual(JobId, Context.GetJobId(), 'Job ID');
        Assert.IsTrue(Context.IsToIntegrationTable(), 'Direction');
        Assert.IsTrue(Context.IsDestinationInserted(), 'Insert flag');
    end;
}
