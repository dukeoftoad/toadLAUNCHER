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

    companion object {
        /** Set while the user keeps the service enabled; null otherwise. */
        @Volatile
        var instance: ToadLockService? = null
    }
}
