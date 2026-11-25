package family.toad.launcher

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent

class ToadLockService : AccessibilityService() {

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
    }

    override fun onInterrupt() {
    }

    override fun onServiceConnected() {
        instance = this
        super.onServiceConnected()
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        super.onDestroy()
    }

    fun lockNow() {
        performGlobalAction(GLOBAL_ACTION_LOCK_SCREEN)
    }

    fun pullNotificationsPanel(): Boolean =
        performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS)

    fun pullQuickSettings(): Boolean =
        performGlobalAction(GLOBAL_ACTION_QUICK_SETTINGS)

    fun takeScreenshot(): Boolean =
        performGlobalAction(GLOBAL_ACTION_TAKE_SCREENSHOT)

    companion object {
        @Volatile
        var instance: ToadLockService? = null
    }
}
