# Restored Android sessions

Android Auto Backup can restore Trace's internal Matrix database when the app is
installed again. The database contains the saved Matrix access token, so restoring
it can restore a signed-in session without asking for the Matrix password.
This is OS data restoration, not a password recovered from the homeserver.
See [Android Auto Backup](https://developer.android.com/identity/data/autobackup).

Trace now stores a per-account installation confirmation receipt in Android's
`noBackupFilesDir`. Android excludes that directory from backup and removes it on
uninstall. If a saved Matrix account is present without this receipt, Trace covers
the entire app, including verification dialogs, with “Is this your account?”.
Opening the restored account requires successful device authentication. A fresh
Matrix sign-in also establishes the receipt. Missing/failed receipt reads keep
the gate closed, and a canceled authentication never writes a receipt.

Existing installations encounter this confirmation once on upgrading. Normal
subsequent launches keep the signed-in convenience. The gate protects UI access;
Matrix may synchronize in the background. Device authentication accepts the
credentials enrolled by the current device owner. It does not prove ownership
of the Matrix account against someone who also knows the device credential.
“Not me” signs out the saved account; if another profile remains, it is checked
independently. Without device authentication, sign out and sign in again.

Widget tests verify that private content stays unmounted until authentication
succeeds. Reinstall/OS restore and native authentication still need verification
on a real Android device with backup enabled.
