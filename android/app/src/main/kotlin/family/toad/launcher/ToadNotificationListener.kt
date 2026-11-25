package family.toad.launcher

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class ToadNotificationListener : NotificationListenerService() {

    private val counts = HashMap<String, Int>()

    private fun push() {
        onCountsChanged?.invoke(HashMap(counts))
    }

    private fun bump(sbn: StatusBarNotification?, delta: Int) {
        if (sbn == null) return
        if (sbn.isOngoing) return
        val pkg = sbn.packageName ?: return
        val next = (counts[pkg] ?: 0) + delta
        if (next <= 0) counts.remove(pkg) else counts[pkg] = next
        push()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) = bump(sbn, 1)

    override fun onNotificationRemoved(sbn: StatusBarNotification) = bump(sbn, -1)

    override fun onListenerConnected() {
        super.onListenerConnected()
        counts.clear()
        for (sbn in activeNotifications ?: emptyArray()) {
            if (sbn.isOngoing) continue
            val pkg = sbn.packageName ?: continue
            counts[pkg] = (counts[pkg] ?: 0) + 1
        }
        push()
    }

    companion object {
        @Volatile
        var onCountsChanged: ((Map<String, Int>) -> Unit)? = null

        fun startWatching() {
        }
    }
}
