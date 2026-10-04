# FEAT-DVI-003 - Value Converters

> **Source/legacy reference:** N/A (greenfield).
> **Affected objects:** Integration Field Mapping (FlowField), Integration Field Mapping List (column); new converter table, enum and codeunits listed below.
> **Namespaces:** `DataverseIntegration.Core`; tests `DataverseIntegration.Test`.

## Business Process

Microsoft computes a field's value through `OnTransferFieldData`, which the CDS, CRM and Field Service subscribers all
handle: the first subscriber that sets `IsValueFound` wins, and the order is not defined. Here, every field mapping
of a switched mapping has exactly one converter, chosen and stored explicitly.

1. When a mapping is switched (*Use Redesigned Synchronization*), each of its field mappings without a converter
   gets one: the first value of **DVI Value Converter**, in ordinal order, whose `AppliesTo` accepts the field pair,
   or *Direct*. The pair is judged in the Business Central → Dataverse orientation when the field mapping sends data
   to Dataverse, otherwise the other way.
2. The choice is stored in **DVI Field Converter**, keyed by mapping name and the two field numbers, so it survives
   Microsoft re-creating the field mappings. It is shown on *Integration Field Mappings* (column *Value Converter*)
   and edited on *Integration Field Converters* (from *Redesigned Integration Mappings → Field Converters*).
3. During a synchronization, the field transfer loads the converters of the owning mapping (a *Synchronize now* copy
   uses its parent's). For a field with a converter, the converter computes the value; if it declines, or for
   *Direct*, the value is copied as before.

| Converter | Ordinal | Applies to | Converts |
|---|---|---|---|
| Direct | 0 | never chosen automatically | Copies the value |
| Owner | 10 | either field is `OwnerId` | Team ownership keeps the Dataverse owner; Person ownership maps the salesperson to the coupled user and back |
| Primary contact | 20 | either field is *Primary Contact No.* | A blank incoming contact keeps an uncoupled local contact; otherwise as Coupled record key |
| Currency | 30 | the source field relates to Currency or Transaction Currency | Local currency ↔ the Dataverse base currency's transaction currency; then as Coupled record key |
| Unit of measure | 40 | base unit of measure of items, resources, price list lines; product default unit; unit groups | Unit and unit-group conversions when unit-group mapping is on; otherwise as Coupled record key |
| Option value | 50 | an option field paired with a field related to a table that has an option mapping | Table code ↔ Dataverse option value |
| Coupled record key | 60 | both fields relate to tables that a Dataverse mapping couples | Business Central key ↔ the coupled Dataverse ID; honours *Clear Value on Failed Sync*; errors when the related record is not coupled |

The more specific converters have lower ordinals, so they are chosen before *Coupled record key*, which is the order
Microsoft's subscribers effectively follow. A dependent app adds a converter as an `enumextension` value; it takes
part in automatic assignment through `AppliesTo` without registration code.

## Data Model

### New Tables

**80004 DVI Field Converter**

| # | Field | Type | Notes |
|---|---|---|---|
| 1 | Mapping Name | Code[20] | Primary key part; the owning integration table mapping |
| 2 | Field No. | Integer | Primary key part; Business Central field |
| 3 | Integration Table Field No. | Integer | Primary key part; Dataverse field |
| 4 | Converter | Enum DVI Value Converter | |

### New Fields on Existing Tables

| Object | Field | Type | Notes |
|---|---|---|---|
| Integration Field Mapping | 80000 DVI Value Converter | FlowField, Enum | Lookup of the field converter |

## Objects

| Type | ID | Name | Purpose |
|---|---|---|---|
| Table | 80004 | DVI Field Converter | Converter per field mapping |
| Table extension | 80003 | DVI Integration Field Mapping | Converter FlowField |
| Enum | 80004 | DVI Value Converter | Converters; implements `DVI IValueConverter` |
| Interface | – | DVI IValueConverter | `AppliesTo`, `Convert` |
| Codeunit | 80040 | DVI Direct Converter | Copies the value |
| Codeunit | 80041 | DVI Owner Converter | Owner by ownership model |
| Codeunit | 80042 | DVI Primary Contact Converter | Primary contact |
| Codeunit | 80043 | DVI Currency Converter | Local and base currency |
| Codeunit | 80044 | DVI Unit of Measure Converter | Units and unit groups |
| Codeunit | 80045 | DVI Option Value Converter | Option values |
| Codeunit | 80046 | DVI Coupled Key Converter | Coupled record keys |
| Codeunit | 80047 | DVI Converter Assignment | Default converters on switch; lookup during transfer |
| Page | 80002 | DVI Field Converters | Converters list |
| Page extension | 80001 | DVI Int. Field Mapping List | Converter column |

`DVI Field Transfer` takes the context and applies the converters; `DVI Default Assignment` assigns converters when
it switches a mapping; *Redesigned Integration Mappings* gets a *Field Converters* action.

## Files

```
app/src/Core/codeunits/   DirectConverter, OwnerConverter, PrimaryContactConverter, CurrencyConverter,
                          UnitOfMeasureConverter, OptionValueConverter, CoupledKeyConverter, ConverterAssignment
app/src/Core/enums/       ValueConverter.Enum.al
app/src/Core/interfaces/  IValueConverter.Interface.al
app/src/Core/tables/      FieldConverter.Table.al
app/src/Core/tableextensions/IntegrationFieldMapping.TableExt.al
app/src/Core/pages/       FieldConverters.Page.al
app/src/Core/pageextensions/IntFieldMappingList.PageExt.al
test/src/Core/codeunits/  ValueConverterTests
```

## Integration Points

| Point | Procedure | Usage |
|---|---|---|
| CRM Synch. Helper | `FindRecordIDByPK`, `FindPKByRecordID`, `GetCoupledCDSUserId`, `FindNewValueForSpecialMapping(SourceFieldRef, var NewValue)`, `ConvertBaseUnitOfMeasureToUomId`, `ConvertUomIdToBaseUnitOfMeasure`, `PrefixUnitGroupCode`, `ConvertTableToOption`, `ConvertOptionToTable` | Value conversions (public, no events) |
| CRM Integration Record | `FindIDFromRecordID`, `FindRecordIDFromID`, `FindByRecordID` | Couplings of related records |
| CRM Integration Management | `IsUnitGroupMappingEnabled` | Unit-group conversions |

## Dependencies

| Dependency | App | Usage |
|---|---|---|
| FEAT-DVI-001 | this app | Field transfer, assignments |

## Known Limitations

- The table-pair-specific conversions of Dynamics 365 Sales (write-in products on sales order lines, the owner of
  bidirectional sales orders, values kept for certain fields) and of Field Service (work order status, durations in
  minutes, quantities) are converters of FEAT-DVI-005 and FEAT-DVI-006.
- Converters are assigned only to field mappings without one; a field mapping added later gets its converter the
  next time the mapping is switched, or by hand on *Integration Field Converters*.
- Verified by compilation and unit tests only.

### Microsoft behaviour corrected

- `CRM Synch. Helper.AreFieldsRelatedToMappedTables` picks the related tables' mapping with `FindFirst` and raises an
  error when there is none; *Coupled record key* prefers a switched mapping and, when deciding whether it applies,
  simply declines instead of failing the switch.
