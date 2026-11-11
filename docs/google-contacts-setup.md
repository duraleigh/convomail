# Connecting Google Contacts

Précis reads photos from your Google contacts through Google's People API. Google allows this only through its own sign-in, and a desktop app needs an OAuth client. You make one in your own free Google Cloud project, so no third party is involved. It takes about ten minutes, once.

These steps are from Google's documented flow. I could not click through them myself, so a label may differ slightly on screen.

## In the Google Cloud console

1. Go to [console.cloud.google.com](https://console.cloud.google.com/) and sign in with your Google account.
2. Open the project menu at the top, choose **New project**, name it `Précis`, and create it. Make sure it is selected afterward.
3. Go to **APIs & Services → Library**, search for **People API**, open it, and click **Enable**.
4. Go to **APIs & Services → OAuth consent screen** (it may be called **Google Auth Platform**) and click through setup:
   - App name: `Précis`.
   - Support email and developer contact: your own address.
   - Audience: **External**.
5. Under **Data access** (or **Scopes**), add `.../auth/contacts.readonly`.
6. Under **Audience**, set the publishing status to **In production**. In Testing status, reports say Google ends sign-ins after 7 days. Leave the app unverified: verification is only for apps offered to other people.
7. Go to **APIs & Services → Credentials → Create credentials → OAuth client ID**. Choose **Desktop app**, name it `Précis`, and click **Create**.
8. Click **Download JSON** and save the file.

If you changed the publishing status after creating the client, create a new client. Reports say tokens from the old one can keep expiring.

## In Précis

1. Open **Settings → Google Contacts**.
2. Click **Choose file** and pick the JSON file.
3. Click **Connect**. Your browser opens to Google's sign-in.
4. Google warns that it has not verified the app. That is expected, because this is your own client. Choose **Advanced**, then **Go to Précis**, and allow reading contacts.
5. Close the browser tab. Photos appear after the first sync.

## What it does

- It reads names, email addresses and photos, read-only, and changes nothing in your contacts.
- Photos are stored on this computer. People with no photo keep their initials.
- Sync runs at start and once a day. **Sync now** runs it on demand.
- **Disconnect** removes the permission, the photos and the saved contact list.
- People in your contacts stay in Chats. If a saved business, such as an airline, moves there, a manual move to Feeds is permanent.
