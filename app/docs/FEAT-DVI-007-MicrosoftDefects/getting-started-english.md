# FEAT-DVI-007 - Microsoft Defects

There is nothing to set up. This feature adds tests that show the redesigned synchronization avoids problems found in
the standard integration, for example:

- removing the couplings of one mapping no longer removes those of another mapping on the same table;
- the Dataverse actions on resources open the product or the bookable resource you asked for;
- on service items you can delete the Field Service coupling;
- Field Service leaves out crews, pools and tasks of closed projects also while it is enabled.

The full list is in the technical documentation.
