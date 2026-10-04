namespace DataverseIntegration.FieldService;

using DataverseIntegration.Core;
using Microsoft.Foundation.NoSeries;
using Microsoft.Foundation.UOM;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;
using Microsoft.Integration.DynamicsFieldService;
using Microsoft.Inventory.Item;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Posting;
using Microsoft.Projects.Project.Setup;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Sales.History;

codeunit 80831 "DVI FS Projects"
{
    Access = Internal;

    var
        ProjectTaskNotCoupledErr: Label 'The Field Service project task %1 is not coupled to a project task.', Comment = '%1 = project task ID';
        ProjectTaskDeletedErr: Label 'The Field Service project task %1 is coupled to a project task that was deleted.', Comment = '%1 = project task ID';
        JournalSetupErr: Label 'The %1 is not set up in %2.', Comment = '%1 = table caption, %2 = setup table caption';
        ProductNotCoupledErr: Label 'The Field Service product %1 is not coupled to an item.', Comment = '%1 = product ID';
        ProductDeletedErr: Label 'The Field Service product %1 is coupled to an item that was deleted.', Comment = '%1 = product ID';
        ServiceItemTypeErr: Label 'The item %1 of the Field Service service must not be an inventory item.', Comment = '%1 = item number';
        ServiceItemBlockedErr: Label 'The item %1 of the Field Service service is blocked.', Comment = '%1 = item number';
        ServiceItemUnitErr: Label 'The base unit of measure of the service item %1 must be %2.', Comment = '%1 = item number, %2 = hour unit of measure';

    /// <summary>
    /// Sums what the project planning lines of a work order product or service already consumed and invoiced, through the usage links that carry its ID. For a service with a coupled booked resource only the budget lines count as consumed.
    /// </summary>
    /// <param name="SourceRecordRef">The work order product or service.</param>
    /// <param name="Consumed">Receives the consumed quantity.</param>
    /// <param name="Invoiced">Receives the invoiced or transferred-to-invoice quantity.</param>
    internal procedure PlanningQuantities(var SourceRecordRef: RecordRef; var Consumed: Decimal; var Invoiced: Decimal)
    var
        FSWorkOrderProduct: Record "FS Work Order Product";
        FSWorkOrderService: Record "FS Work Order Service";
        JobUsageLink: Record "Job Usage Link";
        JobPlanningLine: Record "Job Planning Line";
        FSRecords: Codeunit "DVI FS Records";
        ExternalId: Guid;
        BudgetOnly: Boolean;
    begin
        Consumed := 0;
        Invoiced := 0;
        if not FSRecords.IsProjectIntegration() then
            exit;
        case SourceRecordRef.Number() of
            Database::"FS Work Order Product":
                begin
                    SourceRecordRef.SetTable(FSWorkOrderProduct);
                    ExternalId := FSWorkOrderProduct.WorkOrderProductId;
                end;
            Database::"FS Work Order Service":
                begin
                    SourceRecordRef.SetTable(FSWorkOrderService);
                    ExternalId := FSWorkOrderService.WorkOrderServiceId;
                    BudgetOnly := HasCoupledBookedResource(FSWorkOrderService);
                end;
            else
                exit;
        end;
        JobUsageLink.SetRange("External Id", ExternalId);
        if JobUsageLink.FindSet() then
            repeat
                if JobPlanningLine.Get(JobUsageLink."Job No.", JobUsageLink."Job Task No.", JobUsageLink."Line No.") then begin
                    JobPlanningLine.CalcFields("Qty. Invoiced", "Qty. Transferred to Invoice");
                    if not BudgetOnly or (JobPlanningLine."Line Type" = JobPlanningLine."Line Type"::Budget) then
                        Consumed += JobPlanningLine.Quantity;
                    case true of
                        JobPlanningLine."Qty. Invoiced" > 0:
                            Invoiced += JobPlanningLine."Qty. Invoiced";
                        JobPlanningLine."Qty. Transferred to Invoice" > 0:
                            Invoiced += JobPlanningLine."Qty. Transferred to Invoice";
                        else
                            Invoiced += JobPlanningLine."Qty. to Transfer to Invoice";
                    end;
                end;
            until JobUsageLink.Next() = 0;
    end;

    /// <summary>
    /// Sets the project and project task of a journal line from the coupled project task of a work order product or service.
    /// </summary>
    /// <param name="SourceRecordRef">The work order product or service.</param>
    /// <param name="JobJournalLineRecordRef">The project journal line.</param>
    internal procedure SetProjectTask(var SourceRecordRef: RecordRef; var JobJournalLineRecordRef: RecordRef)
    var
        FSWorkOrderProduct: Record "FS Work Order Product";
        FSWorkOrderService: Record "FS Work Order Service";
        JobJournalLine: Record "Job Journal Line";
        JobTask: Record "Job Task";
        CRMIntegrationRecord: Record "CRM Integration Record";
        JobTaskRecordId: RecordId;
        ProjectTaskId: Guid;
    begin
        if SourceRecordRef.Number() = Database::"FS Work Order Product" then begin
            SourceRecordRef.SetTable(FSWorkOrderProduct);
            ProjectTaskId := FSWorkOrderProduct.ProjectTask;
        end else begin
            SourceRecordRef.SetTable(FSWorkOrderService);
            ProjectTaskId := FSWorkOrderService.ProjectTask;
        end;
        if not CRMIntegrationRecord.FindRecordIDFromID(ProjectTaskId, Database::"Job Task", JobTaskRecordId) then
            Error(ProjectTaskNotCoupledErr, ProjectTaskId);
        if not JobTask.Get(JobTaskRecordId) then
            Error(ProjectTaskDeletedErr, ProjectTaskId);
        JobJournalLineRecordRef.SetTable(JobJournalLine);
        JobJournalLine."Job No." := JobTask."Job No.";
        JobJournalLine."Job Task No." := JobTask."Job Task No.";
        JobJournalLineRecordRef.GetTable(JobJournalLine);
    end;

    /// <summary>
    /// Sets up a new project journal line for a work order product or service: journal template and batch from the Field Service setup, line number, document number and posting date, source and reason code, price and cost calculation, type, item, quantities and prices.
    /// </summary>
    /// <param name="SourceRecordRef">The work order product or service.</param>
    /// <param name="JobJournalLineRecordRef">The new project journal line.</param>
    internal procedure SetUpNewLine(var SourceRecordRef: RecordRef; var JobJournalLineRecordRef: RecordRef)
    var
        FSConnectionSetup: Record "FS Connection Setup";
        Job: Record Job;
        JobJournalLine: Record "Job Journal Line";
        LastJobJournalLine: Record "Job Journal Line";
        JobJournalTemplate: Record "Job Journal Template";
        JobJournalBatch: Record "Job Journal Batch";
    begin
        JobJournalLineRecordRef.SetTable(JobJournalLine);
        FSConnectionSetup.Get();
        Job.Get(JobJournalLine."Job No.");
        if not JobJournalTemplate.Get(FSConnectionSetup."Job Journal Template") then
            Error(JournalSetupErr, JobJournalTemplate.TableCaption(), FSConnectionSetup.TableCaption());
        if not JobJournalBatch.Get(FSConnectionSetup."Job Journal Template", FSConnectionSetup."Job Journal Batch") then
            Error(JournalSetupErr, JobJournalBatch.TableCaption(), FSConnectionSetup.TableCaption());
        JobJournalLine."Journal Template Name" := JobJournalTemplate.Name;
        JobJournalLine."Journal Batch Name" := JobJournalBatch.Name;
        LastJobJournalLine.SetRange("Journal Template Name", JobJournalTemplate.Name);
        LastJobJournalLine.SetRange("Journal Batch Name", JobJournalBatch.Name);
        SetDocumentNo(FSConnectionSetup, SourceRecordRef, JobJournalLine, LastJobJournalLine, JobJournalBatch);
        if LastJobJournalLine.FindLast() then;
        JobJournalLine."Line No." := LastJobJournalLine."Line No." + 10000;
        JobJournalLine."Source Code" := JobJournalTemplate."Source Code";
        JobJournalLine."Reason Code" := JobJournalBatch."Reason Code";
        JobJournalLine."Posting No. Series" := JobJournalBatch."Posting No. Series";
        JobJournalLine."Price Calculation Method" := Job.GetPriceCalculationMethod();
        JobJournalLine."Cost Calculation Method" := Job.GetCostCalculationMethod();
        if SourceRecordRef.Number() = Database::"FS Work Order Product" then
            SetUpProductLine(SourceRecordRef, JobJournalLine)
        else
            SetUpServiceLine(FSConnectionSetup, SourceRecordRef, JobJournalLine);
        JobJournalLineRecordRef.GetTable(JobJournalLine);
    end;

    /// <summary>
    /// Inserts and couples the budget journal line for the booked resource of a work order service, next to its billable line, when the service's item is a service item and the booked resource is coupled.
    /// </summary>
    /// <param name="SourceRecordRef">The work order service.</param>
    /// <param name="JobJournalLineRecordRef">The inserted billable journal line.</param>
    internal procedure InsertBudgetLine(var SourceRecordRef: RecordRef; var JobJournalLineRecordRef: RecordRef)
    var
        FSConnectionSetup: Record "FS Connection Setup";
        FSWorkOrderService: Record "FS Work Order Service";
        FSBookableResourceBooking: Record "FS Bookable Resource Booking";
        JobJournalLine: Record "Job Journal Line";
        BudgetJobJournalLine: Record "Job Journal Line";
        Item: Record Item;
        Resource: Record Resource;
        CRMIntegrationRecord: Record "CRM Integration Record";
        Consumed: Decimal;
        Invoiced: Decimal;
    begin
        if SourceRecordRef.Number() <> Database::"FS Work Order Service" then
            exit;
        SourceRecordRef.SetTable(FSWorkOrderService);
        JobJournalLineRecordRef.SetTable(JobJournalLine);
        if JobJournalLine.Type <> JobJournalLine.Type::Item then
            exit;
        if not Item.Get(JobJournalLine."No.") then
            exit;
        if Item.Type <> Item.Type::Service then
            exit;
        if not FindBookedResource(FSWorkOrderService, FSBookableResourceBooking, Resource) then
            exit;
        FSConnectionSetup.Get();
        PlanningQuantities(SourceRecordRef, Consumed, Invoiced);
        BudgetJobJournalLine.TransferFields(JobJournalLine, true);
        BudgetJobJournalLine."Line No." := JobJournalLine."Line No." - BudgetLineNoOffset();
        BudgetJobJournalLine."Line Type" := BudgetJobJournalLine."Line Type"::Budget;
        BudgetJobJournalLine.Validate(Type, BudgetJobJournalLine.Type::Resource);
        BudgetJobJournalLine.Validate("No.", Resource."No.");
        BudgetJobJournalLine.Validate(Description, CopyStr(FSBookableResourceBooking.Name, 1, MaxStrLen(BudgetJobJournalLine.Description)));
        BudgetJobJournalLine.Validate("Unit of Measure Code", FSConnectionSetup."Hour Unit of Measure");
        BudgetJobJournalLine.Validate("Unit Cost", Resource."Unit Cost");
        BudgetJobJournalLine.Validate(Quantity, FSWorkOrderService.Duration / 60 - Consumed);
        BudgetJobJournalLine.Validate("Unit Price", 0);
        BudgetJobJournalLine.Validate("Qty. to Transfer to Invoice", 0);
        BudgetJobJournalLine.Insert(true);
        CRMIntegrationRecord.InsertRecord(FSWorkOrderService.WorkOrderServiceId, BudgetJobJournalLine.SystemId, Database::"Job Journal Line");
    end;

    /// <summary>
    /// Brings the other journal line coupled to a work order service, its budget or billable line, to the service's current duration.
    /// </summary>
    /// <param name="SourceRecordRef">The work order service.</param>
    /// <param name="JobJournalLineRecordRef">The journal line being updated.</param>
    internal procedure UpdateCorrelatedLine(var SourceRecordRef: RecordRef; var JobJournalLineRecordRef: RecordRef)
    var
        FSWorkOrderService: Record "FS Work Order Service";
        JobJournalLine: Record "Job Journal Line";
        CorrelatedJobJournalLine: Record "Job Journal Line";
        Consumed: Decimal;
        Invoiced: Decimal;
        Quantity: Decimal;
        QuantityToInvoice: Decimal;
    begin
        if SourceRecordRef.Number() <> Database::"FS Work Order Service" then
            exit;
        SourceRecordRef.SetTable(FSWorkOrderService);
        JobJournalLineRecordRef.SetTable(JobJournalLine);
        if not FindCorrelatedLine(FSWorkOrderService.WorkOrderServiceId, JobJournalLine.SystemId, CorrelatedJobJournalLine) then
            exit;
        PlanningQuantities(SourceRecordRef, Consumed, Invoiced);
        Quantity := FSWorkOrderService.Duration / 60 - Consumed;
        if CorrelatedJobJournalLine."Line Type" in [CorrelatedJobJournalLine."Line Type"::Budget, CorrelatedJobJournalLine."Line Type"::" "] then
            QuantityToInvoice := 0
        else
            QuantityToInvoice := FSWorkOrderService.DurationToBill / 60 - Invoiced;
        if (CorrelatedJobJournalLine.Quantity = Quantity) and (CorrelatedJobJournalLine."Qty. to Transfer to Invoice" = QuantityToInvoice) then
            exit;
        CorrelatedJobJournalLine.Quantity := Quantity;
        CorrelatedJobJournalLine."Qty. to Transfer to Invoice" := QuantityToInvoice;
        CorrelatedJobJournalLine.Modify();
    end;

    /// <summary>
    /// Returns whether a synchronized journal line is due for posting by the Field Service posting rule: when its line is used, or when its work order is completed.
    /// </summary>
    /// <param name="SourceRecordRef">The work order product or service.</param>
    /// <returns>True when the journal line is posted now.</returns>
    internal procedure IsDueForPosting(var SourceRecordRef: RecordRef): Boolean
    var
        FSConnectionSetup: Record "FS Connection Setup";
        LineUsed: Boolean;
        WorkOrderCompleted: Boolean;
    begin
        FSConnectionSetup.SetLoadFields("Line Post Rule");
        if not FSConnectionSetup.Get() then
            exit(false);
        LineStatusOf(SourceRecordRef, LineUsed, WorkOrderCompleted);
        case FSConnectionSetup."Line Post Rule" of
            "FS Work Order Line Post Rule"::LineUsed:
                exit(LineUsed);
            "FS Work Order Line Post Rule"::WorkOrderCompleted:
                exit(WorkOrderCompleted);
        end;
        exit(false);
    end;

    /// <summary>
    /// Posts the journal lines coupled to a work order product or service through the project journal batch posting, so the consumed quantities are written back to Field Service.
    /// </summary>
    /// <param name="SourceRecordRef">The work order product or service.</param>
    /// <param name="JobJournalLineRecordRef">The synchronized journal line.</param>
    internal procedure Post(var SourceRecordRef: RecordRef; var JobJournalLineRecordRef: RecordRef)
    var
        JobJournalLine: Record "Job Journal Line";
        LinesToPost: Record "Job Journal Line";
        CorrelatedJobJournalLine: Record "Job Journal Line";
        JobJnlPostBatch: Codeunit "Job Jnl.-Post Batch";
        LineNoFilter: Text;
    begin
        JobJournalLineRecordRef.SetTable(JobJournalLine);
        if not JobJournalLine.Get(JobJournalLine."Journal Template Name", JobJournalLine."Journal Batch Name", JobJournalLine."Line No.") then
            exit;
        LineNoFilter := Format(JobJournalLine."Line No.");
        if FindCorrelatedLine(IntegrationIdOf(SourceRecordRef), JobJournalLine.SystemId, CorrelatedJobJournalLine) then
            LineNoFilter += '|' + Format(CorrelatedJobJournalLine."Line No.");
        LinesToPost.SetRange("Journal Template Name", JobJournalLine."Journal Template Name");
        LinesToPost.SetRange("Journal Batch Name", JobJournalLine."Journal Batch Name");
        LinesToPost.SetFilter("Line No.", LineNoFilter);
        LinesToPost.FindFirst();
        JobJnlPostBatch.Run(LinesToPost);
    end;

    /// <summary>
    /// Decides what happens when the journal line of a work order product or service was deleted, usually by posting: skip when everything is consumed and invoiced, else create a new line for the rest.
    /// </summary>
    /// <param name="SourceRecordRef">The work order product or service.</param>
    /// <returns>Skip or restore.</returns>
    internal procedure ResolveDeletedLine(var SourceRecordRef: RecordRef): Enum "DVI Deletion Outcome"
    var
        FSWorkOrderProduct: Record "FS Work Order Product";
        FSWorkOrderService: Record "FS Work Order Service";
        Consumed: Decimal;
        Invoiced: Decimal;
        Quantity: Decimal;
        QuantityToBill: Decimal;
    begin
        case SourceRecordRef.Number() of
            Database::"FS Work Order Product":
                begin
                    SourceRecordRef.SetTable(FSWorkOrderProduct);
                    Quantity := FSWorkOrderProduct.Quantity;
                    QuantityToBill := FSWorkOrderProduct.QtyToBill;
                end;
            Database::"FS Work Order Service":
                begin
                    SourceRecordRef.SetTable(FSWorkOrderService);
                    Quantity := FSWorkOrderService.Duration / 60;
                    QuantityToBill := FSWorkOrderService.DurationToBill / 60;
                end;
            else
                exit(Enum::"DVI Deletion Outcome"::DVIFail);
        end;
        PlanningQuantities(SourceRecordRef, Consumed, Invoiced);
        if (Quantity = Consumed) and (QuantityToBill = Invoiced) then
            exit(Enum::"DVI Deletion Outcome"::DVISkip);
        exit(Enum::"DVI Deletion Outcome"::DVIRestoreRecord);
    end;

    /// <summary>
    /// Returns whether a work order product or service is left out of the project synchronization: its work order goes to service orders, or, when only used lines synchronize, everything is already consumed and invoiced.
    /// </summary>
    /// <param name="SourceRecordRef">The work order product or service.</param>
    /// <returns>True to leave the line out.</returns>
    internal procedure IgnoreLine(var SourceRecordRef: RecordRef): Boolean
    var
        FSConnectionSetup: Record "FS Connection Setup";
        FSWorkOrder: Record "FS Work Order";
        FSWorkOrderProduct: Record "FS Work Order Product";
        FSWorkOrderService: Record "FS Work Order Service";
        FSRecords: Codeunit "DVI FS Records";
        WorkOrderId: Guid;
        ToConsume: Decimal;
        ToInvoice: Decimal;
        Consumed: Decimal;
        Invoiced: Decimal;
    begin
        if not FSRecords.IsProjectIntegration() then
            exit(false);
        case SourceRecordRef.Number() of
            Database::"FS Work Order Product":
                begin
                    SourceRecordRef.SetTable(FSWorkOrderProduct);
                    WorkOrderId := FSWorkOrderProduct.WorkOrder;
                    if FSWorkOrderProduct.LineStatus = FSWorkOrderProduct.LineStatus::Used then begin
                        ToConsume := FSWorkOrderProduct.Quantity;
                        ToInvoice := FSWorkOrderProduct.QtyToBill;
                    end;
                end;
            Database::"FS Work Order Service":
                begin
                    SourceRecordRef.SetTable(FSWorkOrderService);
                    WorkOrderId := FSWorkOrderService.WorkOrder;
                    if FSWorkOrderService.LineStatus = FSWorkOrderService.LineStatus::Used then begin
                        ToConsume := FSWorkOrderService.Duration / 60;
                        ToInvoice := FSWorkOrderService.DurationToBill / 60;
                    end;
                end;
            else
                exit(false);
        end;
        if FSWorkOrder.Get(WorkOrderId) then
            if FSWorkOrder.IntegrateToService then
                exit(true);
        FSConnectionSetup.SetLoadFields("Line Synch. Rule");
        FSConnectionSetup.Get();
        if FSConnectionSetup."Line Synch. Rule" <> "FS Work Order Line Synch. Rule"::LineUsed then
            exit(false);
        PlanningQuantities(SourceRecordRef, Consumed, Invoiced);
        exit((Consumed = ToConsume) and (Invoiced = ToInvoice));
    end;

    /// <summary>
    /// Adds the quantities of a posted sales invoice's project lines to the invoiced quantity of the work order products and services they came from.
    /// </summary>
    /// <param name="SalesInvoiceHeader">The posted sales invoice.</param>
    internal procedure WriteBackInvoicedQuantities(SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        JobPlanningLineInvoice: Record "Job Planning Line Invoice";
        JobUsageLink: Record "Job Usage Link";
        FSWorkOrderProduct: Record "FS Work Order Product";
        FSWorkOrderService: Record "FS Work Order Service";
        FSRecords: Codeunit "DVI FS Records";
    begin
        if not FSRecords.IsProjectIntegration() then
            exit;
        JobPlanningLineInvoice.SetRange("Document Type", JobPlanningLineInvoice."Document Type"::"Posted Invoice");
        JobPlanningLineInvoice.SetRange("Document No.", SalesInvoiceHeader."No.");
        if JobPlanningLineInvoice.FindSet() then
            repeat
                JobUsageLink.SetRange("Job No.", JobPlanningLineInvoice."Job No.");
                JobUsageLink.SetRange("Job Task No.", JobPlanningLineInvoice."Job Task No.");
                JobUsageLink.SetRange("Line No.", JobPlanningLineInvoice."Job Planning Line No.");
                if JobUsageLink.FindFirst() then
                    if not IsNullGuid(JobUsageLink."External Id") then
                        if FSWorkOrderProduct.Get(JobUsageLink."External Id") then begin
                            FSWorkOrderProduct.QuantityInvoiced += JobPlanningLineInvoice."Quantity Transferred";
                            FSWorkOrderProduct.Modify();
                        end else
                            if FSWorkOrderService.Get(JobUsageLink."External Id") then begin
                                FSWorkOrderService.DurationInvoiced += JobPlanningLineInvoice."Quantity Transferred" * 60;
                                FSWorkOrderService.Modify();
                            end;
            until JobPlanningLineInvoice.Next() = 0;
    end;

    /// <summary>
    /// Returns the distance between the line number of a work order service's billable journal line and its budget line.
    /// </summary>
    /// <returns>The offset.</returns>
    internal procedure BudgetLineNoOffset(): Integer
    begin
        exit(37);
    end;

    local procedure SetUpProductLine(var SourceRecordRef: RecordRef; var JobJournalLine: Record "Job Journal Line")
    var
        FSWorkOrderProduct: Record "FS Work Order Product";
        Item: Record Item;
        Consumed: Decimal;
        Invoiced: Decimal;
    begin
        SourceRecordRef.SetTable(FSWorkOrderProduct);
        PlanningQuantities(SourceRecordRef, Consumed, Invoiced);
        FindCoupledItem(FSWorkOrderProduct.Product, Item);
        JobJournalLine.Validate(Type, JobJournalLine.Type::Item);
        JobJournalLine.Validate("Entry Type", JobJournalLine."Entry Type"::Usage);
        JobJournalLine.Validate("Line Type", JobJournalLine."Line Type"::Billable);
        JobJournalLine.Validate("No.", Item."No.");
        JobJournalLine.Validate(Description, CopyStr(FSWorkOrderProduct.Name, 1, MaxStrLen(JobJournalLine.Description)));
        JobJournalLine.Validate("Unit Cost", Item."Unit Cost");
        JobJournalLine.Validate(Quantity, FSWorkOrderProduct.Quantity - Consumed);
        JobJournalLine.Validate("Unit Price", Item."Unit Price");
        JobJournalLine.Validate("Qty. to Transfer to Invoice", FSWorkOrderProduct.QtyToBill - Invoiced);
    end;

    local procedure SetUpServiceLine(FSConnectionSetup: Record "FS Connection Setup"; var SourceRecordRef: RecordRef; var JobJournalLine: Record "Job Journal Line")
    var
        FSWorkOrderService: Record "FS Work Order Service";
        Item: Record Item;
        UOMMgt: Codeunit "Unit of Measure Management";
        Consumed: Decimal;
        Invoiced: Decimal;
    begin
        SourceRecordRef.SetTable(FSWorkOrderService);
        PlanningQuantities(SourceRecordRef, Consumed, Invoiced);
        FindCoupledItem(FSWorkOrderService.Service, Item);
        if Item.Type = Item.Type::Inventory then
            Error(ServiceItemTypeErr, Item."No.");
        if Item.Blocked then
            Error(ServiceItemBlockedErr, Item."No.");
        if (Item.Type = Item.Type::Service) and (Item."Base Unit of Measure" <> FSConnectionSetup."Hour Unit of Measure") then
            Error(ServiceItemUnitErr, Item."No.", FSConnectionSetup."Hour Unit of Measure");
        JobJournalLine.Validate("Entry Type", JobJournalLine."Entry Type"::Usage);
        if Item.Type = Item.Type::"Non-Inventory" then
            JobJournalLine."Line Type" := JobJournalLine."Line Type"::" "
        else
            JobJournalLine.Validate("Line Type", JobJournalLine."Line Type"::Billable);
        JobJournalLine.Validate(Type, JobJournalLine.Type::Item);
        JobJournalLine.Validate("No.", Item."No.");
        JobJournalLine.Validate(Description, CopyStr(FSWorkOrderService.Name, 1, MaxStrLen(JobJournalLine.Description)));
        JobJournalLine.Validate("Unit of Measure Code", Item."Base Unit of Measure");
        JobJournalLine.Validate("Unit Cost", Item."Unit Cost");
        JobJournalLine.Validate(Quantity, FSWorkOrderService.Duration / 60 - Consumed);
        JobJournalLine.Validate("Unit Price", Item."Unit Price");
        JobJournalLine.Validate("Qty. to Transfer to Invoice",
          UOMMgt.RoundAndValidateQty(FSWorkOrderService.DurationToBill / 60 - Invoiced, JobJournalLine."Qty. Rounding Precision", JobJournalLine.FieldCaption("Qty. to Transfer to Invoice")));
    end;

    local procedure SetDocumentNo(FSConnectionSetup: Record "FS Connection Setup"; var SourceRecordRef: RecordRef; var JobJournalLine: Record "Job Journal Line"; var LastJobJournalLine: Record "Job Journal Line"; JobJournalBatch: Record "Job Journal Batch")
    var
        LineUsed: Boolean;
        WorkOrderCompleted: Boolean;
    begin
        if (JobJournalBatch."Posting No. Series" <> '') and (FSConnectionSetup."Line Post Rule" in ["FS Work Order Line Post Rule"::LineUsed, "FS Work Order Line Post Rule"::WorkOrderCompleted]) then begin
            LineStatusOf(SourceRecordRef, LineUsed, WorkOrderCompleted);
            if LineUsed or WorkOrderCompleted then
                SetPostingDocumentNo(JobJournalLine, LastJobJournalLine, JobJournalBatch);
            exit;
        end;
        SetJournalDocumentNo(JobJournalLine, LastJobJournalLine, JobJournalBatch);
    end;

    local procedure SetPostingDocumentNo(var JobJournalLine: Record "Job Journal Line"; var LastJobJournalLine: Record "Job Journal Line"; JobJournalBatch: Record "Job Journal Batch")
    var
        NoSeries: Codeunit "No. Series";
    begin
        if LastJobJournalLine.FindLast() then begin
            JobJournalLine."Posting Date" := LastJobJournalLine."Posting Date";
            JobJournalLine."Document Date" := LastJobJournalLine."Posting Date";
            if LastJobJournalLine."Document No." = NoSeries.GetLastNoUsed(JobJournalBatch."Posting No. Series") then
                JobJournalLine."Document No." := LastJobJournalLine."Document No."
            else
                JobJournalLine."Document No." := NoSeries.GetNextNo(JobJournalBatch."Posting No. Series", JobJournalLine."Posting Date");
            exit;
        end;
        JobJournalLine."Posting Date" := WorkDate();
        JobJournalLine."Document Date" := WorkDate();
        JobJournalLine."Document No." := NoSeries.GetNextNo(JobJournalBatch."Posting No. Series", JobJournalLine."Posting Date");
    end;

    local procedure SetJournalDocumentNo(var JobJournalLine: Record "Job Journal Line"; var LastJobJournalLine: Record "Job Journal Line"; JobJournalBatch: Record "Job Journal Batch")
    var
        JobsSetup: Record "Jobs Setup";
        NoSeries: Codeunit "No. Series";
    begin
        JobsSetup.Get();
        if LastJobJournalLine.FindLast() then begin
            JobJournalLine."Posting Date" := LastJobJournalLine."Posting Date";
            JobJournalLine."Document Date" := LastJobJournalLine."Posting Date";
            if JobsSetup."Document No. Is Job No." and (LastJobJournalLine."Document No." = '') then
                JobJournalLine."Document No." := JobJournalLine."Job No."
            else
                JobJournalLine."Document No." := LastJobJournalLine."Document No.";
            exit;
        end;
        JobJournalLine."Posting Date" := WorkDate();
        JobJournalLine."Document Date" := WorkDate();
        if JobsSetup."Document No. Is Job No." then begin
            if JobJournalLine."Document No." = '' then
                JobJournalLine."Document No." := JobJournalLine."Job No.";
            exit;
        end;
        if JobJournalBatch."No. Series" <> '' then
            JobJournalLine."Document No." := NoSeries.GetNextNo(JobJournalBatch."No. Series", JobJournalLine."Posting Date");
    end;

    local procedure LineStatusOf(var SourceRecordRef: RecordRef; var LineUsed: Boolean; var WorkOrderCompleted: Boolean)
    var
        FSWorkOrderProduct: Record "FS Work Order Product";
        FSWorkOrderService: Record "FS Work Order Service";
    begin
        case SourceRecordRef.Number() of
            Database::"FS Work Order Product":
                begin
                    SourceRecordRef.SetTable(FSWorkOrderProduct);
                    LineUsed := FSWorkOrderProduct.LineStatus = FSWorkOrderProduct.LineStatus::Used;
                    WorkOrderCompleted := FSWorkOrderProduct.WorkOrderStatus = FSWorkOrderProduct.WorkOrderStatus::Completed;
                end;
            Database::"FS Work Order Service":
                begin
                    SourceRecordRef.SetTable(FSWorkOrderService);
                    LineUsed := FSWorkOrderService.LineStatus = FSWorkOrderService.LineStatus::Used;
                    WorkOrderCompleted := FSWorkOrderService.WorkOrderStatus = FSWorkOrderService.WorkOrderStatus::Completed;
                end;
        end;
    end;

    local procedure FindCoupledItem(ProductId: Guid; var Item: Record Item)
    var
        CRMIntegrationRecord: Record "CRM Integration Record";
        ItemRecordId: RecordId;
    begin
        if not CRMIntegrationRecord.FindRecordIDFromID(ProductId, Database::Item, ItemRecordId) then
            Error(ProductNotCoupledErr, ProductId);
        if not Item.Get(ItemRecordId) then
            Error(ProductDeletedErr, ProductId);
    end;

    local procedure FindBookedResource(FSWorkOrderService: Record "FS Work Order Service"; var FSBookableResourceBooking: Record "FS Bookable Resource Booking"; var Resource: Record Resource): Boolean
    var
        CRMIntegrationRecord: Record "CRM Integration Record";
        ResourceRecordId: RecordId;
    begin
        if not FSBookableResourceBooking.Get(FSWorkOrderService.Booking) then
            exit(false);
        if not CRMIntegrationRecord.FindRecordIDFromID(FSBookableResourceBooking.Resource, Database::Resource, ResourceRecordId) then
            exit(false);
        exit(Resource.Get(ResourceRecordId));
    end;

    local procedure HasCoupledBookedResource(FSWorkOrderService: Record "FS Work Order Service"): Boolean
    var
        FSBookableResourceBooking: Record "FS Bookable Resource Booking";
        CRMIntegrationRecord: Record "CRM Integration Record";
    begin
        if IsNullGuid(FSWorkOrderService.Booking) then
            exit(false);
        if not FSBookableResourceBooking.Get(FSWorkOrderService.Booking) then
            exit(false);
        exit(CRMIntegrationRecord.FindByCRMID(FSBookableResourceBooking.Resource));
    end;

    local procedure FindCorrelatedLine(IntegrationId: Guid; JobJournalLineSystemId: Guid; var CorrelatedJobJournalLine: Record "Job Journal Line"): Boolean
    var
        CRMIntegrationRecord: Record "CRM Integration Record";
    begin
        if IsNullGuid(IntegrationId) then
            exit(false);
        CRMIntegrationRecord.SetRange("Table ID", Database::"Job Journal Line");
        CRMIntegrationRecord.SetRange("CRM ID", IntegrationId);
        CRMIntegrationRecord.SetFilter("Integration ID", '<>%1', JobJournalLineSystemId);
        if CRMIntegrationRecord.FindSet() then
            repeat
                if CorrelatedJobJournalLine.GetBySystemId(CRMIntegrationRecord."Integration ID") then
                    exit(true);
            until CRMIntegrationRecord.Next() = 0;
        exit(false);
    end;

    local procedure IntegrationIdOf(var SourceRecordRef: RecordRef): Guid
    var
        FSWorkOrderService: Record "FS Work Order Service";
    begin
        if SourceRecordRef.Number() <> Database::"FS Work Order Service" then
            exit;
        SourceRecordRef.SetTable(FSWorkOrderService);
        exit(FSWorkOrderService.WorkOrderServiceId);
    end;
}
