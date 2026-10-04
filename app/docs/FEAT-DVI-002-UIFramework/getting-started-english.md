# FEAT-DVI-002 - UI Framework

## The Dataverse actions on customers

With the redesigned integration turned on, the **Customer Card** and the **Customer List** have one **Dataverse**
group of actions:

| Action | When you see it |
|---|---|
| **Account** | The customer is coupled to an account and the integration sends customers to Dataverse |
| **Synchronize** | Always, when customers are integrated; you only get the directions the integration allows |
| **Set Up Coupling**, **Match-Based Coupling** | Always, when customers are integrated |
| **Delete Coupling** | The customer is coupled |
| **Create Account in Dataverse** | The customer is not coupled yet and the integration sends customers to Dataverse |
| **Create Customer in Business Central** | The integration gets accounts from Dataverse (Customer List) |
| **Synchronization Log** | Always, when customers are integrated |

Actions that do not apply are hidden instead of failing when you choose them.

## Opening Business Central from Dataverse

When you open the Business Central link of an account in Dataverse:

- If the account is coupled, the customer card opens.
- If it is not coupled, you can create the customer in Business Central or choose an existing customer to couple it
  to. The customer then opens.

The other pages with Dataverse actions follow in the next releases.
