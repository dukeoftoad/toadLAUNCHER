package family.toad.launcher

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent

/**
 * The lock-screen service — double-tap-to-sleep's real engine.
 *
 * Android only lets an accessibility service perform the system lock
 * global action (API 28+). The service is opt-in: the user flips it on
 * once in Accessibility settings (the launcher deep-links there with the
 * component preselected), and double-tap then locks the screen through
 * [GLOBAL_ACTION_LOCK_SCREEN]. No other capability is requested — the
 * config retrieves no window content and listens to nothing.
 *
 * The same consent also covers the notification-shade fallback and the
 * screenshot action (both are plain global actions on the same service —
 * zero extra permissions, zero extra watching).
 */
class ToadLockService : AccessibilityService() {

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Intentionally empty — the service performs actions, it watches
        // nothing.
    }

    override fun onInterrupt() {
        // Nothing to interrupt — no feedback channels are configured.
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

    /** Notification-shade pull when the hidden StatusBarManager call is
     *  unavailable (PLT-02 fallback — same service, same consent). */
    fun pullNotificationsPanel(): Boolean =
        performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS)

    /** Quick-settings pull (offered as a gesture target one day). */
    fun pullQuickSettings(): Boolean =
        performGlobalAction(GLOBAL_ACTION_QUICK_SETTINGS)

    /** Screenshot through the accessibility global action (API 28+).
     *  Returns false when the platform refuses (some OEMs do). */
    fun takeScreenshot(): Boolean =
        performGlobalAction(GLOBAL_ACTION_TAKE_SCREENSHOT)

    companion object {
        /** Set while the user keeps the service enabled; null otherwise. */
        @Volatile
        var instance: ToadLockService? = null
    }
}
