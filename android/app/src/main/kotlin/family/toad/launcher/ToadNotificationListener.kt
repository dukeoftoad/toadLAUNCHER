package family.toad.launcher

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Notification dots, for real — opt-in.
 *
 * The user grants Notification access once (the launcher deep-links to
 * that exact settings page); from then on this service counts active
 * notifications per package and pushes the map to Dart through the
 * activity's method channel. Nothing is read beyond the package name
 * and the ongoing flag — no titles, no text, no extras. Counts die with
 * the process: the next connection starts from the live snapshot.
 */
class ToadNotificationListener : NotificationListenerService() {

    private val counts = HashMap<String, Int>()

    private fun push() {
        onCountsChanged?.invoke(HashMap(counts))
    }

    private fun bump(sbn: StatusBarNotification?, delta: Int) {
        if (sbn == null) return
        if (sbn.isOngoing) return // persistent chips are not news
        val pkg = sbn.packageName ?: return
        val next = (counts[pkg] ?: 0) + delta
        if (next <= 0) counts.remove(pkg) else counts[pkg] = next
        push()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) = bump(sbn, 1)

    override fun onNotificationRemoved(sbn: StatusBarNotification) = bump(sbn, -1)

    override fun onListenerConnected() {
        super.onListenerConnected()
        // Re-seed from whatever is currently in the shade, then publish.
        counts.clear()
        for (sbn in activeNotifications ?: emptyArray()) {
            if (sbn.isOngoing) continue
            val pkg = sbn.packageName ?: continue
            counts[pkg] = (counts[pkg] ?: 0) + 1
        }
        push()
    }

    companion object {
        /** The activity registers itself here to relay counts to Dart. */
        @Volatile
        var onCountsChanged: ((Map<String, Int>) -> Unit)? = null

        /**
         * The service can start before the activity (boot, reinstall) —
         * while nobody listens the map simply waits for the next push.
         * Kept as a no-op hook for symmetry with [onCountsChanged].
         */
        fun startWatching() {
            // Registration happens via onCountsChanged in MainActivity;
            // a connected service replays its snapshot on the next push.
        }
    }
}
