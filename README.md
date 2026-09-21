# Azure Lighthouse Multi-Subscription Manifest

`azure-lighthouse-subscription.json` delegates one or more customer subscriptions to a service provider through Azure Lighthouse.

## 1. Customize

Edit the template defaults:

- `managedByTenantId`: service provider Microsoft Entra tenant ID.
- `delegations`: add one entry per customer subscription.
- `subscriptionId`: target customer subscription ID.
- `offerName` and `offerDescription`: customer-facing details.
- `authorizations`: managing-tenant group/service-principal object IDs and Azure role IDs.

Remove any unused sample entries. Prefer security groups and least-privilege roles.

## 2. Deploy

The customer must have **Owner-equivalent access on every target subscription**.

1. In Azure Portal, search for **Deploy a custom template**.
2. Select **Build your own template in the editor** → **Load file**.
3. Upload `azure-lighthouse-subscription.json`, then select **Save**.
4. Select a subscription and deployment region.
5. Select **Review + create** → **Create**.

## 3. Verify

Open **Service providers** → **Service provider offers**. Changes can take up to 15 minutes to appear.

All target subscriptions must belong to the same customer tenant. See [Microsoft's Azure Lighthouse onboarding guide](https://learn.microsoft.com/azure/lighthouse/how-to/onboard-customer) for role restrictions and troubleshooting.
